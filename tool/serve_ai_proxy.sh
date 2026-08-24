#!/usr/bin/env bash
# TonyFino — chạy proxy AI fallback (Phase 23, D8) + phục vụ qua tailscale
# serve dưới /tonyfino-ai/, CẠNH /tonyfino/ và mọi mount đã có.
#
#   tool/serve_ai_proxy.sh
#
# ⚠️ E1 — ĐỌC TRƯỚC KHI SỬA FILE NÀY: xem ghi chú đầy đủ ở tool/serve_apk.sh.
# TUYỆT ĐỐI KHÔNG chạy `tailscale serve reset`. `--set-path` chỉ CỘNG THÊM
# một mount, không đụng các mount có sẵn.
#
# Proxy tự nó CHỈ bind 127.0.0.1 (xem ai_proxy/bin/server.dart) — tailscale
# serve là lớp mạng DUY NHẤT đưa nó ra tailnet, và tailnet đã xác thực theo
# danh tính thiết bị nên APK không cần chứa credential nào (D8).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"
cd "$TONYFINO_ROOT"

PORT="${TONYFINO_AI_PROXY_PORT:-8766}"
PID_FILE="ai_proxy/.server.pid"
LOG_FILE="ai_proxy/.server.log"

EXPECTED_FOREIGN_PATHS=("/" "/web/" "/task1.apk" "/task1-arm64.apk" "/task1-video.mp4" "/tonyfino/")

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

if [ -f ai_proxy/.env ]; then
  set -a
  # shellcheck source=/dev/null
  source ai_proxy/.env
  set +a
fi

if [ -z "${GEMINI_API_KEY:-}" ]; then
  echo "⚠️  GEMINI_API_KEY chưa có (ai_proxy/.env chưa điền hoặc chưa tồn tại)." >&2
  echo "   Vẫn tiếp tục mount /tonyfino-ai/ — chỉ là proxy sẽ báo lỗi rõ ràng" >&2
  echo "   cho mọi request tới khi Tony dán khoá thật vào ai_proxy/.env rồi" >&2
  echo "   chạy lại script này (xem ai_proxy/.env.example)." >&2
fi

if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  echo "→ Proxy đã chạy sẵn (PID $(cat "$PID_FILE")), không khởi động lại."
elif [ -n "${GEMINI_API_KEY:-}" ]; then
  echo "→ Khởi động proxy trên 127.0.0.1:$PORT (nền, log ở $LOG_FILE)"
  (cd ai_proxy && dart pub get >/dev/null)
  TONYFINO_AI_PROXY_PORT="$PORT" GEMINI_API_KEY="$GEMINI_API_KEY" \
    nohup dart run ai_proxy/bin/server.dart >"$LOG_FILE" 2>&1 &
  echo $! >"$PID_FILE"
  sleep 1
  if ! kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "❌ Proxy thoát ngay sau khi khởi động — xem $LOG_FILE." >&2
    exit 1
  fi
else
  echo "→ Bỏ qua khởi động proxy (chưa có khoá) — chỉ set mount tailscale."
fi

echo "→ tailscale serve status TRƯỚC khi set (đối chiếu sau)"
check_foreign_paths || { echo "❌ Đã thiếu mục cũ TRƯỚC khi làm gì — dừng, không set thêm." >&2; exit 1; }

echo "→ tailscale serve --bg --set-path /tonyfino-ai/ $PORT"
tailscale serve --bg --set-path /tonyfino-ai/ "$PORT"

echo "→ tailscale serve status SAU khi set — xác nhận mọi mục cũ + /tonyfino-ai/ đều còn"
FINAL_STATUS="$(check_foreign_paths)" || { echo "🔴 MỘT MỤC CŨ ĐÃ MẤT SAU KHI SET — báo Tony ngay." >&2; exit 1; }
echo "$FINAL_STATUS"

if grep -qF "/tonyfino-ai/" <<<"$FINAL_STATUS"; then
  echo "✅ /tonyfino-ai/ đã lên, mọi mục cũ còn nguyên."
  echo "   URL: https://tony.tailfcdcfc.ts.net/tonyfino-ai/"
else
  echo "❌ /tonyfino-ai/ không thấy trong status — kiểm tra thủ công." >&2
  exit 1
fi
