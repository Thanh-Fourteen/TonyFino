#!/usr/bin/env bash
# TonyFino — boot emulator và chờ tới khi sẵn sàng nhận lệnh.
#
#   tool/emulator.sh              # boot tonyfino36 (API 36) — mặc định
#   tool/emulator.sh test34       # boot AVD khác để sanity pass
#   tool/emulator.sh --window     # có cửa sổ (mặc định là headless)
#
# VÌ SAO CÁC CỜ NÀY (E5):
#   Máy có RTX 2060 nhưng session chạy trên X11 ảo (DISPLAY=:1), không có
#   glxinfo/vulkaninfo, và AVD để hw.gpu.enabled=no. KVM thì DÙNG ĐƯỢC
#   (/dev/kvm có ACL user:tony:rw-) nên CPU nhanh, chỉ GPU là không.
#   -> swiftshader_indirect = render bằng phần mềm. Chậm nhưng ổn định.
#
#   Hệ quả cần nhớ: Flutter 3.44 mặc định dùng Impeller/Vulkan trên Android.
#   Trên SwiftShader nó có thể chậm hoặc rơi về Skia. Nếu phải chạy với
#   --enable-impeller=false thì MỌI golden test chỉ bảo đảm LAYOUT, không bảo
#   đảm pixel — và vòng dogfood APK trên máy thật thành kênh kiểm tra thị giác
#   duy nhất đáng tin. (H7)
# ---------------------------------------------------------------------------
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

AVD="$TONYFINO_AVD"
WINDOW="-no-window"
for arg in "$@"; do
  case "$arg" in
    --window) WINDOW="" ;;
    -*)       echo "cờ lạ: $arg" >&2; exit 2 ;;
    *)        AVD="$arg" ;;
  esac
done

if ! emulator -list-avds | grep -qx "$AVD"; then
  echo "❌ Không có AVD '$AVD'. Đang có:" >&2
  emulator -list-avds >&2
  exit 1
fi

if pgrep -f "qemu-system.*-avd $AVD" >/dev/null; then
  echo "ℹ️  '$AVD' đã chạy sẵn."
else
  echo "→ boot $AVD ${WINDOW:+(headless)}"
  # -no-snapshot-*: luôn boot sạch. Snapshot hay giữ lại state cũ và làm
  # "bug đã sửa rồi mà vẫn thấy" — tốn hàng giờ debug ảo.
  nohup emulator -avd "$AVD" \
    $WINDOW \
    -gpu swiftshader_indirect \
    -noaudio -no-boot-anim \
    -no-snapshot-load -no-snapshot-save \
    -memory 4096 -cores 4 \
    >/tmp/emulator-$AVD.log 2>&1 &
fi

echo "→ chờ boot xong (log: /tmp/emulator-$AVD.log)"
adb wait-for-device
until [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; do
  sleep 2
done

SDK=$(adb shell getprop ro.build.version.sdk | tr -d '\r')
REL=$(adb shell getprop ro.build.version.release | tr -d '\r')
echo "✅ $AVD sẵn sàng — Android $REL (API $SDK)"
[ "$AVD" = "$TONYFINO_AVD" ] && [ "$SDK" != "36" ] && \
  echo "⚠️  Mong đợi API 36 nhưng nhận $SDK — kiểm tra lại AVD." >&2
adb devices -l
