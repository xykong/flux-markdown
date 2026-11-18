# Change: Follow appended Markdown in Finder Quick Look

## Why

Periodically appended Markdown should remain readable at its newest content.
Quick Look already detects changes, but replaces the entire rendered document and
has no explicit Follow control. Repeated replacement can disrupt reading and copying.

## What Changes

- Add an accessible Follow Changes control to the extension's expanded-preview toolbar.
- Follow the document end; pause on user navigation/selection and offer Resume/Off.
- Reparse bounded snapshots and retain unchanged leading DOM, replacing the affected suffix.
- Fall back to full rendering when earlier Markdown semantics or non-append edits require it.
- Use short-lived reads and bounded polling in the extension; guard all asynchronous work by document generation.
- Read a bounded preview snapshot when file metadata changes and use existing contextual error/recovery infrastructure.

## Impact

- New capability: `quicklook-follow-file`.
- Native extension toolbar, refresh lifecycle, renderer DOM lifecycle and tests.
- No Follow feature in app document windows, compact preview, source view or exports.
- Status: local integration candidate. Finder acceptance and performance validation are tracked in the tasks.
- The preview limit behaviour is revised by `update-quicklook-large-documents`.
