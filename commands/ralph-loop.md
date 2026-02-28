---
description: "Start Ralph Wiggum loop in current session"
argument-hint: "PROMPT [--max-iterations N] [--completion-promise TEXT]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-loop.sh:*)", "Bash(jq:*)", "Bash(ls:*)"]
hide-from-slash-command-tool: "true"
---

# Ralph Loop Command

First, determine the session ID, then execute the setup script:

```bash
SESSION_ID=$(jq -r '.session_id' "$(ls -t /tmp/statusline-*.json 2>/dev/null | head -1)" 2>/dev/null)
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-loop.sh" "$SESSION_ID" $ARGUMENTS
```

You are now in a Ralph loop. Continue working on the task. When you try to exit, the stop hook will block and re-feed the same prompt. Your previous work persists in files.

CRITICAL RULE: If a completion promise is set, you may ONLY output it when the statement is completely and unequivocally TRUE. Do not output false promises to escape the loop.

The user can cancel at any time by telling you to run `/cancel-ralph`. When they ask you to stop, run the cancel command yourself.
