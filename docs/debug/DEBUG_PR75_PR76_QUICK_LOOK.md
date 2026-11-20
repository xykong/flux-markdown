# Quick Look selection copy and paused Follow review

The review covers PR #75 at `edcddf3` and PR #76 at `906d129` against
`ba9d828`. The individual CI runs were green. Combining the PRs requires
both new Window declarations in `globals.d.ts`.

- Selecting only `Hello` in `Hello ![diagram](img.png)` must copy only
  `Hello`. A whole rendered heading with a reference link must paste with a
  usable destination even if its definition is outside the selected heading.
- Escape or changing the selection during a pending clipboard write must
  prevent its acknowledgement from reopening the old selection controls.
  Copy failures must retain actionable recovery and shared incident feedback.
- Pause Follow, change the file, manually reload, then change it again. The new
  change must be reported while still paused. A stale revision check must not
  update a newer Follow session. The paused button must remain visually
  distinct on the macOS 11 deployment target.
