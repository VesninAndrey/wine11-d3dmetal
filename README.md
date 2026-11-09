# wine11-d3dmetal

[Русская версия](README-RU.md)

Wine 11 for Apple Silicon Macs with D3DMetal support, built from open source. Runs Windows programs and DirectX 11 and 12 games through D3DMetal.

Tested on Apple M5 Pro, macOS 26.5.2.

## Requirements

- An Apple Silicon Mac, macOS 14 or newer.
- Rosetta 2: `softwareupdate --install-rosetta --agree-to-license`
- Command Line Tools: `xcode-select --install`
- pkg-config: `brew install pkgconf`
- 8 GB of free disk space.
- A folder with Apple's D3DMetal, see below.

## Getting D3DMetal

D3DMetal is closed source, ships with Apple's Game Porting Toolkit and is not part of this repository because it may not be redistributed. Get it yourself and follow Apple's license.

You need a folder containing:

```
lib/external/D3DMetal.framework
lib/external/libd3dshared.dylib
lib/wine/x86_64-windows/dxgi.dll   (plus d3d10, d3d11, d3d12, atidxx64)
```

Tested with `Game Porting Toolkit.app/Contents/Resources/wine` from [Gcenx/game-porting-toolkit](https://github.com/Gcenx/game-porting-toolkit/releases), version 3.0-3. Setup checks that `D3DMetal.framework` and `libd3dshared.dylib` are signed by Apple. The DLL stubs are unsigned, so their origin cannot be checked.

## Install

1. Clone the repository into a folder with no spaces in its path.
2. Build it, pointing to the D3DMetal folder:

   ```bash
   ./setup.sh "/path/to/Game Porting Toolkit.app/Contents/Resources/wine"
   ```

3. Check D3DMetal:

   ```bash
   ./run.sh test
   ```

   The output should end with `D3D11 present loop 00000000 frames 120` and `END`.

Vulkan works through MoltenVK. To check it:

```bash
./run.sh vulkan
```

After the build the folder can be moved: `run.sh` finds its own files.

## Running programs

```bash
./run.sh exe "/path/on/mac/game.exe" -force-d3d11
```

```bash
./run.sh wine 'C:\Program Files\Game\game.exe'
```

The default prefix is `~/Library/Application Support/D3DMetal Wine/prefix`. Set `WINEPREFIX` to use another one.

To make a standalone Desktop app with Wine inside it:

```bash
./make-app.sh "My Game" 'C:\Program Files\Game\game.exe' -force-d3d11
```

## Adding arguments to a program

`WINE_APPEND_ARGS` appends arguments to programs by name. Use it when one program starts another and does not pass a flag along.

```bash
WINE_APPEND_ARGS='helper.exe=--some-flag;other.exe=--flag2' ./run.sh wine main.exe
```

## Steam

The Windows Steam client works with two launch settings. Without them its window is black: Steam's embedded Chromium draws from a separate process, and Wine on macOS cannot show an image in a window owned by another process.

```bash
curl -fLO https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe
./run.sh wine "$PWD/SteamSetup.exe" /S
./run.sh wait
WINE_APPEND_ARGS='steamwebhelper.exe=--in-process-gpu' SteamNoOverlayUIDrawing=1 ./run.sh wine 'C:\Program Files (x86)\Steam\steam.exe' -cef-disable-gpu-compositing
```

- On first launch Steam updates itself and exits: run the last command again.
- The sign-in window may open behind other windows: press Cmd+Tab and choose `wine`.
- One account cannot be signed in to two clients at once.
- Start games from Steam. If a game needs a flag, add it to the game's launch options.
- On a game's first launch Steam may ask about cloud saves. Answer it, or the game will not start.

## Troubleshooting

| What you see | Cause | What to do |
|---|---|---|
| A program hangs while listing drives (for example, Steam never connects) | Wine reads a one-byte `BOOLEAN` argument as four bytes | Patch `0001`, check that it applied |
| D3DMetal crashes immediately | `CX_APPLEGPTK_LIBD3DSHARED_PATH` and `CX_ACTIVE_GRAPHICS_BACKEND` are not set | Launch through `run.sh` or the app |
| The test fails with `__wine_unix_call` | Plain Wine without D3DMetal support is being used | Use this Wine |
| A Unity game picks D3D12 and crashes | The game rejects D3D12 at the low core count it sees under Wine | Add `-force-d3d11` |
| Videos do not play | Built without GStreamer and ffmpeg | A limitation of this build |

Build errors are in `logs/` next to `setup.sh`. Re-run setup: finished steps are skipped.

## What it is built from

| Component | Source | sha256 |
|---|---|---|
| Wine from CrossOver 26.3.0 | https://media.codeweavers.com/pub/crossover/source/crossover-sources-26.3.0.tar.gz | `ac99c8ca4b3848f3e81784135f023df266b61c2345726ea55a50b3e030dd6872` |
| llvm-mingw 20261104 | https://github.com/mstorsjo/llvm-mingw/releases/tag/20261104 | `66cbd5178c4a71b0d473e68ede172f8eb7d15d023e67f39201d0a69e21f6bf3c` |
| gmp 6.3.0 | https://ftpmirror.gnu.org/gmp/gmp-6.3.0.tar.xz | `a3c2b80201b89e68616f4ad30bc66aee4927c3ce50e33929ca819d5c43538898` |
| nettle 4.0 | https://ftpmirror.gnu.org/nettle/nettle-4.0.tar.gz | `3addbc00da01846b232fb3bc453538ea5468da43033f21bb345cb1e9073f5094` |
| gnutls 3.8.13 | https://www.gnupg.org/ftp/gcrypt/gnutls/v3.8/gnutls-3.8.13.tar.xz | `ffed8ec1bf09c2426d4f14aae377de4753b53e537d685e604e99a8b16ca9c97e` |
| freetype 2.15.0 | https://downloads.sourceforge.net/project/freetype/freetype2/2.15.0/freetype-2.15.0.tar.xz | `93cd47eb719c325107f2d3cf087d06299e944c3b48a40b55537302304dea1dd5` |
| MoltenVK 1.4.2 | https://github.com/KhronosGroup/MoltenVK/releases/tag/v1.4.2 | `f95765a6229cb7b915990a2890ce12ebe36a730b021545d3d52ae69ce4c4024e` |
| bison 3.8.2, build only | https://ftpmirror.gnu.org/bison/bison-3.8.2.tar.xz | `9bba0214ccf7f1079c5d59210045227bcf619519840ebfa80cd3849cff5a5bf2` |

Patches in `patches/`:

- `0001` fixes an endless loop in `GetLogicalDrives`. Windows code writes only the low byte of the `BOOLEAN` `restart` argument of `NtQueryDirectoryObject`, but the macOS compiler assumes the upper bytes are zero and tests all four. Stack garbage in them makes every call restart from the first entry. The same pattern may affect other `BOOLEAN` syscall arguments.
- `0002` adds the `WINE_APPEND_ARGS` setting.

The build does not update itself or download anything at run time.

## License

Wine and the patches to it are under LGPL-2.1. D3DMetal and the Game Porting Toolkit belong to Apple and are not part of this repository.
