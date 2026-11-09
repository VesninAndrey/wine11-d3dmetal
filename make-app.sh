#!/bin/zsh
# Builds a standalone app: Wine lives inside it, only the prefix data stays outside.
# ./make-app.sh "Name" 'C:\path\program.exe' [args]
# The app appears on the Desktop and can be moved. The first launch creates the prefix.
set -e
ROOT="${0:A:h}"
[[ -x "$ROOT/wine/bin/wine" ]] || { echo "Run ./setup.sh first"; exit 1; }
[[ $# -ge 2 ]] || { sed -n 3p "$0"; exit 1; }
NAME="$1"; EXE="$2"; shift 2
APP="$HOME/Desktop/$NAME.app"; R="$APP/Contents/Resources"
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS" "$R"
cp -Rc "$ROOT/wine" "$ROOT/deps" "$ROOT/test" "$ROOT/run.sh" "$R/"
{ print -r -- '#!/bin/zsh'; print -r -- "exec \"\${0:A:h:h}/Resources/run.sh\" wine ${(q)EXE} ${(q)@}"; } > "$APP/Contents/MacOS/launch"
chmod +x "$APP/Contents/MacOS/launch"
cat > "$APP/Contents/Info.plist" <<P
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>$NAME</string>
<key>CFBundleIdentifier</key><string>local.d3dmetal-wine.app</string>
<key>CFBundleExecutable</key><string>launch</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSUIElement</key><true/>
</dict></plist>
P
plutil -lint "$APP/Contents/Info.plist" >/dev/null
touch "$APP"; echo "Done: $APP"
