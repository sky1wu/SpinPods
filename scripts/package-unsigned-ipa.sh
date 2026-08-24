#!/bin/zsh
set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <path-to-device-app> <output-ipa>" >&2
    exit 2
fi

app_path=${1:A}
output_path=${2:A}

if [[ ! -d "$app_path" || "$app_path" != *.app ]]; then
    echo "Input must be an existing .app bundle: $app_path" >&2
    exit 2
fi

info_plist="$app_path/Info.plist"
platform=$(/usr/bin/plutil -extract CFBundleSupportedPlatforms.0 raw "$info_plist" 2>/dev/null || true)
if [[ "$platform" != "iPhoneOS" ]]; then
    echo "Input must be an iPhoneOS device build, not macOS or Simulator: $app_path" >&2
    exit 2
fi

if [[ -e "$output_path" ]]; then
    echo "Refusing to overwrite existing output: $output_path" >&2
    exit 2
fi

output_dir=${output_path:h}
mkdir -p "$output_dir"

staging_dir=$(mktemp -d "${TMPDIR:-/tmp}/spinpods-ipa.XXXXXX")
trap 'rm -rf "$staging_dir"' EXIT

payload_dir="$staging_dir/Payload"
mkdir -p "$payload_dir"
cp -R "$app_path" "$payload_dir/SpinPods.app"

(
    cd "$staging_dir"
    /usr/bin/zip -q -r -y -X "$output_path" Payload
)

print -r -- "$output_path"
