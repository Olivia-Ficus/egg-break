#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="egg-break"
LOADER_LINE='dofile(os.getenv("HOME") .. "/.hammerspoon/egg-break/init.lua")'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HAMMERSPOON_DIR="${HOME}/.hammerspoon"
INSTALL_DIR="${HAMMERSPOON_DIR}/${PROJECT_NAME}"
GLOBAL_INIT="${HAMMERSPOON_DIR}/init.lua"

mkdir -p "${HAMMERSPOON_DIR}"
rm -rf "${INSTALL_DIR}"
mkdir -p "${INSTALL_DIR}"

if command -v rsync >/dev/null 2>&1; then
  rsync -a --exclude ".git" --exclude ".DS_Store" "${SCRIPT_DIR}/" "${INSTALL_DIR}/"
else
  cp -R "${SCRIPT_DIR}/." "${INSTALL_DIR}/"
fi

touch "${GLOBAL_INIT}"

if grep -Fqx "${LOADER_LINE}" "${GLOBAL_INIT}"; then
  echo "egg-break loader already exists in ${GLOBAL_INIT}"
else
  {
    printf "\n-- egg-break\n"
    printf "%s\n" "${LOADER_LINE}"
  } >> "${GLOBAL_INIT}"
  echo "Added egg-break loader to ${GLOBAL_INIT}"
fi

echo "Installed egg-break to ${INSTALL_DIR}"
echo "Open Hammerspoon and choose Reload Config from the menu bar."
