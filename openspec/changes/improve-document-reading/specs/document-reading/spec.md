## ADDED Requirements
### Requirement: Durable recent document history
The app SHALL retain bounded, deduplicated recent document history across rebuilds and upgrades independently of signing identity, and SHALL preserve an explicit clear across restarts.

#### Scenario: New binary identity
- **WHEN** a different signed build opens the same app-owned history
- **THEN** recent documents remain in most-recent-first order, including temporarily unavailable files

#### Scenario: Clear history
- **WHEN** the user clears recent documents
- **THEN** both app-owned and system history are cleared and old entries are not restored on restart

### Requirement: Copy current document path
The app SHALL offer a localized File menu action and Command-Option-C to copy the active saved document's absolute path.

#### Scenario: Multiple documents
- **WHEN** the user invokes path copying with multiple document windows
- **THEN** only the active document path is copied unchanged as plain text

### Requirement: Readable Mermaid scale
The renderer SHALL cap automatic Mermaid label size at the surrounding body text size and provide bounded independent per-diagram zoom controls, including reset.

#### Scenario: Fullscreen document
- **WHEN** a document window becomes wide
- **THEN** diagrams stop growing at their body-font scale instead of filling the window

#### Scenario: Per-diagram adjustment
- **WHEN** the user zooms one diagram with pointer or keyboard
- **THEN** only that diagram changes and reset restores automatic sizing

#### Scenario: Export
- **WHEN** a document is copied or exported
- **THEN** diagram control labels do not appear in document content
