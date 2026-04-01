#!/bin/bash

# Markdown QuickLook Installation Script
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$DIR/.."
cd "$PROJECT_ROOT"

CONFIGURATION=${1:-Release}
SKIP_BUILD=${2:-false}

echo "════════════════════════════════════════════════════════════════"
echo "  🚀 Installing Markdown QuickLook - $CONFIGURATION Configuration"
echo "════════════════════════════════════════════════════════════════"
echo ""

# 1. Build the app (skip if already built by make debug)
if [ "$SKIP_BUILD" = "false" ]; then
    echo "📦 Building application in $CONFIGURATION mode..."
    make app CONFIGURATION="$CONFIGURATION"
else
    echo "📦 Skipping build (already completed)..."
fi

# 2. Copy to Applications
echo "🔍 Locating built application..."
APP_PATH=""

for path in ~/Library/Developer/Xcode/DerivedData/FluxMarkdown-*/Build/Products/"$CONFIGURATION"/"FluxMarkdown.app"; do
    if [ -d "$path" ]; then
        if [ -z "$APP_PATH" ] || [ "$path" -nt "$APP_PATH" ]; then
            APP_PATH="$path"
        fi
    fi
done

if [ -z "$APP_PATH" ]; then
    echo "❌ Error: Could not find built application in DerivedData."
    echo "   Expected path: .../Build/Products/$CONFIGURATION/FluxMarkdown.app"
    echo "   Please check if the build succeeded."
    exit 1
fi

echo "📋 Found app at: $APP_PATH"
echo "📋 Configuration: $CONFIGURATION"
echo "📋 Installing to /Applications..."
rm -rf "/Applications/FluxMarkdown.app"
cp -R "$APP_PATH" /Applications/

# 3. Remove quarantine attribute
echo "🔓 Removing quarantine attribute..."
/usr/bin/xattr -cr "/Applications/FluxMarkdown.app"

# 4. Register with LaunchServices
echo "🔧 Registering with system..."
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "/Applications/FluxMarkdown.app"

# 5. Reset QuickLook cache (before launching app)
echo "🔄 Resetting QuickLook cache..."
qlmanage -r

# 5a. Enable QuickLook extension (required on macOS Ventura+)
echo "🔌 Enabling QuickLook extension..."
pluginkit -e use -i com.xykong.Markdown.QuickLook

# 5b. Ensure FluxMarkdown is first in the QuickLook extension display order.
# macOS stores a user-ordered list in this plist; if a previously-installed
# Markdown previewer (e.g. QLMarkdown) is still in the list but now missing,
# it silently wins priority over FluxMarkdown, causing fallback to plain-text.
echo "📋 Setting QuickLook extension priority..."
CURRENT_ORDER=$(defaults read com.apple.preferences.extensions.QuickLook displayOrder 2>/dev/null | tr -d '(),"' | tr -s ' \n' ' ' | xargs)
if echo "$CURRENT_ORDER" | grep -qv "com.xykong.Markdown.QuickLook"; then
    defaults write com.apple.preferences.extensions.QuickLook displayOrder -array \
        "com.xykong.Markdown.QuickLook" \
        $(defaults read com.apple.preferences.extensions.QuickLook displayOrder 2>/dev/null | grep -v "com.xykong.Markdown.QuickLook" | grep '"' | sed 's/.*"\(.*\)".*/\1/' | xargs -I{} echo '"{}"' | tr '\n' ' ')
    defaults write com.apple.preferences.extensions.QuickLook userHasOrdered -bool true
fi
qlmanage -r cache

# 6. Launch app once to complete system registration
echo "🚀 Launching application to complete registration..."
open -g "/Applications/FluxMarkdown.app" --args --register-only
sleep 2

# 7. Set as default handler for .md files
echo "🔗 Setting as default handler for Markdown files..."
BUNDLE_ID="com.xykong.Markdown"

# Try using duti if available (more reliable)
if command -v duti >/dev/null 2>&1; then
    echo "   Using duti to set default associations..."
    duti -s "$BUNDLE_ID" net.daringfireball.markdown all
    duti -s "$BUNDLE_ID" public.markdown all
    duti -s "$BUNDLE_ID" .md all
    duti -s "$BUNDLE_ID" .markdown all
    duti -s "$BUNDLE_ID" .mdown all
    echo "   ✓ Default associations set via duti"
else
    # Fallback to Swift LaunchServices API
    echo "   Using Swift LaunchServices API (duti not available)..."
    cat << 'EOF' > /tmp/set_default_handler.swift
import Foundation
import CoreServices

func setDefaultHandler(bundleId: String, contentType: String) -> Bool {
    let cfBundleId = bundleId as CFString
    let cfContentType = contentType as CFString
    
    let result = LSSetDefaultRoleHandlerForContentType(cfContentType, LSRolesMask.all, cfBundleId)
    return result == noErr
}

let bundleId = "com.xykong.Markdown"
let types = ["net.daringfireball.markdown", "public.markdown"]

var allSuccess = true
for type in types {
    if setDefaultHandler(bundleId: bundleId, contentType: type) {
        print("   ✓ Set handler for \(type)")
    } else {
        print("   ⚠ Failed for \(type)")
        allSuccess = false
    }
}
exit(allSuccess ? 0 : 1)
EOF
    swift /tmp/set_default_handler.swift || {
        echo "   ⚠️  Automatic default app setting failed."
        echo "   📝 You can set it manually or install duti: brew install duti"
    }
    rm -f /tmp/set_default_handler.swift
fi

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  ✅ Installation Complete - $CONFIGURATION Configuration"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "🎉 FluxMarkdown has been automatically configured!"
echo ""
echo "📋 What was done:"
echo "   ✓ Application installed to /Applications"
echo "   ✓ Quarantine attribute removed (xattr -cr)"
echo "   ✓ Registered with system LaunchServices"
echo "   ✓ QuickLook extension enabled (pluginkit)"
echo "   ✓ QuickLook cache reset"
echo "   ✓ Launched once to complete registration"
echo "   ✓ Set as default handler for .md files"
echo ""
echo "🧪 Test the installation:"
echo "   qlmanage -p Tests/fixtures/feature-validation.md"
echo "   Or press Space on any .md file in Finder"
echo ""
echo "💡 If QuickLook doesn't work immediately, try:"
echo "   1. Log out and log back in (OR restart your Mac)"
echo "   2. Or manually verify in Finder: Right-click .md file → Get Info → Open with"
echo ""
