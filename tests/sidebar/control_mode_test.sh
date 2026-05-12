#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/../testlib.sh"

# 1. ensure-sidebar-pane.sh bails when a -CC client is attached.
fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "work" "@1" "editor" "nvim"
fake_tmux_register_client "work" 1
printf '1\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_enabled.txt"

bash scripts/features/sidebar/ensure-sidebar-pane.sh

assert_file_not_contains "$TEST_TMUX_DATA_DIR/commands.log" 'split-window'
assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'set-option -g @tmux_sidebar_enabled 0'

# 2. ensure-sidebar-pane.sh tears down an existing sidebar pane when -CC is attached.
fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "work" "@1" "editor" "nvim"
fake_tmux_register_pane "%90" "work" "@1" "Sidebar" "python3"
fake_tmux_add_sidebar_pane "%90" "@1"
fake_tmux_register_client "work" 1
printf '1\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_enabled.txt"

bash scripts/features/sidebar/ensure-sidebar-pane.sh

assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'kill-pane -t %90'
assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'set-option -g @tmux_sidebar_enabled 0'

# 3. Empty client_control_mode (older tmux) — sidebar still spawns normally.
fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "work" "@1" "editor" "nvim"
fake_tmux_register_client "work" ""
printf '1\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_enabled.txt"

bash scripts/features/sidebar/ensure-sidebar-pane.sh

assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'split-window -t %1 -h -b -d -f -l 25'

# 4. Session isolation: -CC on session A does not block sidebar on session B.
fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "play" "@2" "editor" "nvim"
fake_tmux_register_client "work" 1
printf '1\n' > "$TEST_TMUX_DATA_DIR/option__tmux_sidebar_enabled.txt"

bash scripts/features/sidebar/ensure-sidebar-pane.sh

assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'split-window -t %1 -h -b -d -f -l 25'

# 5. Teardown still runs even when @tmux_sidebar_enabled is already 0 (stale sidebar).
fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "work" "@1" "editor" "nvim"
fake_tmux_register_pane "%90" "work" "@1" "Sidebar" "python3"
fake_tmux_add_sidebar_pane "%90" "@1"
fake_tmux_register_client "work" 1

bash scripts/features/sidebar/ensure-sidebar-pane.sh

assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'kill-pane -t %90'

# 6. toggle-sidebar.sh shows a message and does not enable the sidebar when -CC is attached.
fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "work" "@1" "editor" "nvim"
fake_tmux_register_client "work" 1

bash scripts/features/sidebar/toggle-sidebar.sh

assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'display-message tmux-sidebar: disabled while iTerm2 control-mode client is attached'
assert_file_not_contains "$TEST_TMUX_DATA_DIR/commands.log" 'set-option -g @tmux_sidebar_enabled 1'
assert_file_not_contains "$TEST_TMUX_DATA_DIR/commands.log" 'split-window'

# 7. toggle-sidebar.sh still works normally when no -CC client is attached.
fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "work" "@1" "editor" "nvim"
fake_tmux_register_client "work" 0

bash scripts/features/sidebar/toggle-sidebar.sh

assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'set-option -g @tmux_sidebar_enabled 1'
assert_file_not_contains "$TEST_TMUX_DATA_DIR/commands.log" 'display-message tmux-sidebar: disabled'
