import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Chỉ lưu TÊN FILE, không bao giờ lưu đường dẫn tuyệt đối. Thư mục gốc của
/// app (`getApplicationDocumentsDirectory()`) có thể đổi giữa các lần cài —
/// đường dẫn tuyệt đối lưu từ lần chạy trước có thể trỏ vào chỗ không còn
/// tồn tại. Resolve lại thư mục gốc mỗi lần khởi động thay vì tin vào cache.
class PathService {
  const PathService();

  Future<String> resolveAppFilePath(String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, fileName);
  }

  Future<String> resolveBackupFilePath(String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    final backupDir = p.join(dir.path, 'backups');
    return p.join(backupDir, fileName);
  }
}
