#!/bin/bash

# Configuration
APP_NAME="Lobby"
VERSION=$1
GITHUB_REPO="b2oule/Lobbydesktop"
PRIVATE_KEY_PATH="./ed_private.pem"
APPLE_ID="Sarah@thelobby.ai"
TEAM_ID="7Y9Y7R6X93"
APP_SPECIFIC_PASSWORD="dhrm-firi-olsx-xoze"
PROJECT_DIR="/Users/nicolascabrignac/Desktop/LobbyDesktop/Lobby/LobbyOS/"
DMG_BACKGROUND="${PROJECT_DIR}LobbyOS/assets/dmg-background.png"
DERIVED_DATA="/Users/nicolascabrignac/Library/Developer/Xcode/DerivedData/LobbyOS-hdtadhiprggywdgovgrqrhyphzhd/Build/Products/Release"
APP_PATH="${DERIVED_DATA}/${APP_NAME}.app"
DMG_PATH="${DERIVED_DATA}/${APP_NAME}-${VERSION}.dmg"
DEVELOPER_ID="Developer ID Application: Lobby OS, Inc. (7Y9Y7R6X93)"

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to sign a binary with hardened runtime and timestamp
sign_binary() {
    local binary_path="$1"
    echo "Signing: $binary_path"
    codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID" "$binary_path" || {
        echo "Error: Failed to sign $binary_path"
        exit 1
    }
}

# Function to sign all binaries in a directory recursively
sign_directory() {
    local dir="$1"
    echo "Signing all binaries in: $dir"

    # Sign all frameworks first
    find "$dir" -type d -name "*.framework" | while read -r framework; do
        echo "Signing framework: $framework"
        codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID" "$framework" || {
            echo "Error: Failed to sign framework $framework"
            exit 1
        }
    done

    # Sign all XPC services
    find "$dir" -type d -name "*.xpc" | while read -r xpc; do
        echo "Signing XPC service: $xpc"
        codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID" "$xpc" || {
            echo "Error: Failed to sign XPC service $xpc"
            exit 1
        }
    done

    # Sign all Mach-O executables (skip resource files)
    find "$dir" -type f -perm +111 | while read -r binary; do
        if file "$binary" | grep -q 'Mach-O'; then
            echo "Signing binary: $binary"
            codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID" "$binary" || {
                echo "Error: Failed to sign binary $binary"
                exit 1
            }
        fi
    done
}

# Check for required tools
if ! command_exists xcodebuild; then
    echo "Error: xcodebuild not found. Please install Xcode Command Line Tools."
    exit 1
fi

if ! command_exists gh; then
    echo "Error: GitHub CLI (gh) not found. Please install it with: brew install gh"
    exit 1
fi

if ! command_exists create-dmg; then
    echo "Error: create-dmg not found. Please install it with: brew install create-dmg"
    exit 1
fi

if ! command_exists gsed; then
    echo "Error: GNU sed (gsed) not found. Please install it with: brew install gnu-sed"
    exit 1
fi

# Check if version is provided
if [ -z "$VERSION" ]; then
    echo "Please provide a version number (e.g., ./release.sh 1.0.0)"
    exit 1
fi

# Check if Sparkle tools exist
if [ ! -f "./sparkle/bin/sign_update" ]; then
    echo "Setting up Sparkle tools..."
    mkdir -p sparkle
    cd sparkle
    curl -L https://github.com/sparkle-project/Sparkle/releases/download/2.4.0/Sparkle-2.4.0.tar.xz | tar xJ
    cd ..
fi

# Change to the project directory
cd "$PROJECT_DIR" || { echo "Error: Could not change to project directory $PROJECT_DIR"; exit 1; }

# Build the app
echo "Building app..."
xcodebuild -project LobbyOS.xcodeproj -scheme Lobby -configuration Release clean build || {
    echo "Error: Build failed"
    exit 1
}

# Sign all binaries in the app bundle
echo "Signing all binaries in the app bundle..."
sign_directory "$APP_PATH"

# Sign the main app bundle last
echo "Signing main app bundle..."
codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID" "$APP_PATH" || {
    echo "Error: Failed to sign main app bundle"
    exit 1
}

