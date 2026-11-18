# AGENTS.md

## Project

`oc-troubleshoot` installs an OpenCode command (`/troubleshoot`) and a launcher
(`oc-troubleshoot`) that start a background `plan` session to analyse a model
mistake and propose harness/config consolidations.

Layout:

```
command/troubleshoot.md   OpenCode command prompt (installed as a symlink)
bin/oc-troubleshoot       bash launcher (installed as a symlink)
tests/run.sh              test suite (syntax + CLI + detection + background launch)
tests/stub/opencode       recording stub used by the tests
install.sh / uninstall.sh idempotent symlink management
```

The tool is standalone: it depends only on the `opencode` CLI. The source
session, working directory and model are read from the OpenCode database with
read-only queries (`opencode db` on v1, `opencode session list --format json`
on v2). The new session is started with `opencode run` detached via `setsid` — no
terminal or multiplexer is imposed; the launcher reports the new session id so
the user reopens it however they like.

## Commands

```bash
bash -n bin/oc-troubleshoot          # syntax check
tests/run.sh                         # full suite (uses the opencode stub)
oc-troubleshoot --dry-run <<<'text'  # inspect resolution without launching
```

`tests/integration-v2.sh` is an opt-in test against a real v2 binary
(`OC_TROUBLESHOOT_V2_BIN`); it runs in an isolated `HOME` and is not part of the
default green block.

## Working procedure

**Definition of green.** A change is only done when this passes from the repo
root:

```bash
bash -n bin/oc-troubleshoot
tests/run.sh
```

Run it after **every** batch of edits and before writing any summary. Never
present an intermediate red state.

**Change discipline.**

- One concern per edit; keep diffs small and atomic.
- Each shell function carries a comment block stating its contract and *why*.
  `shellcheck` is not a required dependency; `bash -n` plus review is the floor.
- Never start a real OpenCode session in tests: use `tests/stub/opencode` via
  `OC_TROUBLESHOOT_OPENCODE`.

## Conventions

- The launcher never edits files and never writes to the OpenCode database: it
  only runs read-only queries and starts a detached `opencode run`.
- OpenCode v1 and v2 are both supported. The **new** session id is parsed from
  `opencode run --format json` (both versions), and the session is given an
  explicit `Troubleshoot: <short>` title so it is never mistaken for a fork of
  the source session. **Source detection** is best effort: `opencode db` on v1
  when available, otherwise `opencode session list --format json` (v2, where
  `opencode db` was removed), otherwise none. Never hardcode one table or
  assume `opencode db` exists.
- The test suite unsets `OPENCODE_SESSION_ID` and `CLAUDE_SESSION_ID` before
  stub-based checks, so running the suite inside a real OpenCode session does
  not override the stub.
- The tool never references a specific user's harness paths or external tools:
  the generated Plan prompt only talks about "the harness in force".
- `opencode.json` is **never** modified by `install.sh`; it prints the required
  permission rule and the user applies it.
- Symlinks follow the install/uninstall discipline: back up real files, remove
  only symlinks that point into this repo.
