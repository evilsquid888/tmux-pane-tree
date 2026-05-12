# Disable sidebar when an iTerm2 control-mode client is attached

Date: 2026-05-12
Branch: `feat/disable-in-iterm-cc`

## Problem

When iTerm2 attaches to a tmux session in control mode (`tmux -CC`), iTerm renders panes as native iTerm splits/tabs and tmux acts as a backend speaking the control protocol. The current `tmux-pane-tree` plugin auto-spawns a curses sidebar pane on `client-attached` / `client-active` hooks. That split is incompatible with control mode: the iTerm window launches, the sidebar pane is created, and the control client deadlocks — the user cannot type into the iTerm window.

The conflict is structural, not cosmetic:

- tmux panes are session-scoped. All clients attached to a session see the same panes, so a sidebar that exists for one client exists for all of them.
- In control mode, iTerm consumes a DCS-wrapped framing protocol from tmux and renders panes natively. Spontaneous splits during attach, combined with a curses UI emitting its own escape sequences inside that pane, hangs the client.
- There is no way to make the sidebar "invisible to the -CC client only" — if it exists in the session, iTerm sees it.

## Goal

When any control-mode client is attached to a session, that session must not contain a sidebar pane. All sidebar entry points must respect this, and the plugin must tear down any pre-existing sidebar pane the moment a -CC client attaches.

Non-goal: making the sidebar work *with* iTerm -CC. That would require rendering inside iTerm rather than as a tmux pane and is out of scope.

## Design summary

Single rule, enforced at every sidebar lifecycle entry point:

> **If any attached client on the relevant session reports `client_control_mode = 1`, the sidebar is disabled for that session.** "Disabled" means: do not create, kill any that exist, and surface a user-visible message on explicit toggle.

Implementation has three pieces:

1. A small helper layer in `scripts/core/lib.sh` that detects control mode and tears down sidebars by session.
2. Guards at each sidebar entry point (`ensure-sidebar-pane.sh`, `toggle-sidebar.sh`, `focus-sidebar.sh`, `notify-sidebar.sh`, `on-pane-focus.sh`).
3. Reuse of the existing `client-attached` hook (already wired in `tmux-pane-tree.tmux:9`) to trigger teardown — no new hook needs to be registered, because `ensure-sidebar-pane.sh` becomes the place where teardown runs.

### Behavior matrix

| Scenario | Result |
|---|---|
| Regular client only on session | Sidebar works as today. |
| -CC client only on session | No sidebar; auto-spawn is suppressed. |
| Regular client attached, then -CC client joins | `client-attached` fires → `ensure-sidebar-pane.sh` sees a -CC client → kills the existing sidebar pane, clears window state. Regular client loses sidebar. |
| -CC client attached, then regular client joins | `client-attached` fires → `ensure-sidebar-pane.sh` sees a -CC client → does not create a sidebar. Regular client has no sidebar. |
| -CC client detaches, regular client remains | Sidebar stays gone until the user toggles `prefix t`. (No auto-recreate; see Non-goals.) |
| -CC on session A, regular on session B | Session B is unaffected. Sidebar works normally on B. |
| User hits `prefix t` while -CC is attached | `toggle-sidebar.sh` displays `"tmux-sidebar: disabled while iTerm2 control-mode client is attached"` and exits without changing state. |

The "regular client loses sidebar because -CC joined" case is the only real downside. Tradeoff is intentional: the alternative is iTerm deadlock, which is strictly worse.

## Implementation surface

### New helpers in `scripts/core/lib.sh`

```bash
# Returns 0 if any client attached to $session_name is in control mode.
session_has_control_client() {
  local session_name="$1"
  [ -n "$session_name" ] || return 1
  tmux list-clients -t "$session_name" -F '#{client_control_mode}' 2>/dev/null \
    | grep -qx 1
}

# Kills every sidebar pane in $session_name and clears window-scoped state.
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

Both helpers reuse existing primitives: `list_sidebar_panes_in_session`, `restore_sidebar_window_snapshot_if_unchanged`, `clear_sidebar_window_state_options` already exist in `lib.sh`.

The `client_control_mode` format string is supported in tmux 3.2+. If the format is empty on older tmux, `grep -qx 1` returns false, which is the correct safe default (treat as not-control-mode).

### Guard in `ensure-sidebar-pane.sh`

The guard runs **before** the existing `@tmux_sidebar_enabled` early-exit (currently at line 10), so that a stale sidebar pane from a previous crash is still torn down even when `enabled` is already 0.

Restructure the head of the file to:

```bash
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

