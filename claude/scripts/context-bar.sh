#!/bin/bash

# Color theme: gray, orange, blue, teal, green, lavender, rose, gold, slate, cyan
# Preview colors with: bash scripts/color-preview.sh
COLOR="blue"

# Color codes
C_RESET='\033[0m'
C_GRAY='\033[38;5;245m'  # explicit gray for default text
C_BAR_EMPTY='\033[38;5;238m'
C_USAGE_LABEL='\033[38;5;173m'  # orange for usage labels (Session/Weekly)
case "$COLOR" in
    orange)   C_ACCENT='\033[38;5;173m' ;;
    blue)     C_ACCENT='\033[38;5;74m' ;;
    teal)     C_ACCENT='\033[38;5;66m' ;;
    green)    C_ACCENT='\033[38;5;71m' ;;
    lavender) C_ACCENT='\033[38;5;139m' ;;
    rose)     C_ACCENT='\033[38;5;132m' ;;
    gold)     C_ACCENT='\033[38;5;136m' ;;
    slate)    C_ACCENT='\033[38;5;60m' ;;
    cyan)     C_ACCENT='\033[38;5;37m' ;;
    *)        C_ACCENT="$C_GRAY" ;;  # gray: all same color
esac

input=$(cat)

# Extract model, directory, and cwd
model=$(echo "$input" | jq -r '.model.display_name // .model.id // "?"')
cwd=$(echo "$input" | jq -r '.cwd // empty')
dir=$(basename "$cwd" 2>/dev/null || echo "?")

# Get git branch, uncommitted file count, and sync status
branch=""
git_status=""
if [[ -n "$cwd" && -d "$cwd" ]]; then
    branch=$(git -C "$cwd" branch --show-current 2>/dev/null)
    if [[ -n "$branch" ]]; then
        # Count uncommitted files
        file_count=$(git -C "$cwd" --no-optional-locks status --porcelain -uall 2>/dev/null | wc -l | tr -d ' ')

        # Check sync status with upstream
        sync_status=""
        upstream=$(git -C "$cwd" rev-parse --abbrev-ref @{upstream} 2>/dev/null)
        if [[ -n "$upstream" ]]; then
            # Get last fetch time
            fetch_head="$cwd/.git/FETCH_HEAD"
            fetch_ago=""
            if [[ -f "$fetch_head" ]]; then
                fetch_time=$(stat -f %m "$fetch_head" 2>/dev/null || stat -c %Y "$fetch_head" 2>/dev/null)
                if [[ -n "$fetch_time" ]]; then
                    now=$(date +%s)
                    diff=$((now - fetch_time))
                    if [[ $diff -lt 60 ]]; then
                        fetch_ago="<1m ago"
                    elif [[ $diff -lt 3600 ]]; then
                        fetch_ago="$((diff / 60))m ago"
                    elif [[ $diff -lt 86400 ]]; then
                        fetch_ago="$((diff / 3600))h ago"
                    else
                        fetch_ago="$((diff / 86400))d ago"
                    fi
                fi
            fi

            counts=$(git -C "$cwd" rev-list --left-right --count HEAD...@{upstream} 2>/dev/null)
            ahead=$(echo "$counts" | cut -f1)
            behind=$(echo "$counts" | cut -f2)
            if [[ "$ahead" -eq 0 && "$behind" -eq 0 ]]; then
                if [[ -n "$fetch_ago" ]]; then
                    sync_status="synced ${fetch_ago}"
                else
                    sync_status="synced"
                fi
            elif [[ "$ahead" -gt 0 && "$behind" -eq 0 ]]; then
                sync_status="${ahead} ahead"
            elif [[ "$ahead" -eq 0 && "$behind" -gt 0 ]]; then
                sync_status="${behind} behind"
            else
                sync_status="${ahead} ahead, ${behind} behind"
            fi
        else
            sync_status="no upstream"
        fi

        # Build git status string
        if [[ "$file_count" -eq 0 ]]; then
            git_status="(0 files uncommitted, ${sync_status})"
        elif [[ "$file_count" -eq 1 ]]; then
            # Show the actual filename when only one file is uncommitted
            single_file=$(git -C "$cwd" --no-optional-locks status --porcelain -uall 2>/dev/null | head -1 | sed 's/^...//')
            git_status="(${single_file} uncommitted, ${sync_status})"
        else
            git_status="(${file_count} files uncommitted, ${sync_status})"
        fi
    fi
fi

# ============================================================================
# USAGE TRACKING (Session & Weekly)
# ============================================================================

