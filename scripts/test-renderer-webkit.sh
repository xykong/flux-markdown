#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
PROBE_DIR=$(mktemp -d)
trap 'rm -rf "$PROBE_DIR"' EXIT
swiftc Tests/Support/TestWindowPolicy.swift Tests/TestWindowPolicy/main.swift -o "$PROBE_DIR/window-policy"
"$PROBE_DIR/window-policy"
swiftc Tests/Support/TestWindowPolicy.swift Sources/Shared/RendererBundleSchemeHandler.swift Sources/Shared/RendererBridgePolicy.swift Sources/Shared/BlockCopyBridge.swift Sources/Shared/LocalSchemeHandler.swift Sources/Shared/MarkdownImageDataCollector.swift Sources/Shared/BoundedFileReader.swift Tests/RendererIntegration/main.swift -o "$PROBE_DIR/probe"
"$PROBE_DIR/probe" "${1:-$PWD/web-renderer/dist}" "$PROBE_DIR"
