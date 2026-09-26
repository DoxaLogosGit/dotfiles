#!/bin/bash
# Runs every tests/test_*.sh. Exits non-zero if any file fails.
set -u

cd "$(dirname "$0")" || exit 1

failed=0
for t in test_*.sh; do
    [ -e "$t" ] || continue
    echo "== $t"
    if bash "$t"; then :; else failed=1; fi
done

echo ""
if [ "$failed" -eq 0 ]; then
    echo "ALL TESTS PASSED"
else
    echo "TESTS FAILED"
fi
exit "$failed"
