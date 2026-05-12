# iTerm2 -CC Sidebar Conflict — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When any iTerm2 control-mode (`tmux -CC`) client is attached to a session, suppress and tear down the sidebar pane in that session, preventing the deadlock currently triggered on attach.

**Architecture:** Add two helpers to `scripts/core/lib.sh` (`session_has_control_client`, `kill_sidebar_panes_in_session`). Add a single guard at the top of `ensure-sidebar-pane.sh` that tears down any existing sidebar and exits when a -CC client is on the session. Add a parallel guard to `toggle-sidebar.sh` that shows a user-visible message instead. All other sidebar entry points already inherit this behavior through `ensure-sidebar-pane.sh` (auto-spawn hooks) or `toggle-sidebar.sh` (focus fallback), so no further guards are required (YAGNI).

**Tech Stack:** Bash 4+, tmux 3.2+ (for `#{client_control_mode}`), the project's existing fake-tmux test harness.

**Spec:** `docs/superpowers/specs/2026-05-12-itermcc-sidebar-conflict-design.md`

**Branch:** `feat/disable-in-iterm-cc` (already created and contains the spec commit)

---

## File map

- Modify: `tests/testlib.sh` — add `list-clients` arm to the fake tmux and `fake_tmux_register_client` / `fake_tmux_clear_clients` helpers.
- Modify: `scripts/core/lib.sh` — add `session_has_control_client` and `kill_sidebar_panes_in_session`.
- Modify: `scripts/features/sidebar/ensure-sidebar-pane.sh` — early-exit + teardown guard near top.
- Modify: `scripts/features/sidebar/toggle-sidebar.sh` — display-message + early-exit guard.
- Modify: `tests/core/lib_test.sh` — tests for the two new helpers.
- Create: `tests/sidebar/control_mode_test.sh` — end-to-end tests for the two script guards.

No new directories. Plan-tracking and the spec already live under `docs/superpowers/`.

---

## Task 1: Extend fake tmux with `list-clients` support

**Why first:** all subsequent tests need a way to express "session X has a -CC client." Add the harness piece before writing any test that relies on it.

**Files:**
- Modify: `tests/testlib.sh:60-188` (helpers block) and `tests/testlib.sh:930-938` (fake tmux dispatch tail)

- [ ] **Step 1: Add two test helpers**

In `tests/testlib.sh`, insert after `fake_tmux_set_pane_width()` (around line 179, before `assert_file_not_contains`):

```bash
fake_tmux_register_client() {
  local session_name="$1"
  local control_mode="${2:-0}"
  printf '%s|%s\n' "$session_name" "$control_mode" >> "$TEST_TMUX_DATA_DIR/clients.txt"
}

fake_tmux_clear_clients() {
  : > "$TEST_TMUX_DATA_DIR/clients.txt"
}
```

Also extend `fake_tmux_no_sidebar()` (around line 120) to clean up the new file. Change the existing function body to add one line:

```bash
fake_tmux_no_sidebar() {
  : > "$TEST_TMUX_DATA_DIR/toggle_panes.txt"
  printf '%%1\n' > "$TEST_TMUX_DATA_DIR/current_pane.txt"
  : > "$TEST_TMUX_DATA_DIR/commands.log"
  rm -f "$TEST_TMUX_DATA_DIR"/pane_*.meta
  rm -f "$TEST_TMUX_DATA_DIR"/capture_*.txt
  rm -f "$TEST_TMUX_DATA_DIR"/option_*.txt
  rm -f "$TEST_TMUX_DATA_DIR"/window_layout_*.txt
  rm -f "$TEST_TMUX_DATA_DIR/next_sidebar_pane_id.txt"
  rm -f "$TEST_TMUX_DATA_DIR/fail_allow_set_title.txt"
  rm -f "$TEST_TMUX_DATA_DIR/split_window_pane_title.txt"
  rm -f "$TEST_TMUX_DATA_DIR/clients.txt"
}
```

