# wine11-d3dmetal

[English](README.md)

Wine для мака с поддержкой D3DMetal, собранный из открытых исходников. Запускает Windows-программы и игры DirectX 11 и 12 на Apple Silicon через D3DMetal.

Проверено на Apple M5 Pro, macOS 26.5.2.

## Что нужно

- Мак на Apple Silicon, macOS 14 или новее.
- Rosetta 2: `softwareupdate --install-rosetta --agree-to-license`
- Command Line Tools: `xcode-select --install`
- pkg-config: `brew install pkgconf`
- 14 ГБ свободного места.
- Папка с D3DMetal от Apple, см. следующий раздел.

## Где взять D3DMetal

D3DMetal закрыт, входит в Game Porting Toolkit от Apple и в этот репозиторий не входит: распространять его нельзя. Возьмите его сами и соблюдайте лицензию Apple.

Нужна папка, внутри которой есть:

```
lib/external/D3DMetal.framework
lib/external/libd3dshared.dylib
lib/wine/x86_64-windows/dxgi.dll   (и d3d10, d3d11, d3d12, atidxx64)
```

Проверено с папкой `Game Porting Toolkit.app/Contents/Resources/wine` из сборки [Gcenx/game-porting-toolkit](https://github.com/Gcenx/game-porting-toolkit/releases), версия 3.0-3. Установка проверяет, что `D3DMetal.framework` и `libd3dshared.dylib` подписаны Apple. DLL-заглушки не подписаны, их подпись проверить нельзя.

## Установка

1. Склонируйте репозиторий в папку без пробелов в пути.
2. Запустите сборку, указав папку с D3DMetal:

   ```bash
   ./setup.sh "/путь/к/Game Porting Toolkit.app/Contents/Resources/wine"
   ```

3. Проверьте D3DMetal:

   ```bash
   ./run.sh test
   ```

   В конце должно быть `D3D11 present loop 00000000 frames 120` и `END`.

Vulkan работает через MoltenVK, видео через GStreamer. Проверка:

```bash
./run.sh vulkan
```

```bash
./run.sh video /путь/к/ролику.mp4
```

При первой проверке видео GStreamer сканирует модули и может казаться зависшим. В конце должно быть `frames` больше нуля и `END`.

После сборки папку можно перенести: `run.sh` находит свои файлы сам.

## Запуск программ

```bash
./run.sh exe "/путь/на/маке/game.exe" -force-d3d11
```

```bash
./run.sh wine 'C:\Program Files\Game\game.exe'
```

Префикс по умолчанию лежит в `~/Library/Application Support/D3DMetal Wine/prefix`, другой задаётся через `WINEPREFIX`.

Самостоятельное приложение на рабочий стол, Wine будет внутри него:

```bash
./make-app.sh "Моя игра" 'C:\Program Files\Game\game.exe' -force-d3d11
```

## Добавить аргументы программе

`WINE_APPEND_ARGS` дописывает аргументы к программам по имени. Это нужно, когда программа запускает другую и не передаёт ей нужный флаг.

```bash
WINE_APPEND_ARGS='helper.exe=--some-flag;other.exe=--flag2' ./run.sh wine main.exe
```

## Подсказка для Steam

Steam для Windows работает с двумя настройками запуска. Без них окно Steam будет чёрным: Chromium внутри Steam рисует в отдельном процессе, а Wine на маке не показывает картинку в чужом окне.

```bash
curl -fLO https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe
./run.sh wine "$PWD/SteamSetup.exe" /S
./run.sh wait
WINE_APPEND_ARGS='steamwebhelper.exe=--in-process-gpu' SteamNoOverlayUIDrawing=1 ./run.sh wine 'C:\Program Files (x86)\Steam\steam.exe' -cef-disable-gpu-compositing
```

- При первом запуске Steam обновится и закроется: повторите последнюю команду.
- Окно входа может открыться за другими окнами: Cmd+Tab, пункт `wine`.
- Один аккаунт в двух клиентах сразу не работает.
- Игры запускайте из Steam. Если игре нужен флаг, добавьте его в параметры запуска игры.
- При первом запуске игры Steam может спросить про облачные сохранения. Ответьте, иначе игра не стартует.

## Если что-то пошло не так

| Что видите | В чём дело | Что сделать |
|---|---|---|
| Программа зависает, вечно спрашивая список дисков (например, Steam не подключается) | Wine читает однобайтовый аргумент `BOOLEAN` как четыре байта | Правка `0001`, проверьте, что наложилась |
| D3DMetal падает сразу | Нет переменных `CX_APPLEGPTK_LIBD3DSHARED_PATH` и `CX_ACTIVE_GRAPHICS_BACKEND` | Запускайте через `run.sh` или приложение |
| Тест падает с `__wine_unix_call` | Используется обычный Wine без поддержки D3DMetal | Запускайте этот Wine |
| Игра на Unity выбирает D3D12 и падает | Игра не пускает D3D12 при малом числе ядер под Wine | Добавьте `-force-d3d11` |

Ошибки при сборке смотрите в `logs/` рядом с `setup.sh`. Запускайте установку заново: готовые шаги она пропустит.

## Из чего собрано

| Компонент | Адрес | sha256 |
|---|---|---|
| Wine из CrossOver 26.3.0 | https://media.codeweavers.com/pub/crossover/source/crossover-sources-26.3.0.tar.gz | `ac99c8ca4b3848f3e81784135f023df266b61c2345726ea55a50b3e030dd6872` |
| llvm-mingw 20261104 | https://github.com/mstorsjo/llvm-mingw/releases/tag/20261104 | `66cbd5178c4a71b0d473e68ede172f8eb7d15d023e67f39201d0a69e21f6bf3c` |
| gmp 6.3.0 | https://ftpmirror.gnu.org/gmp/gmp-6.3.0.tar.xz | `a3c2b80201b89e68616f4ad30bc66aee4927c3ce50e33929ca819d5c43538898` |
| nettle 4.0 | https://ftpmirror.gnu.org/nettle/nettle-4.0.tar.gz | `3addbc00da01846b232fb3bc453538ea5468da43033f21bb345cb1e9073f5094` |
| gnutls 3.8.13 | https://www.gnupg.org/ftp/gcrypt/gnutls/v3.8/gnutls-3.8.13.tar.xz | `ffed8ec1bf09c2426d4f14aae377de4753b53e537d685e604e99a8b16ca9c97e` |
| freetype 2.15.0 | https://downloads.sourceforge.net/project/freetype/freetype2/2.15.0/freetype-2.15.0.tar.xz | `93cd47eb719c325107f2d3cf087d06299e944c3b48a40b55537302304dea1dd5` |
| MoltenVK 1.4.2 | https://github.com/KhronosGroup/MoltenVK/releases/tag/v1.4.2 | `f95765a6229cb7b915990a2890ce12ebe36a730b021545d3d52ae69ce4c4024e` |
| GStreamer 1.28.1, runtime | https://gstreamer.freedesktop.org/data/pkg/osx/1.28.1/gstreamer-1.0-1.28.1-universal.pkg | `02803f73435daabe8fb12b79c38c6775d0efb83af001474558ba25c4f874d305` |
| GStreamer 1.28.1, devel, только для сборки | https://gstreamer.freedesktop.org/data/pkg/osx/1.28.1/gstreamer-1.0-devel-1.28.1-universal.pkg | `df167b41559afbcd743276c6b068cba2ada8f5b69eb68095415a7a5a7515e52c` |
| bison 3.8.2, только для сборки | https://ftpmirror.gnu.org/bison/bison-3.8.2.tar.xz | `9bba0214ccf7f1079c5d59210045227bcf619519840ebfa80cd3849cff5a5bf2` |

Правки в `patches/`:

- `0001` — исправляет вечный цикл в `GetLogicalDrives`. Windows-код записывает только младший байт аргумента `restart` типа `BOOLEAN` у `NtQueryDirectoryObject`, а компилятор macOS считает старшие байты нулями и проверяет все четыре. Мусор в стеке заставляет каждый вызов начинать обход сначала. Такая же ошибка может быть у других аргументов `BOOLEAN` в системных вызовах.
- `0002` — настройка `WINE_APPEND_ARGS`.

Сборка ничего не обновляет и не скачивает при запуске.

## Лицензии

Wine и правки к нему распространяются по LGPL-2.1. D3DMetal и Game Porting Toolkit принадлежат Apple и в репозиторий не входят.
