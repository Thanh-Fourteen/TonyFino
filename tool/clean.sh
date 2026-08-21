#!/usr/bin/env bash
# TonyFino — dọn SSD khi chật.
#
#   tool/clean.sh          # xem sẽ xoá gì, KHÔNG xoá (mặc định)
#   tool/clean.sh --yes    # xoá thật
#
# Xếp theo mức độ an toàn. Mọi thứ ở đây đều TÁI TẠO ĐƯỢC — không đụng vào
# source, drift_schemas/, test/fixtures/, raw_rolly/, hay keystore.
# ---------------------------------------------------------------------------
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"
cd "$TONYFINO_ROOT"

DRY=1; [ "${1:-}" = "--yes" ] && DRY=0
run() { if [ $DRY -eq 1 ]; then echo "   [thử] $*"; else echo "   [chạy] $*"; eval "$@"; fi; }
size() { du -sh "$1" 2>/dev/null | cut -f1 || echo "-"; }

echo "=== Trước ==="; df -h / /mnt/data1tb | sed 1d; echo

echo "1. build/ của dự án  ($(size build))"
run "rm -rf '$TONYFINO_ROOT/build'"

echo "2. .dart_tool/       ($(size .dart_tool))"
run "rm -rf '$TONYFINO_ROOT/.dart_tool'"

echo "3. Gradle daemon logs + cache build cũ  ($(size ~/.gradle/caches/build-cache-1))"
run "rm -rf ~/.gradle/daemon ~/.gradle/caches/build-cache-1"

echo "4. Gradle dist thừa (giữ bản mới nhất)"
if [ -d ~/.gradle/wrapper/dists ]; then
  ls -1t ~/.gradle/wrapper/dists 2>/dev/null | tail -n +2 | while read -r d; do
    run "rm -rf ~/.gradle/wrapper/dists/'$d'"
  done
fi

echo "5. AVD tạm + snapshot  ($(size ~/.android/avd))"
run "find ~/.android/avd -name '*.lock' -delete"
run "rm -rf ~/.android/avd/*.avd/snapshots"

echo
echo "── KHÔNG tự động xoá (cân nhắc thủ công) ─────────────────────────────"
echo "   ~/.pub-cache                 $(size ~/.pub-cache)   # tải lại mất thời gian"
echo "   ~/Android/Sdk/ndk            $(size ~/Android/Sdk/ndk)   # cần cho sqlite3mc"
echo "   AVD test34                   $(size ~/.android/avd/test34.avd)   # còn dùng để sanity pass API 34"
echo "   /mnt/data1tb/android-dev     $(size /mnt/data1tb/android-dev)   # trên HDD, không tốn SSD"
echo
[ $DRY -eq 1 ] && echo "→ Đây là chạy thử. Thêm --yes để xoá thật." || { echo "=== Sau ==="; df -h / | sed 1d; }
