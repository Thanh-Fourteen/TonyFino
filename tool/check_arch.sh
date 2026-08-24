#!/usr/bin/env bash
# Ép luật kiến trúc bằng máy thay vì bằng trí nhớ.
# Chạy trong CI và trước mỗi commit quan trọng. Trả về khác 0 nếu vi phạm.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
fail=0

viol() { echo "  ❌ $1"; fail=1; }

echo "── Luật iOS-portable: không dart:io / Platform. / DateTime.now() trong lib/features/ ──"
# loại trừ comment; bắt import và cách dùng thật
if grep -rnE "import 'dart:io'|import \"dart:io\"" lib/features/ 2>/dev/null; then
  viol "lib/features/ import dart:io — phải qua interface ở core/ hoặc data/services/"; fi
if grep -rnE '\bPlatform\.(is|environment|operating)' lib/features/ 2>/dev/null | grep -v '// *ignore'; then
  viol "lib/features/ dùng Platform. — dùng defaultTargetPlatform hoặc interface"; fi
if grep -rnE '\bDateTime\.now\(\)' lib/features/ lib/core/ lib/data/ 2>/dev/null | grep -vE '^\s*\S+:\s*//' | grep -v '// *ignore'; then
  viol "dùng DateTime.now() — phải qua Clock được inject (package:clock)"; fi

echo "── Luật migration material_ui: lib/theme/tokens/ không import material.dart ──"
if grep -rnE "import 'package:flutter/material.dart'|import \"package:flutter/material.dart\"" lib/theme/tokens/ 2>/dev/null; then
  viol "lib/theme/tokens/ import material.dart — chỉ được dùng dart:ui / painting.dart"; fi

echo "── Luật không analytics gọi về nhà ──"
if grep -rnE 'firebase_analytics|google_analytics|facebook|mixpanel|amplitude|sentry' lib/ pubspec.yaml 2>/dev/null | grep -v '//'; then
  viol "có SDK analytics/crash-report gọi về nhà"; fi

if [ $fail -eq 0 ]; then echo "✅ mọi luật kiến trúc PASS"; else echo; echo "🔴 CÓ VI PHẠM — sửa trước khi commit"; fi
exit $fail
