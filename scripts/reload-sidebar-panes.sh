#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib.sh"

sidebar_command="$(sidebar_ui_command "$SCRIPT_DIR")"

list_sidebar_panes \
  | while IFS='|' read -r pane_id _window_id; do
      [ -n "$pane_id" ] || continue
      tmux respawn-pane -k -t "$pane_id" "$sidebar_command"
      tmux set-option -p -t "$pane_id" allow-set-title off
    done
