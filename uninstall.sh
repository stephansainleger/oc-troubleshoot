#!/usr/bin/env bash
#
# uninstall.sh - remove exactly what install.sh created for the current user.
#
# Removes the two symlinks only when they still point into this repository; a
# real file or a foreign symlink left there is reported and kept. Idempotent:
# missing files are reported, not fatal.
#
# Usage: ./uninstall.sh [--help]
set -euo pipefail

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BIN_DEST="${HOME}/.local/bin/oc-troubleshoot"
CMD_DEST="${HOME}/.config/opencode/command/troubleshoot.md"

# usage - print the help text to stdout.
usage() {
  cat <<'EOF'
uninstall.sh - remove the /troubleshoot command and the oc-troubleshoot launcher.

Removes the two symlinks if (and only if) they point into this repository.
Options:
  -h, --help   show this help and exit.
EOF
}

# remove_link - remove dest when it is a symlink resolving inside the repo.
remove_link() {
  local dest="$1" resolved
  if [ -L "$dest" ]; then
    resolved="$(readlink -f -- "$dest" || true)"
    case "$resolved" in
      "${REPO}/"*)
        rm -f -- "$dest"
        printf 'removed %s\n' "$dest"
        ;;
      *)
        printf 'kept    %s (points outside the repository: %s)\n' "$dest" "$resolved"
        ;;
    esac
  elif [ -e "$dest" ]; then
    printf 'kept    %s (not a symlink)\n' "$dest"
  fi
}

# main - remove the symlinks and print the follow-up reminder.
main() {
  case "${1:-}" in
    -h | --help) usage; exit 0 ;;
    "") ;;
    *) printf 'uninstall.sh: unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac

  remove_link "$BIN_DEST"
  remove_link "$CMD_DEST"

  cat <<'EOF'

You may also remove the "oc-troubleshoot" bash rule from your opencode
configuration, and restart opencode.
EOF
}

main "$@"
