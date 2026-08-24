#!/usr/bin/env bash
# TonyFino — build universal release APK, ký bằng keystore release (D3).
#
#   tool/build_apk.sh
#
# TUYỆT ĐỐI KHÔNG --split-per-abi (D6): emulator là x86_64, điện thoại thật
# là arm64-v8a — split nghĩa là file đã test kỹ không phải file đem cài.
#
# Nhúng GIT_SHA + BUILD_TIME qua --dart-define (D4) — hiện ở Settings → About
# (`lib/core/build_info.dart`). Copy kết quả ra dist/ dưới TÊN FILE THẬT,
# không phải symlink (giữ đúng quy ước Phase 14).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"
cd "$TONYFINO_ROOT"

if [ ! -f "$TONYFINO_KEYSTORE" ]; then
  echo "❌ Thiếu keystore release: $TONYFINO_KEYSTORE (xem docs/decisions.md § D3)" >&2
  exit 1
fi
if [ ! -f android/key.properties ]; then
  echo "❌ Thiếu android/key.properties — Gradle sẽ fail lớn đúng như thiết kế (D3)." >&2
  exit 1
fi

GIT_SHA="$(git rev-parse --short=8 HEAD)"
BUILD_TIME="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
VERSION="$(grep '^version:' pubspec.yaml | awk '{print $2}')"

echo "→ flutter build apk --release (universal, KHÔNG split-per-abi)"
echo "  version=$VERSION git_sha=$GIT_SHA build_time=$BUILD_TIME"
flutter build apk --release \
  --dart-define=GIT_SHA="$GIT_SHA" \
  --dart-define=BUILD_TIME="$BUILD_TIME"

mkdir -p dist
SRC="build/app/outputs/flutter-apk/app-release.apk"
DEST="dist/tonyfino-${VERSION}.apk"
cp "$SRC" "$DEST"
# File THẬT, không symlink — tailscale serve phải phục vụ đúng byte đã build.
cp "$SRC" dist/tonyfino-latest.apk

echo "✅ $DEST"
echo "✅ dist/tonyfino-latest.apk ($(du -h dist/tonyfino-latest.apk | cut -f1))"
sha256sum "$DEST"
