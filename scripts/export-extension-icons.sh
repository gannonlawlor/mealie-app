#!/bin/sh
# Export the approved Cookbook artwork at Chrome's required icon sizes.
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
source_icon="$repo_dir/docs/branding/extension-icon-rounded.png"
for size in 16 32 48 128; do
  sips -z "$size" "$size" "$source_icon" --out "$repo_dir/extension/icons/icon-$size.png" >/dev/null
done
printf '%s\n' 'Exported Cookbook extension icons (16, 32, 48, 128 px).'
