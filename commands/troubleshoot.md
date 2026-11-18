---
description: Analyse a model mistake in a detached Plan session and propose harness consolidations
agent: build
---

You are preparing a retrospective on a mistake made by the model.

## 1. Get the description

- If the following argument is not empty, it is the description to analyse:

  <mistake>$ARGUMENTS</mistake>

- Otherwise, ask the user (via the `question` tool) to describe the mistake
  precisely: what was expected, what happened instead, and any session, file,
  command or project involved.

## 2. Launch the analysis session

Pass the description **verbatim** on stdin to the launcher, via a heredoc:

```bash
oc-troubleshoot <<'TROUBLESHOOT_EOF'
<verbatim description from the user>
TROUBLESHOOT_EOF
```

The launcher starts a background OpenCode `plan` session with the same
`auth.json` as the current session, then prints its session id and the log
path.

## 3. Report

Report the new session id and how to reopen it: `opencode -s <id>`. The launcher
also prints the path of the log capturing the run.

Do not analyse the mistake yourself and do not call any other tool: all the
analysis work happens in the detached Plan session.
