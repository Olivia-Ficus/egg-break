#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${HOME}/.hammerspoon/egg-break"
GLOBAL_INIT="${HOME}/.hammerspoon/init.lua"
LOADER_LINE='dofile(os.getenv("HOME") .. "/.hammerspoon/egg-break/init.lua")'

rm -rf "${INSTALL_DIR}"

echo "Removed ${INSTALL_DIR}"
echo
echo "To finish uninstalling, remove this loader line from ${GLOBAL_INIT}:"
echo "${LOADER_LINE}"
echo
echo "This script does not rewrite your Hammerspoon init.lua automatically."
echo "After removing the line, reload Hammerspoon config from the menu bar."
