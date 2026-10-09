---
title: "Review Mode Test Fixtures"
date: 2026-10-09
tags:
  - review-mode
  - fixtures
  - testing
---

# Review Mode Test Fixtures

Use these files to test the review diff.

## Steps

1. Copy `before.md` to a scratch path.

   ```bash
   cp Tests/fixtures/review/before.md /tmp/review-test.md
   ```

2. Open the scratch file in FluxMarkdown.

   ```bash
   open -a FluxMarkdown /tmp/review-test.md
   ```

3. Wait for the preview.

4. Replace the scratch file with the new version.

   ```bash
   cp Tests/fixtures/review/after.md /tmp/review-test.md
   ```

5. The preview reloads. The review toolbar appears.

6. Use the toolbar to mark each change as reviewed.

7. Close the preview. The reviewed state stays for the same file path.

## What to check

- The first paragraph shows red struck-through `cookies and` and green `and encrypts it`.
- The second paragraph keeps the link and marks `text` to `words`.
- The second list item marks `changes` to `changed`.
- The removed paragraph appears in a "Before" disclosure.
- The rewritten quote appears in a "Before" disclosure.
- The unchanged heading, section, and Mermaid diagram show no marks.

## Reset

Delete the scratch file.

```bash
rm -f /tmp/review-test.md
```

The review state is in the web view `localStorage` under the `flux-review:` prefix.
