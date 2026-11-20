#!/bin/sh
# Turns assets/icon/*.png (from tool/gen_icon_test.dart) into Android launcher icons and web icons.
# Run from wrong-chat/:  sh tool/gen_icons.sh   (needs ffmpeg)
set -e
RES=android/app/src/main/res
for d in mdpi:48:108 hdpi:72:162 xhdpi:96:216 xxhdpi:144:324 xxxhdpi:192:432; do
  name=${d%%:*}; rest=${d#*:}; legacy=${rest%%:*}; adaptive=${rest#*:}
  mkdir -p "$RES/mipmap-$name"
  ffmpeg -loglevel error -y -i assets/icon/icon.png -vf "scale=$legacy:$legacy:flags=lanczos" "$RES/mipmap-$name/ic_launcher.png"
  ffmpeg -loglevel error -y -i assets/icon/icon_fg.png -vf "scale=$adaptive:$adaptive:flags=lanczos" "$RES/mipmap-$name/ic_launcher_foreground.png"
  ffmpeg -loglevel error -y -i assets/icon/icon_bg.png -vf "scale=$adaptive:$adaptive:flags=lanczos" "$RES/mipmap-$name/ic_launcher_background.png"
done
mkdir -p "$RES/mipmap-anydpi-v26"
cat > "$RES/mipmap-anydpi-v26/ic_launcher.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
XML
for s in 192 512; do
  ffmpeg -loglevel error -y -i assets/icon/icon.png -vf "scale=$s:$s:flags=lanczos" "web/icons/Icon-$s.png"
  ffmpeg -loglevel error -y -i assets/icon/icon.png -vf "scale=$s:$s:flags=lanczos" "web/icons/Icon-maskable-$s.png"
done
ffmpeg -loglevel error -y -i assets/icon/icon.png -vf "scale=32:32:flags=lanczos" web/favicon.png
echo "icons written"
