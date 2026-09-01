#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
export_root="$project_root/exports/ios"
xcode_root="$export_root/xcode"
derived_root="$export_root/DerivedData"
payload_root="$export_root/Payload"
archive_path="$export_root/ShadowRift-unsigned.ipa"

mkdir -p "$export_root"
godot --headless --path "$project_root" --editor --quit
godot --headless --path "$project_root" --export-debug "iOS Debug" "$export_root/ShadowRift-xcode.zip"
unzip -q "$export_root/ShadowRift-xcode.zip" -d "$xcode_root"

xcode_project="$(find "$xcode_root" -name '*.xcodeproj' -type d -print -quit)"
if [[ -z "$xcode_project" ]]; then
  echo "Godot did not produce an Xcode project" >&2
  exit 1
fi

scheme="$(xcodebuild -project "$xcode_project" -list -json | python3 -c 'import json,sys; data=json.load(sys.stdin); print(data["project"]["schemes"][0])')"
xcodebuild \
  -project "$xcode_project" \
  -scheme "$scheme" \
  -sdk iphoneos \
  -configuration Debug \
  -derivedDataPath "$derived_root" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  DEVELOPMENT_TEAM="" \
  build

app_path="$(find "$derived_root/Build/Products" -name '*.app' -type d -print -quit)"
if [[ -z "$app_path" ]]; then
  echo "Xcode did not produce an application bundle" >&2
  exit 1
fi

mkdir -p "$payload_root"
cp -R "$app_path" "$payload_root/"
ditto -c -k --sequesterRsrc --keepParent "$payload_root" "$archive_path"
echo "$archive_path"