- [ ] **Step 2: Add fake `list-clients` dispatch**

In `tests/testlib.sh`, insert a new arm before the `unbind-key)` arm (around line 931). The fake supports the exact invocation `tmux list-clients -t <session> -F '#{client_control_mode}'`:

```bash
  list-clients)
    target=""
    format=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        -t) target="$2"; shift 2 ;;
        -F) format="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    clients_file="$data_dir/clients.txt"
    [ -f "$clients_file" ] || exit 0
    while IFS='|' read -r client_session client_control; do
      [ -n "$client_session" ] || continue
      if [ -n "$target" ] && [ "$client_session" != "$target" ]; then
        continue
      fi
      case "$format" in
        '#{client_control_mode}')
          printf '%s\n' "${client_control:-0}"
          ;;
        '')
          printf '%s\n' "$client_session"
          ;;
        *)
          printf '\n'
          ;;
      esac
    done < "$clients_file"
    ;;
```

- [ ] **Step 3: Smoke-test the harness manually**

Add a temporary check at the bottom of `tests/core/lib_test.sh` (will be removed in step 5):

```bash
fake_tmux_no_sidebar
fake_tmux_register_client "work" 1
fake_tmux_register_client "play" 0
output="$(tmux list-clients -t work -F '#{client_control_mode}')"
assert_eq "$output" "1"
output="$(tmux list-clients -t play -F '#{client_control_mode}')"
assert_eq "$output" "0"
output="$(tmux list-clients -t missing -F '#{client_control_mode}')"
assert_eq "$output" ""
```

- [ ] **Step 4: Run the test**

Run: `bash tests/run.sh tests/core/lib_test.sh`
Expected: PASS (the new assertions print nothing on success; failures print loud errors).

- [ ] **Step 5: Remove the temporary smoke test**

Delete the block added in step 3 from `tests/core/lib_test.sh`. The real helper tests in Task 2 supersede it.

- [ ] **Step 6: Commit**

```bash
git add tests/testlib.sh tests/core/lib_test.sh
git commit -m "test: add fake tmux list-clients support for control-mode detection

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Add `session_has_control_client` helper

**Files:**
- Modify: `scripts/core/lib.sh` (append before the `if [[ "${BASH_SOURCE[0]}" == "$0" ]]` block at line 497)
- Modify: `tests/core/lib_test.sh` (append at end)

- [ ] **Step 1: Write the failing test**

Append to `tests/core/lib_test.sh`:

```bash
fake_tmux_no_sidebar
fake_tmux_register_client "work" 1
output="$(bash scripts/core/lib.sh session_has_control_client "work" 2>&1; printf 'rc=%s\n' "$?")"
assert_contains "$output" "rc=0"

fake_tmux_no_sidebar
fake_tmux_register_client "work" 0
output="$(bash scripts/core/lib.sh session_has_control_client "work" 2>&1; printf 'rc=%s\n' "$?")"
assert_contains "$output" "rc=1"

fake_tmux_no_sidebar
output="$(bash scripts/core/lib.sh session_has_control_client "work" 2>&1; printf 'rc=%s\n' "$?")"
assert_contains "$output" "rc=1"

fake_tmux_no_sidebar
fake_tmux_register_client "other" 1
output="$(bash scripts/core/lib.sh session_has_control_client "work" 2>&1; printf 'rc=%s\n' "$?")"
assert_contains "$output" "rc=1"

