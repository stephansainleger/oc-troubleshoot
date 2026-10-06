# oc-troubleshoot

Start a new **OpenCode `plan` session** that analyses a mistake made by the
model and proposes consolidations of the active harness and configuration.

The session runs in the background with `opencode run` (detached with `setsid`):
no terminal, no multiplexer, no display is imposed. It uses the same `auth.json`
as the session you started it from. The launcher prints the new session id and
the log path, so you can reopen it however you like (`opencode -s <id>`, your
own terminal, a picker, ...).

## How it works

```
/troubleshoot  ──►  command/troubleshoot.md   (asks you what went wrong)
                       └─ stdin ──►  bin/oc-troubleshoot
                                        ├─ source session  ← opencode db (v1) / session list (v2)
                                        ├─ cwd + model      ← source session, else sensible defaults
                                        └─ setsid opencode run --agent plan --format json "<prompt>"
                                             └─ new session id parsed from the JSON event stream
```

- `bin/oc-troubleshoot` reads the description on **stdin**, resolves the source
  session id, the working directory and the current model, then starts
  `opencode run --agent plan` in the background and reports the new session id.
- The new session id is parsed from the run's `--format json` stream, which works
  on both v1 and v2 (v2 removed the `opencode db` command).
- The Plan session re-reads the project and the harness in force with its own
  tools and outputs a **plan only** (Plan mode is read-only).

It is standalone: it only needs the `opencode` CLI.

## Requirements

- [OpenCode](https://opencode.ai) CLI, **v1 or v2** (tested against 1.18.x and
  the v2 beta `opencode2`).

## Compatibility with OpenCode v1 and v2

- **New session capture** uses `opencode run --format json`, available in both
  versions — independent of the database.
- **Source session detection** (best effort): `opencode db` when available (v1,
  `session` table; v2 GA, `session_v2` table), otherwise
  `opencode session list --format json` (v2 GA), otherwise no source (pass
  `--session <id>` to be explicit). The `--dry-run` output shows the resolved
  `source` method and `schema`.
- The v2 **beta** we tested has neither `opencode db` nor `opencode session`, so
  source detection is skipped there (the plan session runs with opencode's
  default model and no "source session" line); capture still works.
- The command file is installed under `~/.config/opencode/command/` (v2 also
  discovers this legacy directory).
- Permissions accept the v1 shape; a native v2 shape is printed too by
  `install.sh`.

```sh
# Example permission rules
# v1 (also accepted by v2):
{ "permission": { "bash": { "*oc-troubleshoot*": "allow" } } }
# v2 native:
{ "permissions": [ { "action": "shell", "resource": "*oc-troubleshoot*", "effect": "allow" } ] }
```

## Install

```sh
git clone <repo> ~/dev/oc-troubleshoot
cd oc-troubleshoot
./install.sh
```

`install.sh` is idempotent. It creates two symlinks (backing up, never
deleting, any pre-existing real file):

```
~/.config/opencode/command/troubleshoot.md  -> <repo>/command/troubleshoot.md
~/.local/bin/oc-troubleshoot                -> <repo>/bin/oc-troubleshoot
```

Then add the permission rule it prints to your opencode configuration. For
OpenCode v1 (also accepted by v2), inside the `bash` permission object after
the catch-all `*` rule:

```json
"*oc-troubleshoot*": "allow"
```

For the native v2 shape, use the `permissions` array:

```json
{ "permissions": [ { "action": "shell", "resource": "*oc-troubleshoot*", "effect": "allow" } ] }
```

Restart OpenCode: commands are loaded at startup.

## Usage

Inside OpenCode:

```
/troubleshoot
```

Then describe the mistake when asked. Or pass it inline:

```
/troubleshoot the model ran sed -i instead of using the edit tool
```

From the shell:

```sh
oc-troubleshoot <<'EOF'
The model ran sed -i instead of using the edit tool.
EOF
```

The launcher prints the new session id and the log path:

```
analysis session started
session id : ses_xxxxxxxx
reopen with: opencode -s ses_xxxxxxxx
log        : ~/.local/state/oc-troubleshoot/20261007T213000-12345.log
```

Options:

```
--session ID        source session id (default: auto-detect)
--model PROVIDER/M  model for the plan session (default: source session model, else opencode default)
--cwd DIR           working directory (default: source session's directory)
--dry-run           print what would be run, do not start anything
-h, --help / -V, --version
```

Environment: `OC_TROUBLESHOOT_OPENCODE` (opencode path),
`OC_TROUBLESHOOT_ID_TIMEOUT` (seconds to wait for the new session id, default 5).

### Source session detection

Without `--session`, the launcher picks the most recently updated top-level
session whose directory matches the current one (read from the OpenCode
database). Pass `--session <id>` to be explicit when several sessions run in
the same directory.

## Uninstall

```sh
./uninstall.sh
```

Removes the two symlinks (only if they point into this checkout), then drop the
permission rule and restart OpenCode.

## Tests

```sh
bash -n bin/oc-troubleshoot
tests/run.sh
```

`tests/run.sh` runs syntax and CLI checks, session-detection checks (v1 and v2
schemas) and a background-launch check, all against a recording stub for
`opencode` (no real session).

`tests/integration-v2.sh` is an opt-in integration test against a real v2
binary. It runs in an isolated `HOME` and never touches your OpenCode
installation:

```sh
npm install --prefix /tmp/oc-v2 @opencode-ai/cli@next
OC_TROUBLESHOOT_V2_BIN=/tmp/oc-v2/node_modules/.bin/opencode2 tests/integration-v2.sh
rm -rf /tmp/oc-v2
```

## License

AGPLv3. See `LICENSE`.
