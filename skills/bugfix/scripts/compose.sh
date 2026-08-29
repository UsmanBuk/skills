#!/usr/bin/env bash
# compose.sh <template> <out> [NAME=file ...]
# Writes <template>, then one "--- NAME ---" block per file, in the order given.
# Prompts live in files, never argv, so a large diff cannot trip shell quoting or argv limits.
set -euo pipefail
[ $# -ge 2 ] || { echo "usage: compose.sh <template> <out> [NAME=file ...]" >&2; exit 1; }
tpl=$1 out=$2; shift 2
[ -s "$tpl" ] || { echo "compose.sh: template missing or empty: $tpl" >&2; exit 1; }
{
  cat "$tpl"
  for kv in "$@"; do
    name=${kv%%=*} file=${kv#*=}
    [ -s "$file" ] || { echo "compose.sh: section $name: file missing or empty: $file" >&2; exit 1; }
    printf '\n--- %s ---\n' "$name"
    cat "$file"
  done
} > "$out"
echo "$out ($(wc -c < "$out") bytes)"
