# Sidebar Truncation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Truncate long sidebar rows with a single-character ellipsis so narrow sidebar widths do not wrap text.

**Architecture:** The change lives in `scripts/sidebar-ui.py`, where all sidebar rows are assembled before being shown interactively or emitted via `--dump-render`. A small width-resolution helper and a truncation helper will keep both code paths consistent while preserving the existing width precedence and default.

**Tech Stack:** Python 3, curses, shell tests

---

### Task 1: Add a failing truncation regression test

**Files:**
- Modify: `tests/sidebar_ui_state_test.sh`

**Step 1: Write the failing test**

Add a case with a long pane label and a narrow configured sidebar width. Assert
that dump-render output contains `…` and does not contain the full long pane
label.

**Step 2: Run test to verify it fails**

Run: `bash tests/run.sh tests/sidebar_ui_state_test.sh`
Expected: FAIL because the renderer still emits the full line without
truncation.

**Step 3: Write minimal implementation**

No implementation in this task.

**Step 4: Run test to verify it still fails for the expected reason**

Run: `bash tests/run.sh tests/sidebar_ui_state_test.sh`
Expected: FAIL on the new truncation assertions.

**Step 5: Commit**

Commit later with implementation.

### Task 2: Implement width-aware truncation in the shared renderer

**Files:**
- Modify: `scripts/sidebar-ui.py`

**Step 1: Write the failing test**

Covered by Task 1.

**Step 2: Run test to verify it fails**

Covered by Task 1.

**Step 3: Write minimal implementation**

Add helpers that resolve the effective width and truncate rendered rows with a
single `…` when they exceed the available width.

**Step 4: Run test to verify it passes**

Run: `bash tests/run.sh tests/sidebar_ui_state_test.sh tests/render_sidebar_test.sh`
Expected: PASS

**Step 5: Commit**

Commit later after full verification.

### Task 3: Verify the change against the full shell suite

**Files:**
- Modify: none

**Step 1: Write the failing test**

Not applicable.

**Step 2: Run test to verify it fails**

Not applicable.

**Step 3: Write minimal implementation**

Not applicable.

**Step 4: Run test to verify it passes**

Run: `bash tests/run.sh`
Expected: PASS

**Step 5: Commit**

```bash
git add -f docs/plans/2026-03-13-sidebar-truncation-design.md docs/plans/2026-03-13-sidebar-truncation.md
git commit -m "docs: add sidebar truncation planning docs"

git add scripts/sidebar-ui.py tests/sidebar_ui_state_test.sh
git commit -m "feat: truncate narrow sidebar rows"
```
