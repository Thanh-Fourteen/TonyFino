package dev.tony.tonyfino

import android.content.ContentResolver
import android.content.Intent
import android.content.Context
import android.net.Uri
import android.provider.DocumentsContract
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Ghi/kiểm tra file trong một cây thư mục SAF đã được cấp quyền lifetime
 * (xem AndroidSafDestination — H6). `dart:io File` không hiểu URI
 * `content://`, nên việc ghi file mới (hoặc ghi đè file backup cũ, tránh
 * chồng chất "backup (1).json") phải đi qua DocumentsContract ở đây.
 */
object SafBackupChannel {
    private const val CHANNEL = "dev.tony.tonyfino/saf"

    fun register(context: Context, messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            val resolver = context.contentResolver
            try {
                when (call.method) {
                    "writeFile" -> {
                        val treeUri = Uri.parse(call.argument<String>("treeUri"))
                        val fileName = call.argument<String>("fileName")!!
                        val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
                        val bytes = call.argument<ByteArray>("bytes")!!
                        result.success(writeFile(resolver, treeUri, fileName, mimeType, bytes).toString())
                    }
                    /**
                     * Tự GIỮ quyền lâu dài cho cây thư mục vừa chọn.
                     *
                     * 🚨 KHÔNG phó thác việc này cho gói chọn file.
                     * `android_file_picker` 1.0.1 CÓ gọi
                     * `takePersistableUriPermission`, nhưng trên máy thật
                     * quyền vẫn không nằm trong `persistedUriPermissions`
                     * (kiểm chứng: máy không hề có `/data/system/urigrants.xml`).
                     * Hậu quả: `isGrantValid` luôn false → health-check báo
                     * hỏng vĩnh viễn → banner đỏ "Sao lưu tự động đang hỏng"
                     * dù vừa sao lưu thành công, và sau khi khởi động lại
                     * máy thì grant chết thật.
                     *
                     * Gọi lại nhiều lần vô hại (idempotent).
                     */
                    "takePersistable" -> {
                        val treeUri = Uri.parse(call.argument<String>("treeUri"))
                        val flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or
                            Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                        try {
                            resolver.takePersistableUriPermission(treeUri, flags)
                            result.success(true)
                        } catch (e: SecurityException) {
                            // Grant đã hết hiệu lực trước khi kịp giữ — báo
                            // false để tầng Dart nói cho người dùng chọn lại,
                            // đừng nuốt lặng rồi để họ tưởng đã xong.
                            result.success(false)
                        }
                    }
                    "isGrantValid" -> {
                        val treeUri = call.argument<String>("treeUri")
                        val valid = resolver.persistedUriPermissions.any {
                            it.uri.toString() == treeUri && it.isReadPermission && it.isWritePermission
                        }
                        result.success(valid)
                    }
                    "readFile" -> {
                        val treeUri = Uri.parse(call.argument<String>("treeUri"))
                        val fileName = call.argument<String>("fileName")!!
                        result.success(readFile(resolver, treeUri, fileName))
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("saf_error", e.message, null)
            }
        }
    }

    private fun writeFile(
        resolver: ContentResolver,
        treeUri: Uri,
        fileName: String,
        mimeType: String,
        bytes: ByteArray,
    ): Uri {
        val treeDocId = DocumentsContract.getTreeDocumentId(treeUri)
        val treeDocUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, treeDocId)
        val target = findChild(resolver, treeUri, treeDocId, fileName)
            ?: DocumentsContract.createDocument(resolver, treeDocUri, mimeType, fileName)!!
        resolver.openOutputStream(target, "wt")!!.use { it.write(bytes) }
        return target
    }

    /**
     * Đọc lại một file đã ghi trước đó — dùng cho health-check (H6): ghi một
     * file thăm dò nhỏ rồi đọc lại NGAY để xác nhận cây thư mục còn ghi/đọc
     * được thật, không chỉ dựa vào `isGrantValid` (grant có thể còn hiệu lực
     * về mặt quyền URI persisted nhưng thư mục đích đã bị người dùng xoá tay
     * trong Files app — hai việc khác nhau).
     * Trả về `null` (không ném lỗi) nếu file không tồn tại — health-check
     * phía Dart coi `null` là "hỏng", không phải trường hợp đặc biệt.
     */
    private fun readFile(resolver: ContentResolver, treeUri: Uri, fileName: String): ByteArray? {
        val treeDocId = DocumentsContract.getTreeDocumentId(treeUri)
        val target = findChild(resolver, treeUri, treeDocId, fileName) ?: return null
        return resolver.openInputStream(target)?.use { it.readBytes() }
    }

    /** Tìm document con theo tên hiển thị, để ghi đè thay vì tạo file trùng tên mới. */
    private fun findChild(resolver: ContentResolver, treeUri: Uri, treeDocId: String, fileName: String): Uri? {
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, treeDocId)
        resolver.query(
            childrenUri,
            arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID, DocumentsContract.Document.COLUMN_DISPLAY_NAME),
            null, null, null,
        )?.use { cursor ->
            // Khớp CHÍNH XÁC trước; nếu không có thì chấp nhận tên bị
            // provider gắn thêm đúng MỘT đuôi ("probe.txt" cho "probe").
            // SAF được phép đổi tên hiển thị khi tạo document, và khi nó đổi
            // thì mọi lần đọc lại theo tên gốc đều trượt — im lặng, không
            // ngoại lệ nào. Đây là gốc của health-check báo hỏng vĩnh viễn.
            var fallback: Uri? = null
            while (cursor.moveToNext()) {
                val displayName = cursor.getString(1)
                if (displayName == fileName) {
                    return DocumentsContract.buildDocumentUriUsingTree(treeUri, cursor.getString(0))
                }
                if (fallback == null &&
                    displayName != null &&
                    displayName.startsWith("$fileName.") &&
                    !displayName.removePrefix("$fileName.").contains('.')
                ) {
                    fallback = DocumentsContract.buildDocumentUriUsingTree(treeUri, cursor.getString(0))
                }
            }
            if (fallback != null) return fallback
        }
        return null
    }
}
