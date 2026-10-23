#!/usr/bin/env bash
# 编译并打包成 build/GitSwitcher.app
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="GitSwitcher"
DISPLAY_NAME="Git 账号切换"
BUNDLE_ID="com.local.gitswitcher"
VERSION="1.0.0"

echo "▶ 编译 release 版本…"
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

APP="build/${APP_NAME}.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"

# LSUIElement=true：只在菜单栏显示，不占 Dock
cat > "$APP/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
    <key>CFBundleName</key><string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key><string>${DISPLAY_NAME}</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

echo "▶ 本地签名（ad-hoc）…"
codesign --force --sign - "$APP"

echo "✅ 完成：$APP"
echo "   运行：open \"$APP\""
echo "   安装：cp -R \"$APP\" /Applications/"
