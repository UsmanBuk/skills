#!/usr/bin/env bash
# bugfix lane runner — one non-interactive call to Codex, Claude Fable 5, or Kimi K3.
#
#   lane.sh <codex|fable|kimi> <prompt-file> <out-file> [repo-dir] [--readonly]
#   lane.sh --check [repo-dir]
#
# Writes:  <out-file>       the model's final answer (empty on failure)
#          <out-file>.err   stderr / transcript — read this whenever .rc != 0
#          <out-file>.rc    exit code
# Exit:    0 ok · 1 lane failed · 2 empty or invalid output · 3 a --readonly lane
#          modified the working tree · 124 timeout
#
# Why a script: each CLI has its own quirks (Codex wants the prompt on stdin and -o for the
# final message; Kimi only takes argv and prints a resume footer; Claude's JSON must be
# checked for the canonical model). Encoding them once keeps every phase identical and
# fail-closed — a lane that exits 0 with nothing to show is a failure, not a pass.
set -uo pipefail

TIMEOUT="${BUGFIX_TIMEOUT:-1800}"
CLAUDE_MODEL="${BUGFIX_CLAUDE_MODEL:-claude-fable-5}"
KIMI_MODEL="${BUGFIX_KIMI_MODEL:-kimi-code/k3}"
KIMI_MAX_PROMPT=120000   # kimi takes the prompt as one argv; Linux caps a single arg at 128 KiB

die() { echo "lane.sh: $*" >&2; exit 1; }

# sha of (status + diff) so a "read-only" lane that wrote to the tree is caught.
tree_fingerprint() {
  git -C "$1" rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "not-a-repo"; return; }
  {
    git -C "$1" status --porcelain --untracked-files=all
    git -C "$1" diff HEAD 2>/dev/null || git -C "$1" diff   # no HEAD yet in a fresh repo
    git -C "$1" ls-files --others --exclude-standard -z | (cd "$1" && xargs -0 -r sha256sum)
  } | sha256sum | cut -c1-16
}

run_codex() {  # prompt out repo
  # Prompt on stdin ("-"): argv is capped at 128 KiB and a diff-bearing prompt hits that.
  # -o captures the final message only; the transcript goes to .err. --skip-git-repo-check
  # so a non-repo dir is fine. Approvals/sandbox bypassed because the implement lane must
  # edit files; read-only lanes are guarded by --readonly instead.
  timeout "$TIMEOUT" codex exec -C "$3" --skip-git-repo-check \
    --dangerously-bypass-approvals-and-sandbox -o "$2" - < "$1" > "$2.err" 2>&1
  local rc=$?
  grep -qi "usage limit" "$2.err" && echo "codex: usage limit hit — see $2.err" >&2
  return $rc
}

run_fable() {  # prompt out repo
  # Fresh headless session in the repo so Read/Grep/Glob work; JSON output so the model
  # can be verified. Read-only tools need no permission flags in -p mode.
  ( cd "$3" && timeout "$TIMEOUT" claude -p --model "$CLAUDE_MODEL" --output-format json \
      --no-session-persistence < "$1" ) > "$2.json" 2> "$2.err"
  local rc=$?
  [ $rc -ne 0 ] && return $rc
  python3 - "$2" "$CLAUDE_MODEL" <<'PY'
import json, sys
out, want = sys.argv[1], sys.argv[2]
try:
    d = json.load(open(out + ".json"))
except Exception as e:
    print(f"fable: unparseable JSON ({e})", file=sys.stderr); sys.exit(2)
usage = d.get("modelUsage", {})
canon = {v.get("canonicalModel") for v in usage.values() if isinstance(v, dict)}
if d.get("subtype") != "success" or d.get("is_error"):
    print(f"fable: turn failed subtype={d.get('subtype')} is_error={d.get('is_error')}", file=sys.stderr); sys.exit(1)
if want not in usage and want not in canon:
    print(f"fable: expected {want}, got {sorted(usage)}", file=sys.stderr); sys.exit(2)
open(out, "w").write(d.get("result") or "")
PY
}

