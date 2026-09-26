#!/bin/bash
# Runs every tests/test_*.sh. Exits non-zero if any file fails.
set -u

cd "$(dirname "$0")" || exit 1

# With arguments, run only those test files; otherwise run them all. The
# container runner uses this to skip tests that need a supported OS_TYPE.
if [ "$#" -gt 0 ]; then
    tests="$*"
else
    tests="$(echo test_*.sh)"
fi

failed=0
for t in $tests; do
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