# Function to check if using OAuth (subscription) vs API billing
is_oauth_mode() {
    # If using API billing mode, these env vars would be set
    # Check for Bedrock, direct API, or other API-based providers
    if [[ -n "$CLAUDE_CODE_USE_BEDROCK" || -n "$AWS_BEARER_TOKEN_BEDROCK" || \
          -n "$ANTHROPIC_API_KEY" || -n "$ANTHROPIC_BASE_URL" ]]; then
        return 1  # API billing mode detected
    fi

    # Check if OAuth credentials exist
    local creds_file="$HOME/.claude/.credentials.json"
    if [[ ! -f "$creds_file" ]]; then
        return 1
    fi
    local has_oauth=$(jq -r '.claudeAiOauth.accessToken // empty' < "$creds_file" 2>/dev/null)
    [[ -n "$has_oauth" ]] && return 0 || return 1
}

# Function to get OAuth token from credentials
get_oauth_token() {
    local creds_file="$HOME/.claude/.credentials.json"
    if [[ ! -f "$creds_file" ]]; then
        return 1
    fi
    jq -r '.claudeAiOauth.accessToken // empty' < "$creds_file" 2>/dev/null
}

# Function to fetch usage data from API (with 30-second cache)
fetch_usage_data() {
    local cache_file="/tmp/claude-usage-cache.json"
    local cache_ttl=30

    # Check if cache is valid
    if [[ -f "$cache_file" ]]; then
        local cache_age=$(( $(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file" 2>/dev/null) ))
        if [[ $cache_age -lt $cache_ttl ]]; then
            cat "$cache_file"
            return 0
        fi
    fi

    # Fetch fresh data
    local token=$(get_oauth_token)
    if [[ -z "$token" ]]; then
        return 1
    fi

    local usage_data=$(curl -s --max-time 3 \
        -H "Authorization: Bearer $token" \
        -H "anthropic-beta: oauth-2025-04-20" \
        -H "Accept: application/json" \
        "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)

    if [[ -n "$usage_data" ]] && echo "$usage_data" | jq -e . >/dev/null 2>&1; then
        echo "$usage_data" > "$cache_file"
        echo "$usage_data"
        return 0
    fi

    return 1
}

# Function to format countdown timer
format_countdown() {
    local resets_at="$1"
    if [[ -z "$resets_at" ]]; then
        echo ""
        return
    fi

    # Parse ISO datetime and calculate seconds until reset
    local reset_epoch=$(date -d "$resets_at" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "${resets_at%.*}" +%s 2>/dev/null)
    if [[ -z "$reset_epoch" ]]; then
        echo ""
        return
    fi

    local now_epoch=$(date +%s)
    local seconds_left=$((reset_epoch - now_epoch))

    if [[ $seconds_left -le 0 ]]; then
        echo "expired"
        return
    fi

    local hours=$((seconds_left / 3600))
    local mins=$(( (seconds_left % 3600) / 60 ))

    if [[ $hours -gt 0 ]]; then
        echo "${hours}h${mins}m"
    else
        echo "${mins}m"
    fi
}

# Function to create usage bar
make_usage_bar() {
    local pct=$1
    local width=10
    local bar=""

    for ((i=0; i<width; i++)); do
        bar_start=$((i * 10))
        progress=$((pct - bar_start))
        if [[ $progress -ge 8 ]]; then
            bar+="${C_ACCENT}█${C_RESET}"
        elif [[ $progress -ge 3 ]]; then
            bar+="${C_ACCENT}▄${C_RESET}"
        else
            bar+="${C_BAR_EMPTY}░${C_RESET}"
        fi
    done

    echo "$bar"
}

# Get transcript path for context calculation and last message feature
transcript_path=$(echo "$input" | jq -r '.transcript_path // empty')

# Get context window size from JSON (accurate), but calculate tokens from transcript
# (more accurate than total_input_tokens which excludes system prompt/tools/memory)
# See: github.com/anthropics/claude-code/issues/13652
max_context=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
max_k=$((max_context / 1000))

# Calculate context bar from transcript
if [[ -n "$transcript_path" && -f "$transcript_path" ]]; then
    context_length=$(jq -s '
        map(select(.message.usage and .isSidechain != true and .isApiErrorMessage != true)) |
        last |
        if . then
            (.message.usage.input_tokens // 0) +
            (.message.usage.cache_read_input_tokens // 0) +
            (.message.usage.cache_creation_input_tokens // 0)
        else 0 end
    ' < "$transcript_path")

    # 20k baseline: includes system prompt (~3k), tools (~15k), memory (~300),
    # plus ~2k for git status, env block, XML framing, and other dynamic context
    baseline=20000
    bar_width=10

    if [[ "$context_length" -gt 0 ]]; then
        pct=$((context_length * 100 / max_context))
        pct_prefix=""
    else
        # At conversation start, ~20k baseline is already loaded
        pct=$((baseline * 100 / max_context))
        pct_prefix="~"
    fi

    [[ $pct -gt 100 ]] && pct=100

    bar=""
    for ((i=0; i<bar_width; i++)); do
        bar_start=$((i * 10))
        progress=$((pct - bar_start))
        if [[ $progress -ge 8 ]]; then
            bar+="${C_ACCENT}█${C_RESET}"
        elif [[ $progress -ge 3 ]]; then
            bar+="${C_ACCENT}▄${C_RESET}"
        else
            bar+="${C_BAR_EMPTY}░${C_RESET}"
        fi
    done

    ctx="${bar} ${C_GRAY}${pct_prefix}${pct}% of ${max_k}k tokens"
else
    # Transcript not available yet - show baseline estimate
    baseline=20000
    bar_width=10
    pct=$((baseline * 100 / max_context))
    [[ $pct -gt 100 ]] && pct=100

    bar=""
    for ((i=0; i<bar_width; i++)); do
        bar_start=$((i * 10))
        progress=$((pct - bar_start))
        if [[ $progress -ge 8 ]]; then
            bar+="${C_ACCENT}█${C_RESET}"
        elif [[ $progress -ge 3 ]]; then
            bar+="${C_ACCENT}▄${C_RESET}"
        else
            bar+="${C_BAR_EMPTY}░${C_RESET}"
        fi
    done

    ctx="${bar} ${C_GRAY}~${pct}% of ${max_k}k tokens"
fi

# Build output: Model | Dir | Branch (uncommitted) | Context
output="${C_ACCENT}${model}${C_GRAY} | 📁${dir}"
[[ -n "$branch" ]] && output+=" | 🔀${branch} ${git_status}"
output+=" | ${ctx}${C_RESET}"

printf '%b\n' "$output"

# Display usage line (session & weekly) - only for OAuth/subscription mode
if is_oauth_mode; then
    usage_data=$(fetch_usage_data)
    if [[ -n "$usage_data" ]]; then
        # Parse session (5-hour) data
        session_pct=$(echo "$usage_data" | jq -r '.five_hour.utilization // 0' | awk '{printf "%.0f", $1}')
        session_reset=$(echo "$usage_data" | jq -r '.five_hour.resets_at // empty')
        session_countdown=$(format_countdown "$session_reset")

        # Parse weekly (7-day) data
        weekly_pct=$(echo "$usage_data" | jq -r '.seven_day.utilization // 0' | awk '{printf "%.0f", $1}')
        weekly_reset=$(echo "$usage_data" | jq -r '.seven_day.resets_at // empty')
        weekly_countdown=$(format_countdown "$weekly_reset")

        # Create bars
        session_bar=$(make_usage_bar $session_pct)
        weekly_bar=$(make_usage_bar $weekly_pct)

        # Build and output usage line
        usage_line="${C_USAGE_LABEL}Session ${C_GRAY}${session_bar} ${session_pct}%"
        [[ -n "$session_countdown" ]] && usage_line+=" (🕐${session_countdown})"
        usage_line+=" ${C_GRAY}| ${C_USAGE_LABEL}Weekly ${C_GRAY}${weekly_bar} ${weekly_pct}%"
        [[ -n "$weekly_countdown" ]] && usage_line+=" (🕐${weekly_countdown})"
        usage_line+="${C_RESET}"

        printf '%b\n' "$usage_line"
    fi
fi

# Get user's last message (text only, not tool results, skip unhelpful messages)
if [[ -n "$transcript_path" && -f "$transcript_path" ]]; then
    # Calculate visible length (without ANSI codes) - 10 chars for bar + content
    plain_output="${model} | 📁${dir}"
    [[ -n "$branch" ]] && plain_output+=" | 🔀${branch} ${git_status}"
    plain_output+=" | xxxxxxxxxx ${pct}% of ${max_k}k tokens"
    max_len=${#plain_output}
    last_user_msg=$(jq -rs '
        # Messages to skip (not useful as context)
        def is_unhelpful:
            startswith("[Request interrupted") or
            startswith("[Request cancelled") or
            . == "";

        [.[] | select(.type == "user") |
         select(.message.content | type == "string" or
                (type == "array" and any(.[]; .type == "text")))] |
        reverse |
        map(.message.content |
            if type == "string" then .
            else [.[] | select(.type == "text") | .text] | join(" ") end |
            gsub("\n"; " ") | gsub("  +"; " ")) |
        map(select(is_unhelpful | not)) |
        first // ""
    ' < "$transcript_path" 2>/dev/null)

    if [[ -n "$last_user_msg" ]]; then
        if [[ ${#last_user_msg} -gt $max_len ]]; then
            echo "💬 ${last_user_msg:0:$((max_len - 3))}..."
        else
            echo "💬 ${last_user_msg}"
        fi
    fi
fi
