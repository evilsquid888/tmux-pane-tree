# Changelog

All notable project versions are documented here.

## 0.3.3

- Fixed macOS+fish bug where Ctrl-b t stacked new sidebars because detection only matched `python` as `pane_current_command`; allowlist now covers common shells while still excluding agent CLIs like codex/cursor.
- Hardened the live-tmux integration test helper against CI flakes by widening the run-shell poll budget and dropping login-shell profile loading.
- Release commit `c4ab2b4`.

## 0.3.2

- Added built-in Pi and Kiro hook installers, example hook scripts, parser support, and sidebar icons/status badges.
- Documented the Pi and Kiro hook setup and expanded runtime coverage for the new examples and installers.
- Persisted sidebar width across sessions so reopened sidebars keep the user-selected width.
- Fixed a recursive sidebar spawning race when pane selection re-entered sidebar creation.
- Release commit `fa24093`.

## 0.3.1

- Follow-up fixes for the subagent detection and suppression work.
- Tagged on commit `aa1e7f3`.

## 0.3.0

- Added the initial subagent detection and shared suppression state.
- Tagged on commit `199de73`.

## 0.2.0

- Landed Nerd Font icon and badge support for the sidebar UI.
- Tagged on commit `3631ceb`.

## 0.1.0

- Initial project release.
- Tagged on commit `73714a4`.

---

# Fork history (evilsquid888/tmux-pane-tree)

## 2026-04-01 — Rebase onto sandudorogan/tmux-pane-tree

Replaced entire codebase with [sandudorogan/tmux-pane-tree](https://github.com/sandudorogan/tmux-pane-tree)
and renamed repo from `tmux-sidebar` to `tmux-pane-tree`.

### Why

The upstream `sandudorogan/tmux-pane-tree` had evolved well beyond this fork,
with 12+ major features that our fork lacked. Every feature unique to this fork
(mouse support, hide-panes, locking, tmux 3.4 compat) already existed in
tmux-pane-tree. A clean replacement was simpler and more maintainable than
merging two repos with no shared git history.

### New features (from tmux-pane-tree)

- **Search/filter** — press `/` to search, `n`/`N` for next/prev, `f` to toggle filter
- **Jump list** — `Ctrl+o` / `Ctrl+i` for backward/forward navigation history
- **Syntax-highlighted colors** — hex color support for sessions, windows, panes
- **Icon themes** — ASCII, Unicode, and Nerd Font with auto-detection
- **Agent badges** — live status for Claude, Codex, Cursor, and OpenCode
- **Context menu** — right-click opens session/window/pane action menu
- **Scrolloff** — configurable cursor margin (default 8 lines)
- **Rename shortcuts** — `rs` / `rw` for sessions and windows
- **Top/bottom jump** — `gg` / `G`
- **Smart window close** — closing last pane removes window; last window removes session
- **Modular Python UI** — clean separation into `sidebar_ui_lib/` modules
- **Customizable shortcuts** — override any sidebar keybinding via tmux options
- **Session ordering** — `@tmux_pane_tree_session_order` for custom sort
- **Pane filter** — `@tmux_pane_tree_filter` for comma-separated process matching
- **Agent hook installer** — automatic config patching for Claude/Codex/Cursor/OpenCode

### Breaking changes

- Entry point renamed from `sidebar.tmux` to `tmux-pane-tree.tmux` (legacy shim still works)
- Option prefix changed from `@tmux_sidebar_*` to `@tmux_pane_tree_*` (legacy names still work)
- Scripts reorganized into `scripts/core/`, `scripts/ui/`, `scripts/features/`
- Python UI refactored from single file to `scripts/ui/sidebar_ui_lib/` package

### Migration

For TPM users, update your config:

```tmux
# Old
set -g @plugin 'evilsquid888/tmux-sidebar'

# New
set -g @plugin 'evilsquid888/tmux-pane-tree'
```

Legacy `@tmux_sidebar_*` options and the `sidebar.tmux` entry point still work
during the compatibility window.

---

## Pre-rebase history (evilsquid888/tmux-sidebar)

- **2026-03-30** — Merged upstream changes from sandudorogan/tmux-sidebar
- **2026-03-28** — fix: handle missing `allow-set-title` option in tmux 3.4
- **2026-03-28** — fix: prevent recursive sidebar spawning on pane selection
- **2026-03-28** — fix: make plugin TPM-compatible and add UI improvements
- **2026-03-15** — Initial fork from joemiller/tmux-sidebar
