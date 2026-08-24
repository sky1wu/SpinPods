#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}
project_dir=${script_dir:h}

"$script_dir/build-app.sh" debug
app_path="$project_dir/.build/SpinPods.app"

if [[ ! -d "$app_path" ]]; then
    echo "SpinPods app bundle was not created at: $app_path" >&2
    exit 1
fi

open "$app_path"
