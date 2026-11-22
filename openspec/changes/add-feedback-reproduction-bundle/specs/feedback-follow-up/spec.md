## ADDED Requirements

### Requirement: Associate a submitted report with its real Issue
The product SHALL distinguish draft preparation from Issue submission and associate reports only with a verified Issue in the fixed project repository. Automatic association SHALL use the complete incident identity and reject ambiguous matches. The product SHALL offer verified manual linking when automatic discovery is unavailable. Late discovery SHALL include replies created after submission rather than starting at discovery time.

#### Scenario: Submission is discovered after a reply
- **WHEN** a published Issue matching the local incident is discovered after another participant has commented
- **THEN** the reply is fetched and marked unread without requiring another future comment

#### Scenario: User only opens the creation form
- **WHEN** no actual published Issue has been verified
- **THEN** the report remains pending association and the product does not claim submission or active reply tracking

### Requirement: Durable reminders for new replies
The product SHALL track new comments from maintainers and other participants on associated Issues and persist unread state across restarts. It SHALL check on launch, foreground activation and periodically while running, respect API pagination and rate limits, and catch up after offline periods. It SHALL disclose that this polling mode does not provide immediate reminders while the app is not running. Optional system notifications SHALL supplement an accessible in-app feedback entry, available through the host app and reachable from Quick Look.

#### Scenario: Notification dismissed or permission denied
- **WHEN** the user dismisses a system notification or denies notification permission
- **THEN** the in-app unread marker remains until the user activates the corresponding reply reminder

#### Scenario: App restarts or synchronization fails
- **WHEN** the app restarts, a periodic check runs or a network request fails
- **THEN** unread state is retained and failed synchronization does not advance successful synchronization or user acknowledgement progress

### Requirement: Explicit activation opens the new message
The product SHALL clear a reply reminder only after the user activates that reminder and browser navigation to its validated exact comment URL is accepted. Merely opening the app, viewing a list, receiving a notification, dismissing a banner, closing the Issue or waiting SHALL NOT clear it. Navigation failure SHALL preserve the reminder and offer retry or copy. The product SHALL NOT describe accepted browser navigation as proof of reading.

#### Scenario: User clicks a reply reminder
- **WHEN** the user clicks a reminder and the browser accepts the exact comment URL
- **THEN** the product opens that new message and acknowledges only the replies explicitly covered by that activation

#### Scenario: More replies arrive during activation
- **WHEN** additional comments arrive while an existing reminder is activated
- **THEN** the additional comments remain unread and the product does not clear all reminders using a moving latest-comment cursor

#### Scenario: Several new replies exist
- **WHEN** a user activates the Issue's aggregate reminder
- **THEN** it opens the first unread comment and retains reminders for later comments not covered by that activation