# ...existing target_pane / current_window resolution and the rest unchanged
```

The session is looked up via `display-message` (without `-t`) because hooks run in the context of the triggering client/session — that's the right session for the -CC check. The guard is placed *before* the lock acquisition so the early-exit path stays cheap and lock-free. The `@tmux_sidebar_enabled = 0` write keeps the toggle button consistent (next `prefix t` will treat the sidebar as off).

### Guard in `toggle-sidebar.sh`

After resolving `current_window` (line 10), add:

```bash
session_name="$(tmux display-message -p -t "$current_window" '#{session_name}' 2>/dev/null || true)"
if [ -n "$session_name" ] && session_has_control_client "$session_name"; then
  tmux display-message "tmux-sidebar: disabled while iTerm2 control-mode client is attached"
  exit 0
fi
```

User-initiated toggles get a visible message; hook-initiated auto-spawn is silent.

### Guard in other entry points

`focus-sidebar.sh`, `notify-sidebar.sh`, `on-pane-focus.sh`, `refresh-sidebar.sh`: these read or refresh sidebar state but do not create panes. Add the same `session_has_control_client` early-return (silent) at the top, after `current_window` is resolved. Rationale: keep behavior consistent — if there shouldn't be a sidebar, there shouldn't be work happening either. These guards are defensive belt-and-suspenders; `ensure-sidebar-pane.sh`'s teardown is the real enforcement.

### No changes to `tmux-pane-tree.tmux`

The existing `client-attached[199]` hook already runs `ensure-sidebar-pane.sh`. Because that script now detects -CC and tears down, no new hook registration is needed.

## Non-goals

- **Auto-recreate on -CC detach.** When the last -CC client detaches, the sidebar does not come back automatically. The user re-toggles with `prefix t`. Adding `client-detached` recreate logic is a future enhancement; it requires careful handling of the "was the sidebar on before the -CC client joined?" question and isn't needed to fix the reported deadlock.
- **Per-window scoping.** -CC is per-client, and panes are per-session, so session granularity is correct. We do not try to leave a sidebar in some windows of a session while removing it from others.
- **Detecting iTerm specifically.** Any control-mode client (iTerm2, custom tools using `-CC`) is treated identically. `client_control_mode` is the right signal regardless of terminal.

## Testing

New test file: `tests/sidebar/control_mode_test.sh`. Covers:

1. `ensure-sidebar-pane.sh` exits without spawning when the session has a -CC client.
2. `ensure-sidebar-pane.sh` kills an existing sidebar pane when a -CC client is attached.
3. `ensure-sidebar-pane.sh` clears window state options (`pane`, `creating`, `focus`, `layout`, `panes`) during teardown.
4. `toggle-sidebar.sh` calls `display-message` and does not modify `@tmux_sidebar_enabled` when -CC is attached.
5. Session isolation: a -CC client on session A does not prevent sidebar creation on session B.
6. Empty `client_control_mode` output (older tmux) is treated as not-control-mode — sidebar spawns normally.

Fake-tmux changes in `tests/testlib.sh`:

- Add `list-clients -t <session> -F <format>` handling. The fake tracks attached clients per session via a new helper `fake_tmux_register_client <session> <control_mode>` (writes to a temp file the fake reads). Default state: no clients (empty output), so existing tests that don't set this up are unaffected.
- Add `display-message ...` no-format support (for the toggle message) — return empty/no-op. Most likely already handled; verify during implementation.

Live integration check (manual, documented in PR description): with `install-live.sh`, attach a real iTerm in -CC mode to a tmux session, confirm no deadlock, then attach a regular client and confirm sidebar does not come back until toggled.

## Risks / open questions

- **`client_control_mode` availability.** Confirmed present in tmux 3.2 (2021). If the user's tmux is older, the format renders empty and we fall through to "no -CC client" — sidebar still works as today, deadlock still happens for those users. Acceptable: tmux 3.2+ is a reasonable floor and matches what iTerm-CC needs anyway.
- **Race on attach.** `client-attached` fires after the client is in control mode; the format query returns 1 immediately. No race window where we'd see the client as non-control before tearing down. Verified by tmux source behavior — the client's control flag is set before hooks run.
- **Multiple -CC clients.** Handled: `grep -qx 1` matches if any client reports 1.
- **Existing `@tmux_sidebar_enabled` flag.** Setting it to 0 during teardown means the next toggle treats the sidebar as off. If the user wants to re-enable on the regular client after the -CC client leaves, they hit `prefix t` and it spawns normally. This matches user mental model.

## Out of scope but worth flagging

The `is_sidebar_pane_command` matcher in `lib.sh:138` matches any shell command including `python`. This is used to identify sidebar panes by command name. The teardown path uses `list_sidebar_panes_in_session` which relies on this matcher — false positives (e.g. a user pane titled "Sidebar" running python) would get killed during -CC teardown. Existing risk, not introduced by this change; documented here for awareness.
