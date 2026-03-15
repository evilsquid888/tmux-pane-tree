#!/usr/bin/env bash
set -euo pipefail

PLUGIN_DIR="${TMUX_SIDEBAR_PLUGIN_DIR:-$HOME/.tmux/plugins/tmux-sidebar}"
EVENT="${CODEX_EVENT:-}"
RAW_STATUS="${CODEX_STATUS:-}"
MESSAGE="${CODEX_MESSAGE:-}"

status=""
case "$EVENT" in
  error|fail|failure)
    status="error"
    ;;
  permission*|approve*|approval-requested|input-required)
    status="needs-input"
    ;;
  session-start|idle-prompt)
    status="idle"
    ;;
  start)
    status="running"
    ;;
  agent-turn-complete|complete|completed|done|finish|finished|stop|stopped|task-complete|turn-complete|session-end)
    status="done"
    ;;
esac

if [ -z "$status" ]; then
  case "$RAW_STATUS" in
    running)        status="running" ;;
    error|failed)   status="error" ;;
    idle|ready)     status="idle" ;;
    done|completed|finished|stopped) status="done" ;;
    needs-input)    status="needs-input" ;;
    *)              status="${RAW_STATUS:-done}" ;;
  esac
fi

exec "$PLUGIN_DIR/scripts/update-pane-state.sh" \
  --pane "${TMUX_PANE:-}" \
  --app codex \
  --status "$status" \
  --message "$MESSAGE"
