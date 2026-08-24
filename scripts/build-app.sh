#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}
project_dir=${script_dir:h}
configuration=${1:-debug}

case "$configuration" in
    debug|release) ;;
    *)
        echo "Usage: $0 [debug|release]" >&2
        exit 2
        ;;
esac

cd "$project_dir"
swift build --configuration "$configuration" --product SpinPodsMac >&2
binary_dir=$(swift build --configuration "$configuration" --show-bin-path)

app_path="$project_dir/.build/SpinPods.app"
contents_path="$app_path/Contents"
executable_path="$contents_path/MacOS"
resources_path="$contents_path/Resources"

rm -rf "$app_path"
mkdir -p "$executable_path" "$resources_path"
cp "$binary_dir/SpinPodsMac" "$executable_path/SpinPodsMac"
cp "$project_dir/App/Info.plist" "$contents_path/Info.plist"

codesign --force --sign - "$app_path"
print -r -- "$app_path"
