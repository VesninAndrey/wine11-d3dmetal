#!/bin/bash
# Builds Wine from the open-source CrossOver 26.3 code with D3DMetal support.
# Usage: ./setup.sh /path/to/gptk-folder    (must contain lib/external/D3DMetal.framework)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
case "$ROOT" in *" "*) echo "The folder path must not contain spaces: $ROOT"; exit 1;; esac
WORK="$ROOT/.work"; DL="$WORK/dl"; PFX="$WORK/deps"; OUT="$ROOT/wine"; MG="$WORK/llvm-mingw"
J=$(sysctl -n hw.ncpu)
say() { printf '\n== %s\n' "$*"; }
die() { printf '\nError: %s\n' "$*" >&2; exit 1; }

say "Checking the system"
[ "$(uname -m)" = arm64 ] || die "an Apple Silicon Mac is required"
[ "$(sw_vers -productVersion | cut -d. -f1)" -ge 14 ] || die "macOS 14 or newer is required"
arch -x86_64 /usr/bin/true 2>/dev/null || die "Rosetta 2 is missing. Install it: softwareupdate --install-rosetta --agree-to-license"
xcode-select -p >/dev/null 2>&1 || die "Command Line Tools are missing. Install them: xcode-select --install"
PKGCONFIG=$(command -v pkg-config || true); [ -n "$PKGCONFIG" ] || PKGCONFIG=/opt/homebrew/bin/pkg-config
[ -x "$PKGCONFIG" ] || die "pkg-config is missing. Install it: brew install pkgconf"
FREE=$(df -g "$ROOT" | awk 'END{print $4}'); [ "$FREE" -ge 8 ] || die "at least 8 GB of free space is required, found $FREE GB"

GPTK="${1:-${D3DMETAL_SRC:-/Applications/Game Porting Toolkit.app/Contents/Resources/wine}}"
[ -d "$GPTK/lib/external/D3DMetal.framework" ] && [ -f "$GPTK/lib/external/libd3dshared.dylib" ] && [ -f "$GPTK/lib/wine/x86_64-windows/dxgi.dll" ] ||
  die "D3DMetal not found in '$GPTK'. Point to a folder containing lib/external/D3DMetal.framework (see README)"
for f in D3DMetal.framework libd3dshared.dylib; do
  codesign --verify --strict "$GPTK/lib/external/$f" || die "invalid signature: $f"
  info=$(codesign -dvv "$GPTK/lib/external/$f" 2>&1)
  case "$info" in *"Authority=Apple Root CA"*) ;; *) die "$f is not signed by Apple";; esac
done

mkdir -p "$DL" "$PFX" "$ROOT/logs"
fetch() { local f="$DL/$1"; [ -f "$f" ] || curl -fL --retry 3 -o "$f" "$2"; echo "$3  $f" | shasum -a 256 -c - >/dev/null || die "checksum mismatch: $1"; }
say "Downloading sources"
fetch crossover-sources-26.3.0.tar.gz https://media.codeweavers.com/pub/crossover/source/crossover-sources-26.3.0.tar.gz ac99c8ca4b3848f3e81784135f023df266b61c2345726ea55a50b3e030dd6872
fetch llvm-mingw.tar.xz https://github.com/mstorsjo/llvm-mingw/releases/download/20261104/llvm-mingw-20261104-ucrt-macos-universal.tar.xz 66cbd5178c4a71b0d473e68ede172f8eb7d15d023e67f39201d0a69e21f6bf3c
fetch gmp-6.3.0.tar.xz https://ftpmirror.gnu.org/gmp/gmp-6.3.0.tar.xz a3c2b80201b89e68616f4ad30bc66aee4927c3ce50e33929ca819d5c43538898
fetch nettle-4.0.tar.gz https://ftpmirror.gnu.org/nettle/nettle-4.0.tar.gz 3addbc00da01846b232fb3bc453538ea5468da43033f21bb345cb1e9073f5094
fetch gnutls-3.8.13.tar.xz https://www.gnupg.org/ftp/gcrypt/gnutls/v3.8/gnutls-3.8.13.tar.xz ffed8ec1bf09c2426d4f14aae377de4753b53e537d685e604e99a8b16ca9c97e
fetch freetype-2.15.0.tar.xz https://downloads.sourceforge.net/project/freetype/freetype2/2.15.0/freetype-2.15.0.tar.xz 93cd47eb719c325107f2d3cf087d06299e944c3b48a40b55537302304dea1dd5
fetch MoltenVK-macos.tar https://github.com/KhronosGroup/MoltenVK/releases/download/v1.4.2/MoltenVK-macos.tar f95765a6229cb7b915990a2890ce12ebe36a730b021545d3d52ae69ce4c4024e
fetch bison-3.8.2.tar.xz https://ftpmirror.gnu.org/bison/bison-3.8.2.tar.xz 9bba0214ccf7f1079c5d59210045227bcf619519840ebfa80cd3849cff5a5bf2

