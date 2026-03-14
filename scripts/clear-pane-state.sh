#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib.sh"
refresh_helper="${TMUX_SIDEBAR_REFRESH_HELPER:-$SCRIPT_DIR/refresh-sidebar.sh}"

pane_id="${1:-}"
[ -n "$pane_id" ] || exit 0

state_file="$(print_state_dir)/pane-$pane_id.json"
[ -f "$state_file" ] || exit 0

app="$(json_get_string "$state_file" "app")"
status="$(json_get_string "$state_file" "status")"
case "$app:$status" in
  *:needs-input|*:done)
    perl -0pi -e 's/"status":"[^"]*"/"status":"idle"/' "$state_file"
    "$refresh_helper" >/dev/null 2>&1 || true
    ;;
esac
