#!/usr/bin/env bash
# Copy every skill in this repo into the local agent skill folders.
# The repo is the source of truth; these folders are deploy targets.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGETS=(
  "$HOME/.claude/skills"
  "$HOME/.codex/skills"
  "$HOME/.agents/skills"
)

for skill in "$REPO_DIR"/skills/*/; do
  name="$(basename "$skill")"
  for target in "${TARGETS[@]}"; do
    mkdir -p "$target"
    rm -rf "${target:?}/$name"
    cp -r "$skill" "$target/$name"
    echo "synced $name -> $target/$name"
  done
done
