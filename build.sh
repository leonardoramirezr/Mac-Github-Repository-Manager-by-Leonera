#!/bin/bash
set -e

APP_NAME="RepositoryManager"
BUILD_DIR="build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"

rm -rf "${BUILD_DIR}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

echo "Compiling..."
xcrun swiftc \
    -parse-as-library \
    -O \
    -target "$(uname -m)-apple-macos15.0" \
    -o "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}" \
    src/*.swift \
    -framework AppKit \
    -framework SwiftUI \
    -framework Foundation \
    -framework Security \
    -framework CryptoKit

cp Info.plist "${APP_BUNDLE}/Contents/Info.plist"
if [ -f Resources/Icon/AppIcon.icns ]; then
    cp Resources/Icon/AppIcon.icns "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
fi

echo "Signing app..."
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "Done: ${APP_BUNDLE}"
