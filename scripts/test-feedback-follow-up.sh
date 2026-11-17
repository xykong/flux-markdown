#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
swiftc Sources/Shared/BoundedFileReader.swift Sources/Shared/FeedbackFollowUpState.swift Sources/Shared/FeedbackReproduction.swift Tests/FeedbackFollowUp/main.swift -o "$WORK/probe"
"$WORK/probe"
