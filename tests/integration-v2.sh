#!/usr/bin/env bash
#
# integration-v2.sh - opt-in integration test of oc-troubleshoot against a real
# OpenCode v2 binary (v2 beta has no `opencode db` and no `opencode session`).
#
# Runs in an isolated HOME, so it never touches the user's OpenCode
# installation, configuration or database. Every v2 invocation is bounded by
# `timeout` because some v2 commands may start a background service.
#
# Required:
#   OC_TROUBLESHOOT_V2_BIN   path to a v2 opencode binary (e.g. opencode2)
# Optional (enables the real capture smoke):
#   OC_TROUBLESHOOT_V2_AUTH  path to an auth.json copied into the temp HOME
#   OC_TROUBLESHOOT_V2_MODEL model to use, e.g. provider/model
#
# Exits 0 (skipped) when OC_TROUBLESHOOT_V2_BIN is not set.
set -uo pipefail

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LAUNCHER="${REPO}/bin/oc-troubleshoot"
V2="${OC_TROUBLESHOOT_V2_BIN:-}"

if [ -z "$V2" ] || [ ! -x "$V2" ]; then
  printf 'skipped: set OC_TROUBLESHOOT_V2_BIN to a v2 opencode binary\n'
  exit 0
fi

WORK="$(mktemp -d)"
cleanup() {
  # Stop any background service started under the isolated HOME, then drop it.
  HOME="${WORK}/home" timeout 15 "$V2" service stop </dev/null >/dev/null 2>&1 || true
  rm -rf -- "$WORK"
}
trap cleanup EXIT

export HOME="${WORK}/home"
export XDG_STATE_HOME="${WORK}/state"
mkdir -p "$HOME" "${WORK}/project"
PROJ="${WORK}/project"

failures=0

# check - report a test result; increment the failure counter on error.
check() {
  local label="$1" status="$2"
  if [ "$status" -eq 0 ]; then
    printf 'ok   %s\n' "$label"
  else
    printf 'FAIL %s\n' "$label" >&2
    failures=$((failures + 1))
  fi
}

# assert_contains - fail unless the file contains the literal string.
assert_contains() { grep -qF -- "$2" "$1"; }

printf '== v2 binary ==\n'
timeout 30 "$V2" --version </dev/null >"${WORK}/version.txt" 2>&1
check "v2 binary runs" $?
sed -n '1p' "${WORK}/version.txt"

printf '\n== graceful detection without opencode db ==\n'
printf 'The model made a mistake.\n' | \
  OC_TROUBLESHOOT_OPENCODE="$V2" timeout 30 "$LAUNCHER" --cwd "$PROJ" --dry-run \
  >"${WORK}/dry.txt" 2>&1
check "launcher dry-run exits 0 on v2" $?
assert_contains "${WORK}/dry.txt" "source         : none"; check "launcher falls back to no source" $?
assert_contains "${WORK}/dry.txt" "source session : (not detected)"; check "launcher reports no source session" $?

printf '\n== real capture smoke (run --format json) ==\n'
if [ -z "${OC_TROUBLESHOOT_V2_AUTH:-}" ] || [ -z "${OC_TROUBLESHOOT_V2_MODEL:-}" ]; then
  printf 'skipped: set OC_TROUBLESHOOT_V2_AUTH and OC_TROUBLESHOOT_V2_MODEL\n'
else
  mkdir -p "${HOME}/.local/share/opencode"
  cp -- "$OC_TROUBLESHOOT_V2_AUTH" "${HOME}/.local/share/opencode/auth.json"
  log="${WORK}/run-json.log"
  ( cd "$PROJ" && setsid "$V2" run --agent plan --model "$OC_TROUBLESHOOT_V2_MODEL" \
      --format json "Reply with exactly: OK" >"$log" 2>&1 </dev/null & )
  captured=""
  for _ in $(seq 1 120); do
    captured="$(grep -o '"sessionID":"ses_[A-Za-z0-9]*"' "$log" 2>/dev/null | head -n1 || true)"
    [ -n "$captured" ] && break
    sleep 0.5
  done
  check "v2 run --format json exposes a sessionID" $([ -n "$captured" ] && echo 0 || echo 1)
  [ -n "$captured" ] && printf '     parsed %s\n' "$captured"
fi

printf '\n'
if [ "$failures" -eq 0 ]; then
  printf 'All v2 integration tests passed.\n'
else
  printf '%d test(s) failed.\n' "$failures" >&2
  exit 1
fi
