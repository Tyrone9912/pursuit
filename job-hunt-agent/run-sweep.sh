#!/bin/zsh
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

mkdir -p logs

{
  echo "=== sweep started $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
  /opt/homebrew/bin/claude -p "$(cat sweep-instructions.md)" --output-format text
  echo "=== sweep finished $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
} >> logs/sweep.log 2>&1
