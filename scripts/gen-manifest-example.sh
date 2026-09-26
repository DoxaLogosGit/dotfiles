#!/bin/bash
#
# Generate manifest.example from scripts/tools.tsv, so the registry, the
# validator and the starter file cannot drift apart. Re-run after adding a
# tool row; tests/test_gen_manifest.sh fails if the committed example has
# fallen behind the table.
#
# Usage: scripts/gen-manifest-example.sh [table] [output]

set -e

TABLE="${1:-$(dirname "$0")/tools.tsv}"
OUT="${2:-$(dirname "$0")/../manifest.example}"

{
    echo "# Per-machine install manifest — copy to your overlay directory as"
    echo "# manifest.conf and edit the values for this machine."
    echo "#"
    echo "#   yes          install the tool and link its config"
    echo "#   no           skip both"
    echo "#   config-only  link the config; the tool is installed some other way"
    echo "#"
    echo "# A tool left out of an existing manifest is treated as 'no' and named"
    echo "# in the run summary. A machine with no manifest at all installs"
    echo "# everything, exactly as before manifests existed."
    echo "#"
    echo "# The trailing comment on each line lists the platforms that supply the"
    echo "# tool; a platform absent there needs no 'no' line on that machine."
    echo "#"
    echo "# GENERATED from scripts/tools.tsv by scripts/gen-manifest-example.sh."
    echo "# Do not hand-edit: add a row to the table instead."
    echo ""

    while IFS= read -r line; do
        case "$line" in ''|\#*) continue ;; esac

        tool=$(printf '%s' "$line" | cut -f1)

        platforms=""
        for pair in "2:fedora" "3:debian" "4:raspbian" "5:macos"; do
            col="${pair%%:*}"
            name="${pair##*:}"
            cell=$(printf '%s' "$line" | cut -f"$col")
            [ "$cell" = "-" ] || platforms="$platforms $name"
        done

        if [ -z "$platforms" ]; then
            printf '%-16s = yes   # config/phase only\n' "$tool"
        else
            printf '%-16s = yes   #%s\n' "$tool" "$platforms"
        fi
    done < "$TABLE"
} > "$OUT"

echo "wrote $OUT"
