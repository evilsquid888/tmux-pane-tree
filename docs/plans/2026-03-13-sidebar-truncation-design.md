# Sidebar Truncation Design

## Goal

Prevent narrow tmux sidebars from visually wrapping long rows by truncating
overlong text with a single-character ellipsis.

## Current State

The sidebar renderer builds full strings for sessions, windows, and panes in
`scripts/sidebar-ui.py`. Interactive mode relies on curses clipping at draw
time, while `--dump-render` emits the full strings. With narrower sidebars,
long rows can still wrap instead of presenting a compact single-line view.

## Approach Options

### Option 1: Truncate in the shared renderer

Add truncation in the Python render layer so both interactive mode and
`--dump-render` produce lines that already fit the configured sidebar width.

### Option 2: Truncate only in the curses draw loop

This would fix the interactive sidebar only, but it would leave
`--dump-render` behavior inconsistent and harder to test.

### Option 3: Rely on tmux terminal settings to disable wrapping

This is more brittle, less portable, and harder to verify than emitting
correctly sized lines directly.

## Decision

Use Option 1.

## Detailed Design

- Add a helper in `scripts/sidebar-ui.py` that truncates a rendered row to a
  maximum visible width.
- If a row fits, return it unchanged.
- If a row exceeds the width:
  - for width `1`, return only `…`
  - otherwise return the first `width - 1` characters followed by `…`
- Interactive mode will render using `curses.COLS - 1`, matching the existing
  "avoid the last column" behavior.
- `--dump-render` will use the configured sidebar width minus one visible
  column, derived from the same precedence already used for width configuration:
  `TMUX_SIDEBAR_WIDTH`, then `@tmux_sidebar_width`, then default `35`.
- Tests will verify a long row becomes ellipsis-truncated and that the original
  long string is no longer present in dump-render output.

## Error Handling

- Invalid or missing width configuration falls back to the existing default
  width of `35`.
- Zero or negative computed widths render as empty strings.

## Testing

- Add a regression test in `tests/sidebar_ui_state_test.sh` for a narrow width
  with a deliberately long pane label.
- Run targeted sidebar UI tests first, then the full shell suite.
