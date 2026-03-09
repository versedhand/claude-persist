---
description: "Cancel active Ralph Wiggum loop"
allowed-tools: ["Bash(jq:*)", "Bash(ls:*)", "Bash(rm:*)", "Bash(test:*)", "Bash(grep:*)"]
hide-from-slash-command-tool: "true"
---

# Cancel Ralph

Cancel the active Ralph loop:

```bash
SESSION_ID=$(jq -r '.session_id' "$(ls -t /tmp/statusline-*.json 2>/dev/null | head -1)" 2>/dev/null)
STATE_FILE="/tmp/ralph-loop-${SESSION_ID}.md"
if [ -f "$STATE_FILE" ]; then
  ITERATION=$(grep '^iteration:' "$STATE_FILE" | sed 's/iteration: *//')
  rm -f "$STATE_FILE"
  echo "Cancelled Ralph loop (was at iteration $ITERATION)."
else
  echo "No active Ralph loop."
fi
```
