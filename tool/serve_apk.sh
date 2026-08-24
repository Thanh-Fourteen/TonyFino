#!/usr/bin/env bash
# TonyFino — phục vụ dist/ qua tailscale serve dưới /tonyfino/.
#
#   tool/serve_apk.sh
#
# ⚠️ E1 — ĐỌC TRƯỚC KHI SỬA FILE NÀY:
# Đường "/" trên https://tony.tailfcdcfc.ts.net/ ĐÃ BỊ CHIẾM bởi project
# "writing task 1" khác (proxy sang 127.0.0.1:8765, cùng /web/, /task1.apk,
# /task1-arm64.apk, /task1-video.mp4). TonyFino CHỈ được dùng /tonyfino/.
#
# TUYỆT ĐỐI KHÔNG chạy `tailscale serve reset` — nó xoá SẠCH cấu hình của
# project kia. `--set-path` là CỘNG THÊM một mount, không đụng các mount có
# sẵn — đó là lý do dùng nó thay vì bất kỳ lệnh "reset rồi set lại" nào.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"
cd "$TONYFINO_ROOT"

EXPECTED_FOREIGN_PATHS=("/" "/web/" "/task1.apk" "/task1-arm64.apk" "/task1-video.mp4")

check_foreign_paths() {
  local status
  status="$(tailscale serve status 2>&1)"
  local missing=0
  for p in "${EXPECTED_FOREIGN_PATHS[@]}"; do
    if ! grep -qF "$p" <<<"$status"; then
      echo "❌ Mục cũ '$p' KHÔNG còn trong tailscale serve status — DỪNG LẠI, kiểm tra thủ công." >&2
      missing=1
    fi
  done
  echo "$status"
  return $missing
}

if [ ! -f dist/tonyfino-latest.apk ]; then
  echo "❌ Thiếu dist/tonyfino-latest.apk — chạy tool/build_apk.sh trước." >&2
  exit 1
fi

echo "→ tailscale serve status TRƯỚC khi set (đối chiếu sau)"
check_foreign_paths || { echo "❌ Đã thiếu mục cũ TRƯỚC khi làm gì — dừng, không set thêm." >&2; exit 1; }

echo "→ tailscale serve --bg --set-path /tonyfino/ dist/"
tailscale serve --bg --set-path /tonyfino/ "$TONYFINO_ROOT/dist"

echo "→ tailscale serve status SAU khi set — xác nhận 4 mục cũ + /tonyfino/ đều còn"
FINAL_STATUS="$(check_foreign_paths)" || { echo "🔴 MỘT MỤC CŨ ĐÃ MẤT SAU KHI SET — báo Tony ngay." >&2; exit 1; }
echo "$FINAL_STATUS"

if grep -qF "/tonyfino/" <<<"$FINAL_STATUS"; then
  echo "✅ /tonyfino/ đã lên, 4 mục cũ còn nguyên."
  echo "   URL: https://tony.tailfcdcfc.ts.net/tonyfino/tonyfino-latest.apk"
else
  echo "❌ /tonyfino/ không thấy trong status — kiểm tra thủ công." >&2
  exit 1
fi
