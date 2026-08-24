# drift / sqlite3mc KHÔNG cần rule R8 nào — cả hai đều 100% Dart thuần (không
# file .java/.kt/.gradle nào trong package), native lib load qua cơ chế Dart
# native-assets/FFI (@Native bindings), KHÔNG qua System.loadLibrary/JNI của
# Java — R8 chỉ xử lý bytecode JVM nên không có bề mặt nào để cắt nhầm ở đây.
# (Nghiên cứu trước khi code, Phase 24 — đọc trực tiếp source 3 package.)
# 2 rule cũ ở đây trước đó ("org.sqlite.**"/"com.tony.**") đã bị XOÁ vì đều là
# no-op: "org.sqlite.**" là rule của package JNI cũ (requery/sqlite-android)
# không liên quan gì tới drift/sqlite3.dart; "com.tony.**" gõ sai namespace
# thật của app (là "dev.tony.tonyfino", không phải "com.tony.*"), và code
# của chính app cũng không cần keep rule vì không phải bề mặt API thư viện.
# Xem docs/decisions.md § Phase 24.

# flutter_secure_storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# google_mlkit_text_recognition (Phase 18) — plugin's Kotlin code tham chiếu
# TextRecognizerOptions của CẢ 5 script (Latin/Chinese/Devanagari/Japanese/
# Korean) trong một switch, dù app CHỈ khai gradle dependency cho Latin
# (đủ cho tiếng Việt có dấu, xem docs/decisions.md § Phase 18 — không cần 4
# gói ngôn ngữ kia). R8 release build lỗi "Missing class" cho 4 script không
# khai — đây là rule Google TỰ SINH RA và đề xuất trong missing_rules.txt
# lúc build, không phải đoán.
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions

# 🚨 GIỮ LỚP ML Kit — không chỉ `-dontwarn`.
#
# Bắt được bằng cách quét chính hoá đơn Emart THẬT của Tony trên bản
# RELEASE: ML Kit ném
#   NullPointerException: Attempt to invoke virtual method
#   'java.lang.Class java.lang.Object.getClass()' on a null object reference
# ở `m4.na.<init>` — tức là bên trong code ĐÃ BỊ R8 đổi tên. Người dùng
# không thấy lỗi gì: form "Thêm giao dịch" mở ra TRỐNG, y như OCR không đọc
# được chữ nào. Chạy đúng luồng đó trên bản DEBUG (không R8) thì ra ngay
# "414.000đ" + "emart" — thí nghiệm đối chứng xác định R8 là thủ phạm.
#
# Vì sao `-dontwarn` ở trên không đủ: nó chỉ tắt CẢNH BÁO lúc build cho 4
# script không dùng, không giữ lại lớp nào lúc chạy. ML Kit tra lớp bằng
# phản chiếu (đăng ký model, tên component cho telemetry) nên R8 không thấy
# đường tham chiếu và cắt/đổi tên — mọi thứ vẫn biên dịch, chỉ chết lúc chạy.
#
# Đây là bài học Phase 24 ("bug R8 chỉ xuất hiện ở release") lặp lại đúng
# một lần nữa, ở một thư viện chưa ai chạy thử trên bản release.
-keep class com.google.mlkit.** { *; }
-keep interface com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }
-keep class com.google.android.odml.** { *; }
-keepclassmembers class com.google.mlkit.** {
    <init>(...);
    *;
}
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.odml.**
