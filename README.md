# tmux-sidebar

A tmux plugin that gives you a persistent, interactive session tree on the left
side of every window — with live agent status badges for `claude`, `codex`, and
`opencode`.

```
  ┌─ Sidebar ──────────┬─────────────────────────────────┐
  │                     │                                 │
  │ ├─ work             │  $ claude                       │
  │ │  ├─ editor        │                                 │
  │ │  │  └─ nvim       │  Working on your request...     │
  │ │  └─ agents        │                                 │
  │ │     ├─ claude [~] │                                 │
  │ │     └─ codex  [?] │                                 │
  │ └─ ops              │                                 │
  │    └─ logs          │                                 │
  │       └─ tail       │                                 │
  │                     │                                 │
  └─────────────────────┴─────────────────────────────────┘
```

## Features

**Interactive tree** — sessions, windows, and panes rendered as a navigable
Unicode tree. Select any pane and jump to it with `Enter`.

**Agent badges** — per-pane status indicators update in real time:

| Badge | Status      | Meaning                        |
| :---: | ----------- | ------------------------------ |
| `[~]` | running     | Agent is working               |
| `[?]` | needs-input | Waiting for permission / input |
| `[!]` | done        | Finished                       |
| `[x]` | error       | Something went wrong           |

Badges for `done` and `needs-input` clear automatically when you focus the pane.

**Auto-mirroring** — the sidebar follows you across windows. Open it once and it
stays visible as you move around.

**Session management** — add windows, add sessions, and close panes directly
from the sidebar without leaving context.

## Install

### With TPM

```tmux
set -g @plugin 'sandudorogan/tmux-sidebar'
```

Reload tmux and press `prefix + I` to install.

### Manual

```bash
git clone https://github.com/sandudorogan/tmux-sidebar \
  ~/.tmux/plugins/tmux-sidebar
```

Source it in your tmux config:

```tmux
run-shell ~/.tmux/plugins/tmux-sidebar/sidebar.tmux
```

Then `tmux source-file ~/.tmux.conf`.

## Usage

### Toggle

`<prefix> t` opens or closes the sidebar.

### Navigation (inside the sidebar)

| Key          | Action                           |
| ------------ | -------------------------------- |
| `j` / `Down` | Move selection down              |
| `k` / `Up`   | Move selection up                |
| `Enter`      | Jump to the selected pane        |
| `aw`         | Add a window (prompts for name)  |
| `as`         | Add a session (prompts for name) |
| `x`          | Close the selected pane          |
| `q`          | Close the sidebar                |
| `Ctrl+l`     | Return focus to the main pane    |

New windows and sessions are inserted relative to the currently selected row.
Closing the last pane in a window removes the window; the last window removes
the session.

## Configuration

All options are set with `set -g` in your tmux config.

### Sidebar width

```tmux
set -g @tmux_sidebar_width 30      # default: 25
```

The env var `TMUX_SIDEBAR_WIDTH` takes precedence if set.

### Focus on open

By default, toggling the sidebar moves focus into it. Disable this to keep
focus in your main pane:

```tmux
set -g @tmux_sidebar_focus_on_open 0   # default: 1
```

### Session order

Control the order sessions appear in the tree:

```tmux
set -g @tmux_sidebar_session_order "work,ops,scratch"
```

Sessions not in this list appear after the listed ones in their default order.
Adding a session via the sidebar (`as`) automatically inserts it into this
list.

### Custom shortcuts

Override the default sidebar shortcuts:

```tmux
set -g @tmux_sidebar_add_window_shortcut  zw   # default: aw
set -g @tmux_sidebar_add_session_shortcut zs   # default: as
set -g @tmux_sidebar_close_pane_shortcut  dd   # default: x
```

Shortcuts are validated on load. If any value is empty, duplicates another,
overlaps as a prefix, or contains the reserved `q` key, all three revert to
defaults.

### Quick reference

| Option                               | Default | Description                      |
| ------------------------------------ | :-----: | -------------------------------- |
| `@tmux_sidebar_width`                |  `25`   | Sidebar column width             |
| `@tmux_sidebar_focus_on_open`        |   `1`   | Focus sidebar when toggled open  |
| `@tmux_sidebar_session_order`        |    —    | Comma-separated session ordering |
| `@tmux_sidebar_add_window_shortcut`  |  `aw`   | Shortcut to add a window         |
| `@tmux_sidebar_add_session_shortcut` |  `as`   | Shortcut to add a session        |
| `@tmux_sidebar_close_pane_shortcut`  |   `x`   | Shortcut to close selected pane  |

| Environment variable     | Description                                                                                    |
| ------------------------ | ---------------------------------------------------------------------------------------------- |
| `TMUX_SIDEBAR_WIDTH`     | Overrides `@tmux_sidebar_width`                                                                |
| `TMUX_SIDEBAR_STATE_DIR` | State file directory (default `$XDG_STATE_HOME/tmux-sidebar` or `~/.local/state/tmux-sidebar`) |

## Hook Integration

Agents report their status through `scripts/update-pane-state.sh`:

```bash
~/.tmux/plugins/tmux-sidebar/scripts/update-pane-state.sh \
  --pane "$TMUX_PANE" \
  --app claude \
  --status needs-input \
  --message "Permission request"
```

Supported `--status` values: `running`, `needs-input`, `done`, `error`, `idle`.

### Agent hook examples

Ready-to-use hook wrappers live in `examples/`:

- **`examples/claude-hook.sh`** — reads `CLAUDE_HOOK_EVENT_NAME` and
  `CLAUDE_NOTIFICATION_MESSAGE`
- **`examples/codex-hook.sh`** — reads `CODEX_STATUS` and `CODEX_MESSAGE`
- **`examples/opencode-hook.sh`** — reads `OPENCODE_STATUS` and
  `OPENCODE_MESSAGE`

The built-in `scripts/hook-claude.sh` and `scripts/hook-codex.sh` provide
richer event parsing if you need finer-grained status mapping.

## Requirements

- tmux 3.0+
- Python 3 (for the interactive UI)
- bash 4.0+

## Development

### Tests

```bash
bash tests/run.sh tests/*_test.sh
```

Tests use a fake tmux binary — no live session needed.

### Live reload

After editing scripts or the UI, push your changes into the running plugin
directory and reload all sidebar panes in one step:

```bash
bash scripts/install-live.sh
```

This copies the working tree into `~/.config/tmux/plugins/tmux-sidebar`,
patches `#{d:current_file}` references, re-sources the tmux config, and
respawns every open sidebar pane. It also keeps agent hooks in
`~/.claude/settings.json` and `~/.codex/config.toml` pointing at the installed
copy.

If you only changed `sidebar-ui.py` and want to skip the full install, you can
respawn the sidebar panes directly:

```bash
bash scripts/reload-sidebar-panes.sh
```

## License

MIT
