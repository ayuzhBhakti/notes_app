#!/usr/bin/env bash
# Builds every Evos app icon PNG from the SVG drawings in this folder.
#
#   ./tool/app_icon/make_icons.sh
#
# macOS only: Quick Look (qlmanage) renders the SVG, sips resizes it. The
# mark is drawn on the 108-unit grid of an Android adaptive icon; the same
# shapes are in android/app/src/main/res/drawable/ic_launcher_foreground.xml
# (and the gradient in ic_launcher_background.xml), which Android 8 and
# later use instead of these PNGs. Change them together.
set -euo pipefail
cd "$(dirname "$0")/../.."
SRC="tool/app_icon"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

render() { # svg, out png, size
  qlmanage -t -s 1024 -o "$TMP" "$1" >/dev/null 2>&1
  cp "$TMP/$(basename "$1").png" "$TMP/full.png"
  sips -z "$3" "$3" "$TMP/full.png" --out "$2" >/dev/null
}

RES="android/app/src/main/res"
for pair in mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192; do
  d="${pair%%:*}"; px="${pair##*:}"
  render "$SRC/evos_rounded.svg" "$RES/mipmap-$d/ic_launcher.png" "$px"
  render "$SRC/evos_circle.svg" "$RES/mipmap-$d/ic_launcher_round.png" "$px"
done

IOS="ios/Runner/Assets.xcassets/AppIcon.appiconset"
for pair in 20x20@1x:20 20x20@2x:40 20x20@3x:60 29x29@1x:29 29x29@2x:58 \
            29x29@3x:87 40x40@1x:40 40x40@2x:80 40x40@3x:120 60x60@2x:120 \
            60x60@3x:180 76x76@1x:76 76x76@2x:152 83.5x83.5@2x:167 1024x1024@1x:1024; do
  name="${pair%%:*}"; px="${pair##*:}"
  render "$SRC/evos_square.svg" "$TMP/ios.png" "$px"
  # Through JPEG and back, at full quality, to drop the alpha channel: the
  # App Store rejects an icon that has one, even a fully opaque one.
  sips -s format jpeg -s formatOptions 100 "$TMP/ios.png" --out "$TMP/ios.jpg" >/dev/null
  sips -s format png "$TMP/ios.jpg" --out "$IOS/Icon-App-$name.png" >/dev/null
done

# For the Play listing, and to upload as the backend's app_logo_url.
render "$SRC/evos_rounded.svg" "$SRC/evos_logo_1024.png" 1024
render "$SRC/evos_square.svg" "$SRC/evos_icon_512.png" 512
echo "Icons written."
