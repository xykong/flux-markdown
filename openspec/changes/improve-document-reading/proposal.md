# Change: Durable document history and readable diagrams

## Why
System recent-document history is coupled to signing identity; development rebuilds change that identity. Mermaid defaults can enlarge diagrams beyond body-text scale. Users also need direct path copying.

## What Changes
- Persist recent document history independently of binary signatures, migrate the existing system list, and honor explicit clearing.
- Add localized Copy Document Path in the File menu with Command-Option-C, scoped to the active saved document.
- Size Mermaid at no more than body-font scale by default and add independent accessible zoom-out/reset/zoom-in controls.

## Impact
- New document-reading capability, host AppKit document controller and renderer sizing/export.
- No dependencies or release/version changes. User explicitly requested implementation of this scope.
