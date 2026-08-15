#!/usr/bin/env sh
# Run every tests/*_spec.lua in its own headless nvim with an isolated state dir.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NVIM="${NVIM:-nvim}"
export HERDR_TEST_ROOT="$ROOT"

fails=0
for spec in "$ROOT"/tests/*_spec.lua; do
  name="$(basename "$spec")"
  XDG_STATE_HOME="$(mktemp -d)"
  export XDG_STATE_HOME
  if out="$("$NVIM" --headless --clean \
      --cmd "set rtp+=$ROOT" --cmd "runtime plugin/herdr-ask.lua" \
      -l "$spec" 2>&1)" && printf '%s\n' "$out" | grep -q 'HERDR_TEST_PASS'; then
    echo "ok   $name"
  else
    echo "FAIL $name"
    printf '%s\n' "$out" | sed 's/^/     /'
    fails=$((fails + 1))
  fi
done

if [ "$fails" -eq 0 ]; then
  echo "All tests passed"
else
  echo "$fails test(s) failed"
  exit 1
fi
