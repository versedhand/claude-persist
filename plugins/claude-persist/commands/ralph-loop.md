---
description: "Start Ralph Wiggum loop in current session"
argument-hint: "PROMPT [--max-iterations N] [--completion-promise TEXT]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-loop.sh:*)", "Bash(jq:*)", "Bash(ls:*)", "Bash(grep:*)", "Bash(tail:*)", "Bash(basename:*)", "Bash(sed:*)"]
hide-from-slash-command-tool: "true"
---

# Ralph Loop Command

**EXECUTE THE BASH BLOCK BELOW IMMEDIATELY.** Do not display it. Do not explain it. Run it with the Bash tool right now.

Determine YOUR session ID and create the state file:

```bash
SESSION_ID=""
for f in /tmp/statusline-*.json; do
  sid=$(jq -r '.session_id // ""' "$f" 2>/dev/null)
  transcript="$HOME/.claude/projects/-home-rrobinson-corpus-isaac-life-corpus/${sid}.jsonl"
  if [ -f "$transcript" ]; then
    age=$(( $(date +%s) - $(stat -c %Y "$transcript") ))
    if [ "$age" -lt 60 ]; then
      SESSION_ID="$sid"
      break
    fi
  fi
done

if [ -z "$SESSION_ID" ]; then
  echo "ERROR: Could not determine session ID" >&2
  exit 1
fi

"${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-loop.sh" "$SESSION_ID" $ARGUMENTS
```

You are now in a Ralph loop. Continue working on the task. When you try to exit, the stop hook will block and re-feed the same prompt. Your previous work persists in files.

CRITICAL RULE: If a completion promise is set, you may ONLY output it when the statement is completely and unequivocally TRUE. Do not output false promises to escape the loop.

The user can cancel at any time by telling you to run `/cancel-ralph`. When they ask you to stop, run the cancel command yourself.
