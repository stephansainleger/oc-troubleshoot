#!/usr/bin/env bash
#
# run.sh - test suite for oc-troubleshoot.
#
# Runs syntax checks, CLI checks, session-detection checks (v1 and v2 schemas)
# and a background-launch check, all against the recording stub in
# tests/stub/opencode (no real session). Exits non-zero on the first failure.
#
# Usage: tests/run.sh
set -uo pipefail

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LAUNCHER="${REPO}/bin/oc-troubleshoot"
STUB="${REPO}/tests/stub/opencode"
WORK="$(mktemp -d)"
ARGS_OUT="${WORK}/opencode-args.txt"

export XDG_STATE_HOME="${WORK}/state"

cleanup() { rm -rf -- "$WORK"; }
trap cleanup EXIT

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

printf '== syntax ==\n'
bash -n "$LAUNCHER"; check "bash -n bin/oc-troubleshoot" $?
bash -n "${REPO}/install.sh"; check "bash -n install.sh" $?
bash -n "${REPO}/uninstall.sh"; check "bash -n uninstall.sh" $?
bash -n "$STUB"; check "bash -n tests/stub/opencode" $?
bash -n "${REPO}/tests/integration-v2.sh"; check "bash -n tests/integration-v2.sh" $?

printf '\n== cli ==\n'
"$LAUNCHER" --help >"${WORK}/help.txt" 2>&1
check "--help exits 0" $?
assert_contains "${WORK}/help.txt" "Usage: oc-troubleshoot"; check "--help mentions usage" $?

"$LAUNCHER" --version >"${WORK}/version.txt" 2>&1
check "--version exits 0" $?
assert_contains "${WORK}/version.txt" "2.1.0"; check "--version prints version" $?

"$LAUNCHER" </dev/null >"${WORK}/empty.txt" 2>&1
[ $? -ne 0 ]; check "empty description fails" $?

printf '\n== dry-run (explicit session) ==\n'
printf 'The model ran sed instead of using the edit tool.\n' | \
  "$LAUNCHER" --session ses_test --model test-provider/test-model \
  --cwd "$WORK" --dry-run >"${WORK}/dry.txt" 2>&1
check "dry-run exits 0" $?
assert_contains "${WORK}/dry.txt" "source         : provided"; check "dry-run reports provided source" $?
assert_contains "${WORK}/dry.txt" "source session : ses_test"; check "dry-run reports session" $?
assert_contains "${WORK}/dry.txt" "model          : test-provider/test-model"; check "dry-run reports model" $?
assert_contains "${WORK}/dry.txt" "sed instead of using the edit tool"; check "dry-run embeds description" $?
assert_contains "${WORK}/dry.txt" "harness in force"; check "prompt refers to the harness generically" $?

printf '\n== session detection (v1, opencode db) ==\n'
printf 'x\n' | OC_TROUBLESHOOT_OPENCODE="$STUB" OC_STUB_SCHEMA=v1 \
  "$LAUNCHER" --dry-run >"${WORK}/auto-v1.txt" 2>&1
check "v1 detection exits 0" $?
assert_contains "${WORK}/auto-v1.txt" "source         : db:session"; check "v1 detection uses the db" $?
assert_contains "${WORK}/auto-v1.txt" "source session : ses_stub"; check "v1 detection reads the session" $?
assert_contains "${WORK}/auto-v1.txt" "model          : test-provider/test-model"; check "v1 detection reuses source model" $?

printf '\n== session detection (v2, no opencode db) ==\n'
printf 'x\n' | OC_TROUBLESHOOT_OPENCODE="$STUB" OC_STUB_SCHEMA=v2 \
  "$LAUNCHER" --dry-run >"${WORK}/auto-v2.txt" 2>&1
check "v2 detection exits 0" $?
assert_contains "${WORK}/auto-v2.txt" "source         : session-list"; check "v2 detection uses session list" $?
assert_contains "${WORK}/auto-v2.txt" "source session : ses_list"; check "v2 detection reads the session" $?

printf '\n== model fallback (opencode default) ==\n'
printf 'x\n' | OC_TROUBLESHOOT_OPENCODE="$STUB" OC_STUB_SCHEMA=v1 \
  "$LAUNCHER" --session ses_nomodel --cwd "$WORK" --dry-run >"${WORK}/nomodel.txt" 2>&1
check "no-model dry-run exits 0" $?
assert_contains "${WORK}/nomodel.txt" "model          : (opencode default)"; check "no-model reports opencode default" $?
if grep -qF -- "--model" "${WORK}/nomodel.txt"; then
  check "no-model omits --model" 1
else
  check "no-model omits --model" 0
fi

printf '\n== background launch (stub opencode) ==\n'
export OC_TROUBLESHOOT_OPENCODE="$STUB"
export OC_TROUBLESHOOT_TEST_OUT="$ARGS_OUT"
export OC_TROUBLESHOOT_ID_TIMEOUT=2
: >"$ARGS_OUT"

printf 'The model ran sed instead of using the edit tool.\n' | \
  "$LAUNCHER" --session ses_test --model test-provider/test-model \
  --cwd "$WORK" >"${WORK}/run.txt" 2>&1
check "launcher exits 0" $?
assert_contains "${WORK}/run.txt" "analysis session started"; check "launcher reports start" $?
assert_contains "${WORK}/run.txt" "session id : ses_new"; check "launcher captures the session id from the JSON log" $?
assert_contains "${WORK}/run.txt" "opencode -s ses_new"; check "launcher gives a reopen hint" $?

for _ in 1 2 3 4 5 6 7 8 9 10; do
  if [ -s "$ARGS_OUT" ] && grep -qF -- '---END---' "$ARGS_OUT"; then
    break
  fi
  sleep 0.5
done

assert_contains "$ARGS_OUT" "run"; check "stub received run" $?
assert_contains "$ARGS_OUT" "--agent"; check "stub received --agent" $?
assert_contains "$ARGS_OUT" "plan"; check "stub received plan agent" $?
assert_contains "$ARGS_OUT" "--format"; check "stub received --format" $?
assert_contains "$ARGS_OUT" "--model"; check "stub received --model" $?
assert_contains "$ARGS_OUT" "test-provider/test-model"; check "stub received model value" $?
assert_contains "$ARGS_OUT" "sed instead of using the edit tool"; check "prompt embeds description" $?
assert_contains "$ARGS_OUT" "harness in force"; check "prompt asks to consult the harness" $?

printf '\n'
if [ "$failures" -eq 0 ]; then
  printf 'All tests passed.\n'
else
  printf '%d test(s) failed.\n' "$failures" >&2
  exit 1
fi
