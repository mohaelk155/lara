#!/bin/bash
# build_ipa.sh — compatible con Xcode 16.x SIN xcpretty
#
# Cambios respecto al original (que fallaba en Xcode 16.2):
#   1) Quitado el pipe a `xcpretty` (ya no existe en Homebrew y su ausencia
#      rompia el pipe -> no se compilaba nada).
#   2) La salida completa de xcodebuild va a build/xcodebuild.log.
#   3) Se comprueba ldid y se usa el entitlements de Config/ o other/.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

rm -rf build/
mkdir -p build

echo "Build Started!"
echo "Xcode: $(xcodebuild -version | head -1)"
echo

ENT="Config/lara.entitlements"
if [ ! -f "$ENT" ]; then
  ENT="other/lara.entitlements"
fi
if [ ! -f "$ENT" ]; then
  echo "ERROR: no encuentro lara.entitlements (Config/ ni other/)" >&2
  exit 1
fi
echo "Entitlements: $ENT"

set +e
xcodebuild \
  -project lara.xcodeproj \
  -scheme lara \
  -configuration Debug \
  -sdk iphoneos \
  -arch arm64e \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGN_ENTITLEMENTS="$ENT" \
  archive \
  -archivePath "$PWD/build/lara.xcarchive" > build/xcodebuild.log 2>&1
BUILD_RC=$?
set -e

if [ $BUILD_RC -ne 0 ]; then
  echo
  echo "===== BUILD FALLÓ (rc=$BUILD_RC) — últimos errores =====" >&2
  grep -E "error:|\*\* .*failed" build/xcodebuild.log | tail -40 >&2 || tail -60 build/xcodebuild.log >&2
  echo "(log completo: build/xcodebuild.log)" >&2
  exit 1
fi

APP_PATH="$PWD/build/lara.xcarchive/Products/Applications/lara.app"
if [ ! -d "$APP_PATH" ]; then
  echo "Missing app at $APP_PATH" >&2
  exit 1
fi
rm -rf "$PWD/build/Payload"
mkdir -p "$PWD/build/Payload"
cp -R "$APP_PATH" "$PWD/build/Payload/"

plutil -replace UIFileSharingEnabled -bool YES "$PWD/build/Payload/lara.app/Info.plist"

if ! command -v ldid >/dev/null 2>&1; then
  echo "ERROR: ldid not installed. Install with: brew install ldid" >&2
  exit 1
fi
ldid -S"$ENT" "$PWD/build/Payload/lara.app/lara"
(cd "$PWD/build" && /usr/bin/zip -qry lara.ipa Payload)

echo
echo "build successful!"
echo "ipa at: build/lara.ipa"
ls -l build/lara.ipa
exit 0
