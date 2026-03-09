#!/bin/bash

# Ralph Wiggum Stop Hook (forked from anthropics/claude-code)
# Prevents session exit when a ralph-loop is active.
# Feeds the original prompt back to continue the loop.
#
# Fixes applied (vs upstream):
#   1. Session-scoped state files (fixes #15047 cross-session interference)
#   2. Exit 2 + stderr protocol (fixes #10412 plugin hook blocking)
#   3. Removed set -euo pipefail (fixes silent crash on grep no-match)
#   4. stop_hook_active guard (prevents infinite loops)

# DO NOT use set -euo pipefail — grep returns exit 1 on no match,
# which with pipefail propagates and with set -e kills the script silently.

# Read hook input from stdin
HOOK_INPUT=$(cat)

# Prevent infinite loops: if stop hook already active, allow exit
STOP_HOOK_ACTIVE=$(echo "$HOOK_INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null || echo "false")
if [[ "$STOP_HOOK_ACTIVE" == "true" ]]; then
  exit 0
fi

# Extract session ID for session-scoped state file
SESSION_ID=$(echo "$HOOK_INPUT" | jq -r '.session_id // ""' 2>/dev/null || echo "")
if [[ -z "$SESSION_ID" ]]; then
  exit 0
fi

RALPH_STATE_FILE="/tmp/ralph-loop-${SESSION_ID}.md"

if [[ ! -f "$RALPH_STATE_FILE" ]]; then
  exit 0
fi

# Parse markdown frontmatter — use || true on all greps to prevent crash
FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$RALPH_STATE_FILE")
ITERATION=$(echo "$FRONTMATTER" | grep '^iteration:' | sed 's/iteration: *//' || true)
MAX_ITERATIONS=$(echo "$FRONTMATTER" | grep '^max_iterations:' | sed 's/max_iterations: *//' || true)
COMPLETION_PROMISE=$(echo "$FRONTMATTER" | grep '^completion_promise:' | sed 's/completion_promise: *//' | sed 's/^"\(.*\)"$/\1/' || true)

# Validate numeric fields
if [[ ! "$ITERATION" =~ ^[0-9]+$ ]]; then
  echo "Ralph loop: State file corrupted (iteration='$ITERATION'). Stopping." >&2
  rm -f "$RALPH_STATE_FILE"
  exit 0
fi

if [[ -z "$MAX_ITERATIONS" ]] || [[ ! "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
  MAX_ITERATIONS=0
fi

# Check max iterations
if [[ $MAX_ITERATIONS -gt 0 ]] && [[ $ITERATION -ge $MAX_ITERATIONS ]]; then
  echo "Ralph loop: Max iterations ($MAX_ITERATIONS) reached." >&2
  rm -f "$RALPH_STATE_FILE"
  exit 0
fi

# Check completion promise in transcript (if promise is set)
if [[ -n "$COMPLETION_PROMISE" ]] && [[ "$COMPLETION_PROMISE" != "null" ]]; then
  TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path // ""' 2>/dev/null || echo "")

  if [[ -n "$TRANSCRIPT_PATH" ]] && [[ -f "$TRANSCRIPT_PATH" ]]; then
    LAST_LINE=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" 2>/dev/null | tail -1 || true)
    if [[ -n "$LAST_LINE" ]]; then
      LAST_OUTPUT=$(echo "$LAST_LINE" | jq -r '
        .message.content |
        map(select(.type == "text")) |
        map(.text) |
        join("\n")
      ' 2>/dev/null || echo "")

      if [[ -n "$LAST_OUTPUT" ]]; then
        PROMISE_TEXT=$(echo "$LAST_OUTPUT" | perl -0777 -pe 's/.*?<promise>(.*?)<\/promise>.*/$1/s; s/^\s+|\s+$//g; s/\s+/ /g' 2>/dev/null || echo "")
        if [[ -n "$PROMISE_TEXT" ]] && [[ "$PROMISE_TEXT" = "$COMPLETION_PROMISE" ]]; then
          echo "Ralph loop: Completion promise detected." >&2
          rm -f "$RALPH_STATE_FILE"
          exit 0
        fi
      fi
    fi
  fi
fi

# Continue loop — increment iteration
NEXT_ITERATION=$((ITERATION + 1))

# Extract prompt (everything after closing ---)
PROMPT_TEXT=$(awk '/^---$/{i++; next} i>=2' "$RALPH_STATE_FILE")

if [[ -z "$PROMPT_TEXT" ]]; then
  echo "Ralph loop: No prompt found in state file. Stopping." >&2
  rm -f "$RALPH_STATE_FILE"
  exit 0
fi

# Update iteration in state file
TEMP_FILE="${RALPH_STATE_FILE}.tmp.$$"
sed "s/^iteration: .*/iteration: $NEXT_ITERATION/" "$RALPH_STATE_FILE" > "$TEMP_FILE"
mv "$TEMP_FILE" "$RALPH_STATE_FILE"

# Build status line
if [[ -n "$COMPLETION_PROMISE" ]] && [[ "$COMPLETION_PROMISE" != "null" ]]; then
  STATUS="Ralph iteration $NEXT_ITERATION/$MAX_ITERATIONS | Complete: <promise>$COMPLETION_PROMISE</promise>"
else
  STATUS="Ralph iteration $NEXT_ITERATION/${MAX_ITERATIONS:-∞}"
fi

# Block exit: exit 2 + reason on stderr (NOT JSON stdout — that's the #10412 bug)
echo "[$STATUS] $PROMPT_TEXT" >&2
exit 2
