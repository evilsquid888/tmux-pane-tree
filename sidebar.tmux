#!/usr/bin/env bash
CURRENT_DIR="$(CDPATH= cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

main() {
    tmux run-shell -b "$CURRENT_DIR/scripts/configure-pane-border-format.sh"

    tmux bind-key t run-shell -b "$CURRENT_DIR/scripts/toggle-sidebar.sh"
    tmux bind-key T run-shell -b "$CURRENT_DIR/scripts/focus-sidebar.sh"

    tmux set-hook -g "client-active[198]" "run-shell -b '$CURRENT_DIR/scripts/ensure-sidebar-pane.sh'"
    tmux set-hook -g "client-attached[199]" "run-shell -b '$CURRENT_DIR/scripts/ensure-sidebar-pane.sh'"
    tmux set-hook -g "client-session-changed[200]" "run-shell -b '$CURRENT_DIR/scripts/ensure-sidebar-pane.sh #{pane_id} #{window_id}'"
    tmux set-hook -g "window-pane-changed[201]" "run-shell -b '$CURRENT_DIR/scripts/ensure-sidebar-pane.sh #{pane_id} #{window_id}'"
    tmux set-hook -g "client-focus-in[202]" "run-shell -b '$CURRENT_DIR/scripts/ensure-sidebar-pane.sh #{pane_id} #{window_id}'"
    tmux set-hook -g "after-select-window[203]" "run-shell -b '$CURRENT_DIR/scripts/ensure-sidebar-pane.sh #{pane_id} #{window_id}'"
    tmux set-hook -g "client-focus-in[204]" "run-shell -b '$CURRENT_DIR/scripts/remember-main-pane.sh #{pane_id}'"
    tmux set-hook -g "client-focus-in[205]" "run-shell -b '$CURRENT_DIR/scripts/clear-pane-state.sh #{pane_id}'"
    tmux set-hook -g "after-split-window[206]" "run-shell -b '$CURRENT_DIR/scripts/refresh-sidebar.sh'"
    tmux set-hook -g "after-new-window[207]" "run-shell -b '$CURRENT_DIR/scripts/refresh-sidebar.sh'"
    tmux set-hook -g "pane-exited[208]" "run-shell -b '$CURRENT_DIR/scripts/handle-pane-exited.sh #{hook_pane} #{hook_window}'"
    tmux set-hook -g "window-layout-changed[209]" "run-shell -b '$CURRENT_DIR/scripts/refresh-sidebar.sh'"
    tmux set-hook -g "window-renamed[210]" "run-shell -b '$CURRENT_DIR/scripts/refresh-sidebar.sh'"
    tmux set-hook -g "client-session-changed[211]" "run-shell -b '$CURRENT_DIR/scripts/remember-main-pane.sh #{pane_id}'"
    tmux set-hook -g "after-select-window[212]" "run-shell -b '$CURRENT_DIR/scripts/remember-main-pane.sh #{pane_id}'"
    tmux set-hook -g "after-select-pane[213]" "run-shell -b '$CURRENT_DIR/scripts/remember-main-pane.sh #{pane_id}'"
    tmux set-hook -g "window-pane-changed[214]" "run-shell -b '$CURRENT_DIR/scripts/remember-main-pane.sh #{pane_id}'"
    tmux set-hook -g "session-window-changed[215]" "run-shell -b '$CURRENT_DIR/scripts/ensure-sidebar-pane.sh #{pane_id} #{window_id}'"
    tmux set-hook -g "session-window-changed[216]" "run-shell -b '$CURRENT_DIR/scripts/remember-main-pane.sh #{pane_id}'"
    tmux set-hook -g "after-select-window[217]" "run-shell -b '$CURRENT_DIR/scripts/clear-pane-state.sh #{pane_id}'"
    tmux set-hook -g "after-select-pane[218]" "run-shell -b '$CURRENT_DIR/scripts/clear-pane-state.sh #{pane_id}'"

    tmux run-shell -b "$CURRENT_DIR/scripts/apply-key-overrides.sh"
}
main
