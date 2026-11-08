# Change: Support the first lightweight extensions from issue #64

## Why
The mathematics portion is shipped. The supplied corpus still contains definition
lists, abbreviation definitions and ++inserted text++ that remain literal. This
scope follows the first lightweight batch recommended in the issue audit under
the user's instruction to continue handling the remaining issues.

## What Changes
- Enable the upstream markdown-it definition-list, abbreviation and insertion
  plugins in the shared parser, with exact pinned dependencies.
- Preserve literal code, per-document abbreviation definitions, HTML sanitization,
  source view, search and HTML/PDF rendering paths.
- Test the original corpus excerpts and real WebKit output.

## Non-goals
Containers, attributes, body TOC placeholders, Wiki links, CriticMarkup, keyboard
shortcuts, citations and additional diagram engines remain separate candidates.
This batch does not claim full Markdown-dialect or whole-issue compatibility.

## Impact
web-renderer parser/dependencies, regression fixtures, real WebKit checks and
support documentation. No new settings, native permissions or external services.
