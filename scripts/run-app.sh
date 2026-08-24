#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}
app_path=$($script_dir/build-app.sh debug)
open "$app_path"
