#!/usr/bin/env bash
# Runs every release-extension/tests/test-*.sh and exits non-zero if any fails. Usage: ./tests/run.sh
set -uo pipefail
cd "$(dirname "$0")" || exit 1

fail=0
for t in ./test-*.sh; do
  [ -e "$t" ] || continue
  if bash "$t"; then
    echo "PASS $t"
  else
    echo "FAIL $t"
    fail=1
  fi
done
exit "$fail"
