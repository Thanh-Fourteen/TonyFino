/// Kết quả của một thao tác có thể thất bại. Không exception cho luồng chính —
/// mọi write của repository trả `Result<T, AppError>` (D7): zero fire-and-forget,
/// lỗi luôn có chỗ để hiện blocking dialog và ghi vào bảng `app_events`.
sealed class Result<T, E> {
  const Result();

  const factory Result.ok(T value) = Ok<T, E>;
  const factory Result.err(E error) = Err<T, E>;

  bool get isOk => this is Ok<T, E>;
  bool get isErr => this is Err<T, E>;

  R when<R>({
    required R Function(T value) ok,
    required R Function(E error) err,
  }) {
    final self = this;
    return switch (self) {
      Ok<T, E>() => ok(self.value),
      Err<T, E>() => err(self.error),
    };
  }

  /// Giá trị nếu ok, `null` nếu err.
  T? get valueOrNull => switch (this) {
    Ok<T, E>(:final value) => value,
    Err<T, E>() => null,
  };
}

final class Ok<T, E> extends Result<T, E> {
  const Ok(this.value);
  final T value;

  @override
  bool operator ==(Object other) => other is Ok<T, E> && other.value == value;

  @override
  int get hashCode => Object.hash(Ok, value);

  @override
  String toString() => 'Ok($value)';
}

final class Err<T, E> extends Result<T, E> {
  const Err(this.error);
  final E error;

  @override
  bool operator ==(Object other) => other is Err<T, E> && other.error == error;

  @override
  int get hashCode => Object.hash(Err, error);

  @override
  String toString() => 'Err($error)';
}

/// Lỗi ứng dụng cấp người dùng — thứ hiện lên blocking dialog và được ghi vào
/// bảng `app_events` (D7). Không phải exception kỹ thuật; là một thông điệp
/// đã được diễn giải cho người dùng, kèm nguyên nhân gốc để debug sau.
class AppError {
  const AppError(this.message, {this.cause});

  /// Thông điệp tiếng Việt, hiện thẳng cho Tony trong blocking dialog.
  final String message;

  /// Lỗi gốc (exception/stack), chỉ dùng để log vào `app_events`, không hiện UI.
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'AppError($message)'
      : 'AppError($message, cause: $cause)';

  @override
  bool operator ==(Object other) =>
      other is AppError && other.message == message;

  @override
  int get hashCode => message.hashCode;
}
