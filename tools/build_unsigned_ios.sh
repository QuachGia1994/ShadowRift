#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
export_root="$project_root/exports/ios"
derived_root="$export_root/DerivedData"
payload_root="$export_root/Payload"
archive_path="$export_root/ShadowRift-unsigned.ipa"
xcode_archive="$export_root/ShadowRift-xcode.zip"

rm -rf "$export_root"
mkdir -p "$export_root"
godot --headless --path "$project_root" --editor --quit
godot --headless --path "$project_root" --export-debug "iOS PreRelease" "$xcode_archive"

xcode_project="$(find "$export_root" -maxdepth 1 -name '*.xcodeproj' -type d -print -quit)"
if [[ -z "$xcode_project" ]]; then
  echo "Godot did not produce an Xcode project" >&2
  exit 1
fi

scheme="$(xcodebuild -project "$xcode_project" -list -json | python3 -c 'import json,sys; schemes=json.load(sys.stdin).get("project",{}).get("schemes",[]); assert schemes, "Xcode project has no scheme"; print(schemes[0])')"
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

bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app_path/Info.plist")"
short_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app_path/Info.plist")"
expected_bundle="$(python3 -c 'import pathlib,re,sys; text=(pathlib.Path(sys.argv[1]) / "export_presets.cfg").read_text(); match=re.search(r"^application/bundle_identifier=\"([^\"]+)\"$", text, re.M); assert match; print(match.group(1))' "$project_root")"
expected_version="$(python3 -c 'import pathlib,re,sys; text=(pathlib.Path(sys.argv[1]) / "export_presets.cfg").read_text(); match=re.search(r"^application/short_version=\"([^\"]+)\"$", text, re.M); assert match; print(match.group(1))' "$project_root")"
if [[ "$bundle_id" != "$expected_bundle" || "$short_version" != "$expected_version" ]]; then
  echo "Unexpected iOS metadata: $bundle_id $short_version" >&2
  exit 1
fi

mkdir -p "$payload_root"
cp -R "$app_path" "$payload_root/"
ditto -c -k --sequesterRsrc --keepParent "$payload_root" "$archive_path"
ditto -c -k --sequesterRsrc --keepParent "$xcode_project" "$xcode_archive"
echo "$archive_path"