# Create DMG with custom layout
echo "Creating DMG with custom layout..."
# Remove any previous DMG
rm -f "$DMG_PATH"

create-dmg \
  --volname "${APP_NAME}" \
  --background "${DMG_BACKGROUND}" \
  --window-pos 200 120 \
  --window-size 660 400 \
  --icon-size 128 \
  --icon "${APP_NAME}.app" 180 170 \
  --icon "Applications" 480 170 \
  --app-drop-link 480 170 \
  "$DMG_PATH" \
  "$APP_PATH" || {
    echo "Error: DMG creation with create-dmg failed"
    exit 1
}

# Sign the DMG
echo "Signing DMG..."
codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID" "$DMG_PATH" || {
    echo "Error: Failed to sign DMG"
    exit 1
}

# Notarize the DMG
echo "Notarizing DMG..."
xcrun notarytool submit "$DMG_PATH" \
    --apple-id "$APPLE_ID" \
    --password "$APP_SPECIFIC_PASSWORD" \
    --team-id "$TEAM_ID" \
    --wait || {
    echo "Error: DMG notarization failed"
    exit 1
}

# Staple the notarization ticket to the DMG
echo "Stapling notarization ticket to DMG..."
xcrun stapler staple "$DMG_PATH" || {
    echo "Error: DMG stapling failed"
    exit 1
}

# Sign the DMG with Sparkle
echo "Signing DMG with Sparkle..."
SIGNATURE="$(/Users/nicolascabrignac/Desktop/LobbyDesktop/Lobby/LobbyOS/LobbyOS/sparkle/bin/sign_update "$DMG_PATH" "$PRIVATE_KEY_PATH")" || {
    echo "Error: DMG signing failed"
    exit 1
}

# Get file size
FILE_SIZE=$(stat -f%z "$DMG_PATH")

# Create GitHub release
echo "Creating GitHub release..."
RELEASE_NOTES=$(cat <<EOF
## What's New
- Version ${VERSION} release
EOF
)

gh release create "v${VERSION}" "$DMG_PATH" --title "Version ${VERSION}" --notes "${RELEASE_NOTES}" || {
    echo "Error: GitHub release creation failed"
    exit 1
}

# Get the download URL
DOWNLOAD_URL="https://github.com/${GITHUB_REPO}/releases/download/v${VERSION}/${APP_NAME}-${VERSION}.dmg"

# Update appcast.xml
echo "Updating appcast.xml..."
CURRENT_DATE=$(date -u +"%a, %d %b %Y %H:%M:%S +0000")

NEW_ENTRY_FILE=$(mktemp)
cat > "$NEW_ENTRY_FILE" <<EOF
        <item>
            <title>Version ${VERSION}</title>
            <pubDate>${CURRENT_DATE}</pubDate>
            <sparkle:version>${VERSION}</sparkle:version>
            <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
            <description><![CDATA[
                <h2>What's New</h2>
                <ul>
                    <li>Version ${VERSION} release</li>
                </ul>
            ]]></description>
            <enclosure url="${DOWNLOAD_URL}"
                      sparkle:version="${VERSION}"
                      sparkle:shortVersionString="${VERSION}"
                      length="${FILE_SIZE}"
                      type="application/octet-stream"
                      sparkle:edSignature="${SIGNATURE}"/>
        </item>
EOF

# Insert the new entry after <channel> using GNU sed (gsed)
gsed -i "/<channel>/r $NEW_ENTRY_FILE" "${PROJECT_DIR}appcast.xml"
rm "$NEW_ENTRY_FILE"

git -C "$PROJECT_DIR" add appcast.xml
git -C "$PROJECT_DIR" commit -m "Update appcast.xml for version ${VERSION}"
git -C "$PROJECT_DIR" push || {
    echo "Error: Failed to push changes to GitHub"
    exit 1
}

echo "Release process completed!"
echo "Version ${VERSION} has been released and appcast.xml has been updated."
echo "\nIMPORTANT: Place your DMG background image at: $DMG_BACKGROUND (PNG, e.g. 660x400, with arrow and branding)"
echo "You can adjust icon positions and window size in the create-dmg command in release.sh." 