#!/bin/sh
# Uploads the latest release archive to App Store Connect with the Apple ID
# signed in to Xcode.
#
#   cd vompt && flutter build ipa --release && cd .. && tools/upload_ios.sh
#
# The team ID comes from vompt/ios/Flutter/Signing.xcconfig (git-ignored).
# PATH is reset to the system tools because a Homebrew rsync breaks Xcode's
# export with "Copy failed".
set -eu
cd "$(dirname "$0")/.."

archive=vompt/build/ios/archive/Runner.xcarchive
signing=vompt/ios/Flutter/Signing.xcconfig
[ -d "$archive" ] || { echo "No archive. Run: cd vompt && flutter build ipa --release"; exit 1; }
team=$(sed -n 's/^DEVELOPMENT_TEAM *= *//p' "$signing" 2>/dev/null | tr -d '[:space:]')
[ -n "$team" ] || { echo "Set DEVELOPMENT_TEAM in $signing (see Signing.xcconfig.example)"; exit 1; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cat > "$work/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>teamID</key><string>$team</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
  <key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
EOF

env PATH=/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -exportArchive \
  -archivePath "$archive" \
  -exportOptionsPlist "$work/ExportOptions.plist" \
  -exportPath "$work/out" \
  -allowProvisioningUpdates 2>&1 | grep -E "Upload succeeded|Uploaded|EXPORT|error:" || true
