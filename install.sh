#!/usr/bin/env bash
#
# install.sh - install the /troubleshoot command and the oc-troubleshoot launcher
# for the current user.
#
# Creates two symlinks into the opencode configuration and PATH:
#   ~/.config/opencode/command/troubleshoot.md  -> <repo>/command/troubleshoot.md
#   ~/.local/bin/oc-troubleshoot                -> <repo>/bin/oc-troubleshoot
#
# Idempotent and non-destructive: a pre-existing real file (or a symlink to a
# different target) is backed up, never deleted. The script never touches
# opencode.json; it prints the permission rules to add instead.
#
# Usage: ./install.sh [--help]
set -euo pipefail

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BIN_SRC="${REPO}/bin/oc-troubleshoot"
CMD_SRC="${REPO}/command/troubleshoot.md"
BIN_DEST="${HOME}/.local/bin/oc-troubleshoot"
CMD_DEST="${HOME}/.config/opencode/command/troubleshoot.md"

# usage - print the help text to stdout.
usage() {
  cat <<'EOF'
install.sh - install the /troubleshoot command and the oc-troubleshoot launcher.

Creates two symlinks:
  ~/.config/opencode/command/troubleshoot.md  -> <repo>/command/troubleshoot.md
  ~/.local/bin/oc-troubleshoot                -> <repo>/bin/oc-troubleshoot

Options:
  -h, --help   show this help and exit.
EOF
}

# link_path - point dest at src, backing up (never deleting) a pre-existing
# real file or a symlink to a different target. Idempotent when already linked.
link_path() {
  local src="$1" dest="$2"
  if [ -L "$dest" ] && [ "$(readlink -f -- "$dest")" = "$(readlink -f -- "$src")" ]; then
    printf 'ok     %s\n' "$dest"
    return 0
  fi
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    local backup="${dest}.bak.$(date +%Y%m%d%H%M%S)"
    mv -- "$dest" "$backup"
    printf 'backup %s -> %s\n' "$dest" "$backup"
  fi
  mkdir -p -- "$(dirname -- "$dest")"
  ln -s -- "$src" "$dest"
  printf 'link   %s -> %s\n' "$dest" "$src"
}

# print_permission_rules - show the opencode permission rules required to let
# the current agent invoke the launcher without a permission prompt, in both the
# v1 and the native v2 configuration shapes.
print_permission_rules() {
  cat <<'EOF'

Next step (manual): allow the launcher in your opencode configuration, then
restart opencode (the command is read at startup).

OpenCode v1 (also accepted by v2), inside the "bash" permission object, AFTER
the catch-all "*" rule (the last matching rule wins):

  "permission": {
    "bash": { "*oc-troubleshoot*": "allow" }
  }

OpenCode v2 native, in the ordered "permissions" array:

  "permissions": [
    { "action": "shell", "resource": "*oc-troubleshoot*", "effect": "allow" }
  ]

Back up and validate the file and check it loads before restarting.
EOF
}

# main - create the two symlinks and print the follow-up instructions.
main() {
  case "${1:-}" in
    -h | --help) usage; exit 0 ;;
    "") ;;
    *) printf 'install.sh: unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac

  [ -f "$BIN_SRC" ] || { printf 'install.sh: missing %s\n' "$BIN_SRC" >&2; exit 1; }
  [ -f "$CMD_SRC" ] || { printf 'install.sh: missing %s\n' "$CMD_SRC" >&2; exit 1; }
  chmod +x -- "$BIN_SRC"

  link_path "$BIN_SRC" "$BIN_DEST"
  link_path "$CMD_SRC" "$CMD_DEST"

  printf '\nInstalled. Ensure %s is on your PATH.\n' "$(dirname -- "$BIN_DEST")"
  print_permission_rules
}

main "$@"