fake_tmux_no_sidebar
output="$(bash scripts/core/lib.sh session_has_control_client "" 2>&1; printf 'rc=%s\n' "$?")"
assert_contains "$output" "rc=1"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/run.sh tests/core/lib_test.sh`
Expected: FAIL. The runner reports an assertion failure or `session_has_control_client: command not found` since the function does not exist yet.

- [ ] **Step 3: Implement the helper**

In `scripts/core/lib.sh`, insert immediately before the `if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then` line (currently line 497):

```bash
session_has_control_client() {
  local session_name="$1"
  [ -n "$session_name" ] || return 1
  tmux list-clients -t "$session_name" -F '#{client_control_mode}' 2>/dev/null \
    | grep -qx 1
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash tests/run.sh tests/core/lib_test.sh`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/core/lib.sh tests/core/lib_test.sh
git commit -m "feat: add session_has_control_client helper

Detects tmux clients attached to a session in control mode (-CC) using
#{client_control_mode}. Returns 1 (no -CC) on empty session names and on
older tmux that emits an empty value.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Add `kill_sidebar_panes_in_session` helper

**Files:**
- Modify: `scripts/core/lib.sh` (append right after `session_has_control_client`)
- Modify: `tests/core/lib_test.sh` (append at end)

- [ ] **Step 1: Write the failing test**

Append to `tests/core/lib_test.sh`:

```bash
fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "work" "@1" "editor" "nvim"
fake_tmux_register_pane "%90" "work" "@1" "Sidebar" "python3"
fake_tmux_add_sidebar_pane "%90" "@1"

bash scripts/core/lib.sh kill_sidebar_panes_in_session "work"

assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'kill-pane -t %90'
assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'set-option -g -u @tmux_sidebar_pane_w1'

fake_tmux_no_sidebar
fake_tmux_register_pane "%1" "work" "@1" "editor" "nvim"

bash scripts/core/lib.sh kill_sidebar_panes_in_session "work"
assert_file_not_contains "$TEST_TMUX_DATA_DIR/commands.log" 'kill-pane'

fake_tmux_no_sidebar
bash scripts/core/lib.sh kill_sidebar_panes_in_session ""
assert_file_not_contains "$TEST_TMUX_DATA_DIR/commands.log" 'kill-pane'
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/run.sh tests/core/lib_test.sh`
Expected: FAIL with `kill_sidebar_panes_in_session: command not found` or assertion failure.

- [ ] **Step 3: Implement the helper**

In `scripts/core/lib.sh`, immediately after the `session_has_control_client` function added in Task 2:

```bash
kill_sidebar_panes_in_session() {
  local session_name="$1"
  [ -n "$session_name" ] || return 0
  list_sidebar_panes_in_session "$session_name" \
    | while IFS='|' read -r pane_id window_id; do
        [ -n "$pane_id" ] || continue
        tmux kill-pane -t "$pane_id" 2>/dev/null || true
        [ -n "$window_id" ] || continue
        restore_sidebar_window_snapshot_if_unchanged "$window_id"
        clear_sidebar_window_state_options "$window_id"
      done
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash tests/run.sh tests/core/lib_test.sh`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/core/lib.sh tests/core/lib_test.sh
git commit -m "feat: add kill_sidebar_panes_in_session helper

Kills every sidebar pane in a given session and clears per-window state
options. No-op when the session name is empty or no sidebar pane exists.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Guard `ensure-sidebar-pane.sh`

This is the primary enforcement point. The guard runs *before* the existing `@tmux_sidebar_enabled` check so stale sidebars from prior crashes are also torn down.

**Files:**
- Modify: `scripts/features/sidebar/ensure-sidebar-pane.sh:1-15`
- Create: `tests/sidebar/control_mode_test.sh`

- [ ] **Step 1: Write the failing test**

Create `tests/sidebar/control_mode_test.sh`:

```bash
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
# Note: no @tmux_sidebar_enabled option set — defaults to 0.

bash scripts/features/sidebar/ensure-sidebar-pane.sh

assert_file_contains "$TEST_TMUX_DATA_DIR/commands.log" 'kill-pane -t %90'
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/run.sh tests/sidebar/control_mode_test.sh`
Expected: FAIL — current ensure-sidebar-pane.sh has no -CC handling, so test case 1 will see a `split-window` line that shouldn't be there.

- [ ] **Step 3: Add the guard to `ensure-sidebar-pane.sh`**

Replace lines 1-14 of `scripts/features/sidebar/ensure-sidebar-pane.sh`:

Find the existing block:
```bash
#!/usr/bin/env bash
set -euo pipefail

if [ "${TMUX_SIDEBAR_TRACE:-0}" = "1" ]; then
  export PS4='+ensure:${LINENO}: '
  set -x
fi

enabled="$(tmux show-options -gv @tmux_sidebar_enabled 2>/dev/null || printf '0\n')"
[ "$enabled" = "1" ] || exit 0

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
. "$SCRIPTS_DIR/core/lib.sh"
```

Replace with:
```bash
#!/usr/bin/env bash
set -euo pipefail

if [ "${TMUX_SIDEBAR_TRACE:-0}" = "1" ]; then
  export PS4='+ensure:${LINENO}: '
  set -x
fi

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
. "$SCRIPTS_DIR/core/lib.sh"

session_name="$(tmux display-message -p '#{session_name}' 2>/dev/null || true)"
if [ -n "$session_name" ] && session_has_control_client "$session_name"; then
  kill_sidebar_panes_in_session "$session_name"
  tmux set-option -g @tmux_sidebar_enabled 0 2>/dev/null || true
  exit 0
fi

enabled="$(tmux show-options -gv @tmux_sidebar_enabled 2>/dev/null || printf '0\n')"
[ "$enabled" = "1" ] || exit 0
```

The only changes versus current:
1. `SCRIPT_DIR` / `SCRIPTS_DIR` / lib.sh source moved above the `enabled` check (so the helpers are loaded before the guard).
2. New guard block between the lib source and the `enabled` check.

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash tests/run.sh tests/sidebar/control_mode_test.sh`
Expected: PASS.

- [ ] **Step 5: Run the rest of the sidebar suite for regressions**

Run: `bash tests/run.sh tests/sidebar/ensure_sidebar_pane_test.sh`
Expected: PASS. (Reordering the lib.sh source must not affect existing tests; they neither register a client nor inspect their own ordering.)

- [ ] **Step 6: Commit**

```bash
git add scripts/features/sidebar/ensure-sidebar-pane.sh tests/sidebar/control_mode_test.sh
git commit -m "fix: tear down sidebar when iTerm2 control-mode client is attached

ensure-sidebar-pane.sh now checks #{client_control_mode} on the current
session before doing anything else. When a -CC client is attached the
existing sidebar pane (if any) is killed, per-window state is cleared,
and @tmux_sidebar_enabled is set to 0. Auto-spawn is also suppressed.

Fixes the iTerm2 -CC deadlock where attaching to a session caused the
sidebar to spawn and freeze the control client.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: Guard `toggle-sidebar.sh`

User-initiated toggle gets a visible message instead of silent no-op.

**Files:**
- Modify: `scripts/features/sidebar/toggle-sidebar.sh:1-12`
- Modify: `tests/sidebar/control_mode_test.sh` (append two test cases)

- [ ] **Step 1: Write the failing test**

Append to `tests/sidebar/control_mode_test.sh`:

```bash
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
```

Note: the fake tmux logs every command to `commands.log` via the catch-all path. Verify by inspecting the file format after task 4's tests pass — the actual format will be `display-message <message>`. Adjust the substring in `assert_file_contains` if the fake formats the line differently (this is the kind of detail the impl may need to verify; if the assertion needs tweaking, fix it during step 2).

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/run.sh tests/sidebar/control_mode_test.sh`
Expected: FAIL on the first assertion of case 6 (display-message not present because toggle-sidebar.sh doesn't check control mode yet).

- [ ] **Step 3: Add the guard to `toggle-sidebar.sh`**

In `scripts/features/sidebar/toggle-sidebar.sh`, after the `lib.sh` source and before the existing `current_window` line, insert the guard. Current lines 1-10:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
. "$SCRIPTS_DIR/core/lib.sh"
ensure_script="$SCRIPT_DIR/ensure-sidebar-pane.sh"
close_script="$SCRIPT_DIR/close-sidebar.sh"

current_window="$(tmux display-message -p '#{window_id}' 2>/dev/null || true)"
```

Replace with:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
. "$SCRIPTS_DIR/core/lib.sh"
ensure_script="$SCRIPT_DIR/ensure-sidebar-pane.sh"
close_script="$SCRIPT_DIR/close-sidebar.sh"

session_name="$(tmux display-message -p '#{session_name}' 2>/dev/null || true)"
if [ -n "$session_name" ] && session_has_control_client "$session_name"; then
  tmux display-message "tmux-sidebar: disabled while iTerm2 control-mode client is attached"
  exit 0
fi

current_window="$(tmux display-message -p '#{window_id}' 2>/dev/null || true)"
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash tests/run.sh tests/sidebar/control_mode_test.sh`
Expected: PASS.

- [ ] **Step 5: Run the existing toggle test to verify no regressions**

Run: `bash tests/run.sh tests/sidebar/ensure_sidebar_pane_test.sh`
Expected: PASS. (No -CC client registered, so the new guard short-circuits to the existing flow.)

- [ ] **Step 6: Commit**

```bash
git add scripts/features/sidebar/toggle-sidebar.sh tests/sidebar/control_mode_test.sh
git commit -m "feat: show message instead of toggling sidebar under iTerm2 -CC

prefix t now surfaces 'tmux-sidebar: disabled while iTerm2 control-mode
client is attached' rather than silently doing nothing. Behavior is
unchanged for regular clients.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: Full suite + live verification handoff

**Files:** none

- [ ] **Step 1: Run the full test suite**

Run: `bash tests/run.sh`
Expected: every test passes. If any test fails, do not proceed — diagnose the regression, fix it, and re-run.

- [ ] **Step 2: Install into the live plugin dir for manual testing**

Run: `bash scripts/install-live.sh`
Expected: install succeeds; no errors. The user will perform the actual iTerm2 -CC verification (this is a manual step that cannot be automated in this environment).

- [ ] **Step 3: Hand off to the user**

Print a summary on the branch including:
- The branch name (`feat/disable-in-iterm-cc`)
- A short manual test recipe:
  1. Open iTerm2, run `tmux -CC attach -t <existing session>` (or `tmux -CC new -s test`)
  2. Confirm the iTerm window is responsive and no sidebar pane appears.
  3. From a separate terminal, `tmux attach -t <same session>` and hit `prefix t`. Confirm the message appears, no sidebar spawns.
  4. Detach the -CC client; in the regular client hit `prefix t` again. Confirm the sidebar now spawns normally.

Do not commit anything here — the work is already on the branch.

---

## Self-review

**1. Spec coverage:**
- Behavior matrix row "Regular client only" — Task 4 case 3/4 covers this implicitly; existing `ensure_sidebar_pane_test.sh` (already passing) confirms.
- "Regular client attached, then -CC joins" — Task 4 case 2.
- "-CC attached, then regular joins" — Task 4 case 1 (auto-spawn suppressed).
- "-CC detaches, regular remains" — covered by spec non-goal; no test needed.
- Session isolation — Task 4 case 4.
- Toggle message — Task 5 cases 6 and 7.
- Stale sidebar with `enabled=0` — Task 4 case 5.
- `session_has_control_client` helper — Task 2.
- `kill_sidebar_panes_in_session` helper — Task 3.
- Fake-tmux extension — Task 1.

**2. Placeholder scan:** the only soft language is in Task 5 step 1 ("Adjust the substring if the fake formats the line differently"). This is a verification note, not a placeholder — the assertion form depends on the fake tmux's command-log format which is not in my view here. Acceptable.

**3. Type / name consistency:**
- `session_has_control_client` — used identically in Tasks 2, 4, 5.
- `kill_sidebar_panes_in_session` — defined Task 3, called from Task 4 only.
- `fake_tmux_register_client` / `fake_tmux_clear_clients` — defined Task 1, used in Tasks 2, 3, 4, 5.
- File paths verified against `git ls-files`.
