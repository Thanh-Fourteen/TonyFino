#!/usr/bin/env bash
# TonyFino — biến môi trường dùng chung.
#
# VÌ SAO TỒN TẠI (E6): máy này KHÔNG set ANDROID_HOME / ANDROID_SDK_ROOT / JAVA_HOME.
# Flutter tự xoay xở được (nó resolve SDK nội bộ và tự ghi android/local.properties),
# nhưng mọi lệnh gọi THẲNG adb / emulator / sdkmanager / avdmanager đều hỏng.
#
# Cố ý KHÔNG sửa ~/.bashrc — dự án phải tự chứa, và người khác clone về là chạy được.
# Dùng:  source tool/env.sh
# ---------------------------------------------------------------------------

export ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-17-openjdk-amd64}"

# cmdline-tools/latest phải đứng TRƯỚC để sdkmanager/avdmanager lấy bản mới
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$JAVA_HOME/bin:$PATH"

# AVD nằm trên SSD (~/.android/avd) — CỐ Ý. Xem ghi chú đĩa bên dưới.
export ANDROID_AVD_HOME="${ANDROID_AVD_HOME:-$HOME/.android/avd}"

export TONYFINO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export TONYFINO_AVD="tonyfino36"
export TONYFINO_APP_ID="dev.tony.tonyfino"
export TONYFINO_KEYSTORE="$HOME/keystores/tonyfino-release.jks"

# ---------------------------------------------------------------------------
# GHI CHÚ ĐĨA (E7) — đọc trước khi định "dọn dẹp" gì đó
#
#   /              SSD Kingston, 109 GB. Đây là nơi mọi thứ IO-ngẫu-nhiên-nặng
#                  phải ở lại: ~/.gradle, ~/.pub-cache, ~/.android/avd, build/,
#                  và source code.
#   /mnt/data1tb   HDD Apple 5400rpm, 916 GB. CHẬM. Chỉ để kho lạnh.
#
#   Đã dời: ~/Android/Sdk/system-images -> /mnt/data1tb/android-dev/system-images
#           (symlink). 4.2 GB, chỉ đọc tuần tự lúc emulator boot nên không sao.
#
#   ĐỪNG dời .gradle / .pub-cache / avd / build sang HDD. Build và emulator sẽ
#   chậm thấy rõ. Nếu SSD lại đầy, chạy tool/clean.sh trước.
# ---------------------------------------------------------------------------
