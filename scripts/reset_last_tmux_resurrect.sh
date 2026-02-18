#!/bin/bash

# === Fix 'last' symlink for tmux-resurrect with .txt session files ===
# Files are named: tmux_resurrect_YYYYMMDDHHMMSS.txt
# This script:
#   - Finds the most recent non-zero-sized .txt file
#   - Updates the 'last' symlink to point to it
#   - Only if 'last' is broken or pointing to a zero-byte file

set -euo pipefail

# Configuration
RESURRECT_DIR="$HOME/.local/share/tmux/resurrect"
LINK_NAME="last"
LINK_PATH="$RESURRECT_DIR/$LINK_NAME"

# Debug info
echo "🔍 Checking resurrect directory: $RESURRECT_DIR"
echo "🔍 Checking symlink: $LINK_PATH"

# Validate directory
if [[ ! -d "$RESURRECT_DIR" ]]; then
  echo "❌ Error: Directory $RESURRECT_DIR does not exist."
  exit 1
fi

# Check if 'last' is a symlink
if [[ ! -L "$LINK_PATH" ]]; then
  echo "⚠️  'last' is not a symlink. Creating it..."
  # Find the most recent .txt file to use as target
  if ! find "$RESURRECT_DIR" -type f -name "tmux_resurrect_*.txt" -print0 | head -n1 >/dev/null; then
    echo "❌ No session files found. Cannot create 'last'."
    exit 1
  fi
  TARGET=$(find "$RESURRECT_DIR" -type f -name "tmux_resurrect_*.txt" -print0 | sort -r -z | head -n1 | xargs -0 basename)
  ln -sf "$TARGET" "$LINK_PATH"
  echo "✅ Created 'last' symlink to: $TARGET"
  exit 0
fi

# Read current target of 'last'
CURRENT_TARGET=$(readlink "$LINK_PATH")
if [[ -z "$CURRENT_TARGET" ]]; then
  echo "⚠️  'last' symlink is broken. Fixing..."
else
  echo "✅ 'last' currently points to: $CURRENT_TARGET"
fi

# === Step 1: Find all tmux_resurrect_*.txt files ===
SESSION_FILES=()
while IFS= read -r -d '' file; do
  SESSION_FILES+=("$file")
done < <(find "$RESURRECT_DIR" -type f -name "tmux_resurrect_*.txt" -print0)

if [[ ${#SESSION_FILES[@]} -eq 0 ]]; then
  echo "❌ No tmux_resurrect_*.txt files found in $RESURRECT_DIR."
  exit 1
fi

echo "📁 Found ${#SESSION_FILES[@]} session files:"
for file in "${SESSION_FILES[@]}"; do
  size=$(stat -c %s "$file" 2>/dev/null || echo "unknown")
  mtime=$(stat -c %Y "$file" 2>/dev/null || echo "unknown")
  echo "   $file (size: $size bytes, mtime: $mtime)"
done

# === Step 2: Find the most recent non-zero file ===
LATEST_NONZERO_FILE=""
MAX_MTIME=0

for file in "${SESSION_FILES[@]}"; do
  [[ ! -f "$file" ]] && continue

  # Remove zero-byte files
  size=$(stat -c %s "$file" 2>/dev/null)
  if [[ $size -eq 0 ]]; then
    echo "   🗑️  Removing zero-byte file: $file"
    rm "$file"
    continue
  fi

  # Get modification time
  mtime=$(stat -c %Y "$file")
  if [[ $mtime -gt $MAX_MTIME ]]; then
    MAX_MTIME=$mtime
    LATEST_NONZERO_FILE="$file"
  fi
done

if [[ -z "$LATEST_NONZERO_FILE" ]]; then
  echo "❌ No non-zero-sized tmux_resurrect_*.txt files found."
  exit 1
fi

# === Step 3: Get filename (e.g., tmux_resurrect_20250405123456.txt) ===
TARGET_NAME=$(basename "$LATEST_NONZERO_FILE")
echo "✅ Selected latest non-zero file: $TARGET_NAME"

# === Step 4: Check if 'last' is already pointing to this file ===
if [[ -L "$LINK_PATH" ]]; then
  CURRENT_TARGET=$(readlink "$LINK_PATH")
  if [[ "$CURRENT_TARGET" == "$TARGET_NAME" ]]; then
    echo "✅ 'last' already points to the correct file: $TARGET_NAME"
    exit 0
  fi
fi

# === Step 5: Update the symlink ===
echo "🔄 Updating 'last' symlink to point to: $TARGET_NAME"

# Remove old symlink
rm "$LINK_PATH" 2>/dev/null || true

# Create new symlink
ln -sf "$TARGET_NAME" "$LINK_PATH"

# Final validation
if [[ -L "$LINK_PATH" ]]; then
  FINAL_TARGET=$(readlink "$LINK_PATH")
  if [[ "$FINAL_TARGET" == "$TARGET_NAME" ]]; then
    echo "✅ Success: 'last' now points to $TARGET_NAME"
  else
    echo "❌ Failed: 'last' now points to $FINAL_TARGET (expected $TARGET_NAME)"
    exit 1
  fi
else
  echo "❌ Failed: 'last' is not a symlink after update."
  exit 1
fi

# === Step 6: Clean up old session files (keep only latest 10) ===
echo "🧹 Cleaning up old session files (keeping latest 10)..."

# Find all non-zero session files, sorted by mtime (newest first), skip first 10, delete rest
DELETED_COUNT=0
while IFS= read -r file; do
  size=$(stat -c %s "$file" 2>/dev/null || echo 0)
  if [[ $size -gt 0 ]]; then
    echo "   - Removing old session: $(basename "$file")"
    rm "$file"
    ((DELETED_COUNT++))
  fi
done < <(find "$RESURRECT_DIR" -type f -name "tmux_resurrect_*.txt" -printf '%T@ %p\n' | sort -rn | tail -n +11 | cut -d' ' -f2-)

if [[ $DELETED_COUNT -gt 0 ]]; then
  echo "✅ Removed $DELETED_COUNT old session file(s)"
else
  echo "✅ No old session files to remove"
fi

