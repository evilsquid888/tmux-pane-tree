#!/usr/bin/env bash
set -euo pipefail

TESTS_DIR="$(CDPATH= cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$#" -eq 0 ]; then
  test_files=()
  for test_file in "$TESTS_DIR"/*/*_test.sh "$TESTS_DIR"/*_test.sh; do
    [ -f "$test_file" ] || continue
    test_files+=("$test_file")
  done
  set -- "${test_files[@]}"
fi

for test_file in "$@"; do
  printf 'RUN %s\n' "$test_file"
  bash "$test_file"
done
