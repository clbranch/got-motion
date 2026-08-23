#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ARCHIVE="$ROOT/build/ios/archive/Runner.xcarchive"
EXPORT_DIR="$ROOT/build/ios/ipa"
OPTIONS="$EXPORT_DIR/ExportOptions.plist"

if [[ ! -d "$ARCHIVE" ]]; then
  echo "Archive not found. Run: flutter build ipa --release"
  exit 1
fi

mkdir -p "$EXPORT_DIR"
rm -f "$EXPORT_DIR/got_motion.ipa"

echo "Exporting IPA from archive (build $(/usr/libexec/PlistBuddy -c 'Print :ApplicationProperties:CFBundleVersion' "$ARCHIVE/Info.plist"))..."

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$OPTIONS" \
  -allowProvisioningUpdates

IPA="$(find "$EXPORT_DIR" -maxdepth 1 -name '*.ipa' | head -1)"
if [[ -z "$IPA" ]]; then
  echo "Export failed: no IPA produced."
  exit 1
fi

if [[ "$IPA" != "$EXPORT_DIR/got_motion.ipa" ]]; then
  mv "$IPA" "$EXPORT_DIR/got_motion.ipa"
fi

BUILD=$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' /tmp/ipa_verify/Payload/Runner.app/Info.plist 2>/dev/null || true)
rm -rf /tmp/ipa_verify
mkdir -p /tmp/ipa_verify
unzip -qo "$EXPORT_DIR/got_motion.ipa" -d /tmp/ipa_verify
BUILD=$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' /tmp/ipa_verify/Payload/Runner.app/Info.plist)

echo "Exported: $EXPORT_DIR/got_motion.ipa (build $BUILD)"
open "$EXPORT_DIR"
open -a Transporter 2>/dev/null || true
