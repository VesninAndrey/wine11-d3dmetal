#!/bin/zsh
# ./run.sh test                  check D3D11 and D3D12 through D3DMetal
# ./run.sh vulkan                check Vulkan through MoltenVK
# ./run.sh wine command [args]   any Wine command (wine winecfg, wine C:\path\game.exe)
# ./run.sh exe file [args]       run a Windows program from a Mac path, in its own folder
# ./run.sh wait                  wait until every program in the prefix exits
# ./run.sh stop                  stop everything in this prefix
# Set WINEPREFIX to use another prefix. Files are found next to this script, so the folder can be moved.
ROOT="${0:A:h}"
W="$ROOT/wine"
WINE="$W/bin/wine"
export WINEPREFIX="${WINEPREFIX:-$HOME/Library/Application Support/D3DMetal Wine/prefix}" WINEDEBUG="${WINEDEBUG:--all}"
export WINEDLLOVERRIDES="${WINEDLLOVERRIDES:-mscoree,mshtml=}" WINEMSYNC=1 WINEESYNC=1
export DYLD_FALLBACK_LIBRARY_PATH="$ROOT/deps/lib:$W/lib/external:/usr/lib"
# D3DMetal crashes without these two variables
export CX_APPLEGPTK_LIBD3DSHARED_PATH="$W/lib/external/libd3dshared.dylib" CX_ACTIVE_GRAPHICS_BACKEND=d3dmetal
mkdir -p "${WINEPREFIX:h}"
[[ -x "$WINE" ]] || { echo "Run ./setup.sh first"; exit 1; }

first_run() {
  [[ -d "$WINEPREFIX/drive_c" ]] && return
  "$WINE" wineboot -i > /dev/null 2>&1
  "$W/bin/wineserver" -w
}

case "$1" in
  test) first_run; "$WINE" "$ROOT/test/d3dtest.exe" 2>&1 ;;
  vulkan) first_run; "$WINE" "$ROOT/test/vulkantest.exe" 2>&1 ;;
  wine) first_run; shift; exec "$WINE" "$@" ;;
  exe) first_run; shift; cd "${1:h}"; exec "$WINE" "${1:t}" "${@:2}" ;;
  wait) "$W/bin/wineserver" -w ;;
  stop) "$W/bin/wineserver" -k ;;
  *) sed -n 2,8p "$0" ;;
esac