say "Cross-compiler"
if [ ! -x "$MG/bin/clang" ]; then
  mkdir -p "$MG"; tar xf "$DL/llvm-mingw.tar.xz" -C "$MG" --strip-components=1 --exclude='aarch64-w64-mingw32' --exclude='armv7-w64-mingw32' --exclude='arm64ec-w64-mingw32' --exclude='share/doc' --exclude='share/man'
fi

say "x86_64 dependencies"
if [ ! -x "$PFX/hostbin/bison" ]; then
  B="$WORK/bison"; rm -rf "$B"; mkdir -p "$B"; tar xf "$DL/bison-3.8.2.tar.xz" -C "$B" --strip-components=1
  ( cd "$B" && ./configure --prefix="$PFX/hostbin-root" >/dev/null && make -j"$J" >/dev/null && make install >/dev/null )
  mkdir -p "$PFX/hostbin"; ln -sf ../hostbin-root/bin/bison "$PFX/hostbin/bison"; rm -rf "$B"
fi
dep() {
  local name=$1 tar=$2; shift 2
  [ -f "$PFX/.done-$name" ] && return 0
  local B="$WORK/$name"; rm -rf "$B"; mkdir -p "$B"; tar xf "$DL/$tar" -C "$B" --strip-components=1
  ( cd "$B"
    export MACOSX_DEPLOYMENT_TARGET=13.0 CC="clang -arch x86_64" CXX="clang++ -arch x86_64" CFLAGS="-O2" CXXFLAGS="-O2" CPPFLAGS="-I$PFX/include" LDFLAGS="-L$PFX/lib -Wl,-headerpad_max_install_names"
    export PKG_CONFIG="$PKGCONFIG" PKG_CONFIG_LIBDIR="$PFX/lib/pkgconfig" PKG_CONFIG_PATH=""
    export PATH="$PFX/hostbin:/usr/bin:/bin:/usr/sbin:/sbin"
    arch -x86_64 ./configure --prefix="$PFX" --host=x86_64-apple-darwin --build=x86_64-apple-darwin "$@" > "$ROOT/logs/$name.log" 2>&1
    arch -x86_64 make -j"$J" >> "$ROOT/logs/$name.log" 2>&1
    arch -x86_64 make install >> "$ROOT/logs/$name.log" 2>&1 )
  rm -rf "$B"; touch "$PFX/.done-$name"
}
dep gmp gmp-6.3.0.tar.xz --enable-shared --disable-static --enable-fat
dep nettle nettle-4.0.tar.gz --enable-shared --disable-static --disable-documentation --disable-openssl
dep gnutls gnutls-3.8.13.tar.xz --enable-shared --disable-static --with-included-libtasn1 --with-included-unistring --without-p11-kit --without-idn --without-zlib --without-zstd --without-brotli --disable-doc --disable-tools --disable-tests --disable-cxx --disable-guile --disable-nls
dep freetype freetype-2.15.0.tar.xz --enable-shared --disable-static --without-png --without-brotli --without-bzip2 --without-harfbuzz --without-zlib

say "MoltenVK"
if [ ! -f "$PFX/lib/libMoltenVK.dylib" ]; then
  T="$WORK/moltenvk"; rm -rf "$T"; mkdir -p "$T"; tar xf "$DL/MoltenVK-macos.tar" -C "$T"
  cp "$T/MoltenVK/MoltenVK/dynamic/dylib/macOS/libMoltenVK.dylib" "$PFX/lib/" 2>/dev/null || cp "$(find "$T" -path '*macOS/libMoltenVK.dylib' | head -1)" "$PFX/lib/"
  rm -rf "$T"
fi

