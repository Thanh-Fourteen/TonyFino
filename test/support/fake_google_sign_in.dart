import 'package:http/http.dart' as http;
import 'package:tonyfino/core/result/result.dart';
import 'package:tonyfino/data/services/google/google_account.dart';
import 'package:tonyfino/data/services/google/google_sign_in_service.dart';

/// [GoogleSignInService] giả — trả lần lượt các kết quả xếp sẵn trong
/// [signInResults] cho mỗi lần `signIn()`.
class FakeGoogleSignInService implements GoogleSignInService {
  FakeGoogleSignInService({List<Result<GoogleAccount, AppError>>? results})
    : signInResults = results ?? [];

  final List<Result<GoogleAccount, AppError>> signInResults;
  int signInCalls = 0;
  int signOutCalls = 0;

  @override
  Future<Result<GoogleAccount, AppError>> signIn() async {
    signInCalls++;
    return signInResults.removeAt(0);
  }

  @override
  Future<void> signOut() async => signOutCalls++;

  @override
  Future<Result<http.Client, AppError>> authorizedDriveClient() async =>
      const Result.err(AppError('không dùng trong test'));
}
