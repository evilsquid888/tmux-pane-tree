#!/usr/bin/env bash
set -euo pipefail

for test_file in "$@"; do
  bash "$test_file"
done