say "Wine sources and patches"
SRC="$WORK/wine-src"
if [ ! -f "$SRC/.patched" ]; then
  rm -rf "$SRC"; mkdir -p "$SRC"; tar xzf "$DL/crossover-sources-26.3.0.tar.gz" -C "$SRC" --strip-components=2 sources/wine
  for p in "$ROOT"/patches/*.patch; do patch -p1 -d "$SRC" < "$p"; done
  touch "$SRC/.patched"
fi

say "Building Wine"
B="$WORK/build-vulkan"; mkdir -p "$B"
(
  cd "$B"
  # llvm-mingw goes last in PATH: its own clang does not know the macOS SDK
  export PATH="$PFX/hostbin:/usr/bin:/bin:/usr/sbin:/sbin:$MG/bin"
  export MACOSX_DEPLOYMENT_TARGET=14.0 CC="clang -arch x86_64" CXX="clang++ -arch x86_64" OBJC="clang -arch x86_64"
  export CFLAGS="-O2" CXXFLAGS="-O2" OBJCFLAGS="-O2" CROSSCFLAGS="-O2" LDFLAGS="-L$PFX/lib" CPPFLAGS="-I$PFX/include"
  export PKG_CONFIG="$PKGCONFIG" PKG_CONFIG_LIBDIR="$PFX/lib/pkgconfig" PKG_CONFIG_PATH="" BISON="$PFX/hostbin/bison"
  [ -f Makefile ] || arch -x86_64 "$SRC/configure" --prefix="$OUT" --enable-win64 --enable-archs=i386,x86_64 --disable-tests \
    --with-mingw="$MG/bin/clang" --with-coreaudio --with-freetype --with-gnutls --with-pcsclite --with-opencl --with-pthread \
    --without-alsa --without-capi --without-cups --without-dbus --without-ffmpeg --without-fontconfig \
    --without-gettext --without-gettextpo --without-gphoto --without-gssapi --without-gstreamer --without-inotify \
    --without-krb5 --without-netapi --without-oss --without-pcap --without-pulse --without-sane --without-sdl \
    --without-udev --without-usb --without-v4l2 --with-vulkan --without-wayland --without-x > "$ROOT/logs/wine-configure.log" 2>&1
  nice -n 10 arch -x86_64 make -j"$J" > "$ROOT/logs/wine-build.log" 2>&1
  arch -x86_64 make install-lib >> "$ROOT/logs/wine-build.log" 2>&1
)

say "Installing D3DMetal from your GPTK copy"
mkdir -p "$OUT/lib/external"
rm -rf "$OUT/lib/external/D3DMetal.framework" "$OUT/lib/external/libd3dshared.dylib"
cp -Rc "$GPTK/lib/external/D3DMetal.framework" "$GPTK/lib/external/libd3dshared.dylib" "$OUT/lib/external/"
for d in dxgi d3d10 d3d11 d3d12 atidxx64; do
  rm -f "$OUT/lib/wine/x86_64-windows/$d.dll" "$OUT/lib/wine/x86_64-unix/$d.so"
  cp -c "$GPTK/lib/wine/x86_64-windows/$d.dll" "$OUT/lib/wine/x86_64-windows/$d.dll"
  ln -s ../../external/libd3dshared.dylib "$OUT/lib/wine/x86_64-unix/$d.so"
done

say "Relocatable copy of the libraries"
# The build needs libraries with full paths, so only a separate copy is made relocatable
FINAL="$ROOT/deps"; rm -rf "$FINAL"; mkdir -p "$FINAL"; cp -Rc "$PFX/lib" "$FINAL/lib"
rm -rf "$FINAL/lib/pkgconfig" "$FINAL"/lib/*.la
for f in "$FINAL"/lib/*.dylib; do
  [ -L "$f" ] && continue
  chmod u+w "$f"
  install_name_tool -id "@rpath/$(basename "$f")" "$f"
  otool -L "$f" | awk -v p="$PFX/lib/" 'index($1,p)==1{print $1}' | while read -r dep; do
    install_name_tool -change "$dep" "@loader_path/$(basename "$dep")" "$f"
  done
  codesign -f -s - "$f" 2>/dev/null
done

say "Test program"
"$MG/bin/x86_64-w64-mingw32-clang" -O2 "$ROOT/test/d3dtest.c" -o "$ROOT/test/d3dtest.exe" -ld3d11 -ldxgi -ld3d12 -luser32 -luuid
"$MG/bin/x86_64-w64-mingw32-clang" -O2 "$ROOT/test/vulkantest.c" -o "$ROOT/test/vulkantest.exe"
"$OUT/bin/wine" --version
say "Done. Next: ./run.sh test"
