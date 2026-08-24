#!/usr/bin/env bash
# TonyFino — thu nhỏ 4 file master 1024px trong build/icon_master/ ra đúng
# mọi mật độ trong android/app/src/main/res/.
#
#   flutter test test/tooling/generate_app_icon.dart   # sinh master
#   tool/install_app_icon.sh                            # cài vào res/
#
# Tách làm hai bước vì bước sinh master cần engine Skia (chỉ chạy trong
# tiến trình `flutter test`), còn bước này chỉ là resize. Trước đây bước
# resize làm tay từng file — không lặp lại được và dễ sót một mật độ.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"
cd "$TONYFINO_ROOT"

MASTER=build/icon_master
for f in legacy foreground background monochrome; do
  [ -f "$MASTER/${f}_1024.png" ] || {
    echo "❌ Thiếu $MASTER/${f}_1024.png — chạy 'flutter test test/tooling/generate_app_icon.dart' trước." >&2
    exit 1
  }
done

python3 - <<'PY'
from PIL import Image

RES = 'android/app/src/main/res'
# Adaptive layer: khung 108dp. Legacy launcher: 48dp.
ADAPTIVE = {'mdpi': 108, 'hdpi': 162, 'xhdpi': 216, 'xxhdpi': 324, 'xxxhdpi': 432}
LEGACY = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}

def emit(master, folder_prefix, name, sizes):
    src = Image.open(f'build/icon_master/{master}_1024.png').convert('RGBA')
    for density, size in sizes.items():
        out = f'{RES}/{folder_prefix}-{density}/{name}.png'
        src.resize((size, size), Image.LANCZOS).save(out)
        print(f'  {out}  {size}px')

print('adaptive (drawable-*):')
emit('background', 'drawable', 'ic_launcher_background', ADAPTIVE)
emit('foreground', 'drawable', 'ic_launcher_foreground', ADAPTIVE)
emit('monochrome', 'drawable', 'ic_launcher_monochrome', ADAPTIVE)
print('legacy (mipmap-*):')
emit('legacy', 'mipmap', 'ic_launcher', LEGACY)
emit('legacy', 'mipmap', 'ic_launcher_round', LEGACY)
PY

echo "✅ Đã cài icon vào android/app/src/main/res/"
