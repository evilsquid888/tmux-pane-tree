#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
update_helper="${TMUX_SIDEBAR_UPDATE_HELPER:-$SCRIPT_DIR/update-pane-state.sh}"

if [ -t 0 ]; then
  payload=""
else
  payload="$(cat)"
fi

parsed="$(
  PAYLOAD="$payload" python3 - <<'PY'
import json
import os

payload = os.environ.get("PAYLOAD", "").strip()
data = {}
if payload:
    try:
        loaded = json.loads(payload)
        if isinstance(loaded, dict):
            data = loaded
    except Exception:
        data = {}

event = str(data.get("hook_event_name") or os.environ.get("CLAUDE_HOOK_EVENT_NAME") or "").strip()
notification_type = str(data.get("notification_type") or "").strip().lower()
message = str(data.get("message") or data.get("notification_type") or "").strip()

if event in ("SessionStart", "SessionEnd"):
    status = "idle"
elif event in ("UserPromptSubmit",):
    status = "running"
elif event == "Notification" and notification_type == "idle_prompt":
    status = "idle"
elif event in ("Notification", "PermissionRequest"):
    status = "needs-input"
elif event in ("Stop",):
    status = "done"
elif event in ("PostToolUseFailure",):
    status = "error"
else:
    status = "running"

print(status)
print(message)
PY
)"

status="$(printf '%s\n' "$parsed" | sed -n '1p')"
message="$(printf '%s\n' "$parsed" | sed -n '2p')"

exec "$update_helper" \
  --pane "${TMUX_PANE:-}" \
  --app claude \
  --status "$status" \
  --message "$message"