run_kimi() {  # prompt out repo
  local size; size=$(wc -c < "$1")
  [ "$size" -gt "$KIMI_MAX_PROMPT" ] && { echo "kimi: prompt is ${size} B; argv cap is ~128 KiB — trim the diff or split it" >&2; return 1; }
  # -p is one-shot and auto-approves tools (it refuses -y). kimi-code has no stdin mode, so
  # the prompt must be argv. Output ends with a "To resume this session" footer.
  ( cd "$3" && timeout "$TIMEOUT" kimi -m "$KIMI_MODEL" -p "$(cat "$1")" ) > "$2.raw" 2> "$2.err"
  local rc=$?
  sed -r 's/\x1B\[[0-9;?]*[A-Za-z]//g' "$2.raw" | sed '/^To resume this session: kimi -r /d' > "$2"
  grep -qiE "kimi login|device[- ]code" "$2.raw" "$2.err" 2>/dev/null \
    && echo "kimi: OAuth session looks expired — run 'kimi login' interactively (see $2.err)" >&2
  return $rc
}

check() {  # probe every lane with a trivial prompt; exit = number of failed lanes
  local repo="${1:-$PWD}" tmp fails=0; tmp=$(mktemp -d)
  printf 'Reply with exactly the word OK and nothing else. Do not use tools.\n' > "$tmp/p.txt"
  for lane in codex fable kimi; do
    local t0=$SECONDS
    BUGFIX_TIMEOUT=180 "$0" "$lane" "$tmp/p.txt" "$tmp/$lane.md" "$repo" >/dev/null 2>"$tmp/$lane.warn"
    local rc=$?
    if [ $rc -eq 0 ] && grep -q "OK" "$tmp/$lane.md"; then
      echo "$lane: ok ($((SECONDS - t0))s)"
    else
      fails=$((fails + 1))
      local why; why=$(grep -hiE 'usage limit|login|expired|error' "$tmp/$lane.warn" "$tmp/$lane.md.err" 2>/dev/null | head -1 | head -c 200)
      echo "$lane: FAILED rc=$rc ${why:+— $why}"
    fi
  done
  rm -rf "$tmp"
  return $fails
}

[ "${1:-}" = "--check" ] && { check "${2:-}"; exit $?; }

RO=0; ARGS=()
for a in "$@"; do [ "$a" = "--readonly" ] && RO=1 || ARGS+=("$a"); done
[ ${#ARGS[@]} -ge 3 ] || die "usage: lane.sh <codex|fable|kimi> <prompt-file> <out-file> [repo-dir] [--readonly] | lane.sh --check [repo-dir]"
LANE=${ARGS[0]} PROMPT=${ARGS[1]} OUT=${ARGS[2]} REPO=${ARGS[3]:-$PWD}
[ -s "$PROMPT" ] || die "prompt file missing or empty: $PROMPT"
[ -d "$REPO" ] || die "repo dir missing: $REPO"
mkdir -p "$(dirname "$OUT")"; : > "$OUT"
# The lane's own .err/.raw files would change a fingerprint taken inside the repo.
case "$(cd "$(dirname "$OUT")" && pwd -P)/" in
  "$(cd "$REPO" && pwd -P)/"*) [ $RO -eq 1 ] && die "--readonly needs the out dir outside the repo (WORK must not live in $REPO)" ;;
esac

before=$(tree_fingerprint "$REPO")
case $LANE in
  codex) run_codex "$PROMPT" "$OUT" "$REPO" ;;
  fable) run_fable "$PROMPT" "$OUT" "$REPO" ;;
  kimi)  run_kimi  "$PROMPT" "$OUT" "$REPO" ;;
  *) die "unknown lane: $LANE" ;;
esac
rc=$?
if [ $rc -eq 0 ] && [ ! -s "$OUT" ]; then
  echo "$LANE: exit 0 but empty output — treating as failure" >&2; rc=2
fi
if [ $RO -eq 1 ] && [ "$(tree_fingerprint "$REPO")" != "$before" ]; then
  echo "$LANE: --readonly lane modified the working tree — inspect 'git status' and revert before continuing" >&2; rc=3
fi
echo $rc > "$OUT.rc"
exit $rc
