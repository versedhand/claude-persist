---
description: "Cancel active Ralph Wiggum loop"
allowed-tools: ["Bash(jq:*)", "Bash(ls:*)", "Bash(rm:*)", "Bash(test:*)", "Bash(grep:*)", "Bash(stat:*)", "Bash(date:*)", "Bash(basename:*)", "Bash(sed:*)"]
hide-from-slash-command-tool: "true"
---

# Cancel Ralph

Cancel the active Ralph loop. Find YOUR session ID first:

```bash
# Find session with MOST RECENTLY modified transcript (not first match)
SESSION_ID=""
NEWEST_AGE=999999
for f in /tmp/statusline-*.json; do
  sid=$(jq -r '.session_id // ""' "$f" 2>/dev/null)
  transcript="$HOME/.claude/projects/-home-rrobinson-corpus-isaac-life-corpus/${sid}.jsonl"
  if [ -f "$transcript" ]; then
    age=$(( $(date +%s) - $(stat -c %Y "$transcript") ))
    if [ "$age" -lt 60 ] && [ "$age" -lt "$NEWEST_AGE" ]; then
      NEWEST_AGE="$age"
      SESSION_ID="$sid"
    fi
  fi
done

STATE_FILE="/tmp/ralph-loop-${SESSION_ID}.md"
if [ -f "$STATE_FILE" ]; then
  ITERATION=$(grep '^iteration:' "$STATE_FILE" | sed 's/iteration: *//')
  rm -f "$STATE_FILE"
  echo "Cancelled Ralph loop (was at iteration $ITERATION)."
else
  echo "No active Ralph loop for this session."
fi
```
