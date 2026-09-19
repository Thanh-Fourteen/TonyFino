/// Quan hệ giữa MỘT danh mục và MỘT hũ, nhìn từ bảng "Danh mục trong hũ".
///
/// Luật nền (khớp truy vấn `COALESCE(c.jar_id, parent.jar_id)` ở
/// `JarRepository.watchProgress`): danh mục con xếp riêng vào hũ nào thì
/// theo hũ đó; chưa xếp (`jarId == null`) thì THỪA HƯỞNG hũ của cha.
///
/// Vì sao cần thừa hưởng lẫn xếp riêng: cùng một "Ăn uống" nhưng "Ăn trưa
/// thiết yếu" thuộc hũ Thiết yếu còn "Giao lưu" thuộc hũ Hưởng thụ — Tony
/// cần tách từng con. Nhưng danh mục con MỚI tạo sau này mà không thuộc hũ
/// nào thì chi của nó rơi ra ngoài mọi hũ, nên mặc định vẫn theo cha.
enum JarMembership {
  /// Được xếp THẲNG vào hũ này.
  direct,

  /// Danh mục con đang theo hũ này qua danh mục cha — không tự gỡ ra được
  /// (gỡ ra thì nó lại thừa hưởng đúng hũ này); muốn tách thì xếp nó vào
  /// hũ khác.
  inherited,

  /// Đang thuộc một hũ KHÁC (trực tiếp hoặc qua cha).
  elsewhere,

  /// Không thuộc hũ nào.
  none,
}

/// Hũ hiệu lực của một danh mục — cùng công thức với truy vấn SQL.
int? effectiveJarId({required int? ownJarId, required int? parentJarId}) =>
    ownJarId ?? parentJarId;

JarMembership jarMembership({
  required int jarId,
  required int? ownJarId,
  required int? parentJarId,
}) {
  // Con mang `jarId` trùng hũ của cha là dư thừa — nó VẪN nằm trong hũ này
  // dù có gỡ dòng của riêng nó hay không, nên với người dùng nó là "theo
  // cha", không phải "xếp thẳng".
  if (parentJarId == jarId && (ownJarId == null || ownJarId == jarId)) {
    return JarMembership.inherited;
  }
  if (ownJarId == jarId) return JarMembership.direct;
  final effective = effectiveJarId(
    ownJarId: ownJarId,
    parentJarId: parentJarId,
  );
  return effective == null ? JarMembership.none : JarMembership.elsewhere;
}

/// `jarId` MỚI cần ghi cho danh mục khi Tony tick/bỏ tick nó trong bảng của
/// hũ [jarId].
///
/// Tick một danh mục con mà cha đã ở đúng hũ này → ghi `null` (thừa hưởng)
/// thay vì chép lại id: để sau này Tony dời cả cha sang hũ khác thì con đi
/// theo, không bị bỏ lại một mình ở hũ cũ.
int? jarIdAfterToggle({
  required int jarId,
  required bool checked,
  required int? ownJarId,
  required int? parentJarId,
}) {
  if (checked) return parentJarId == jarId ? null : jarId;
  // Bỏ tick chỉ gỡ đúng dây nối RIÊNG tới hũ này; dây nối tới hũ khác (nếu
  // có) không liên quan gì tới bảng đang mở.
  return ownJarId == jarId ? null : ownJarId;
}

/// Mọi danh mục (kể cả đã lưu trữ — lịch sử vẫn phải lọc đúng) có hũ HIỆU
/// LỰC là [jarId]. Đúng tập mà `JarRepository.watchProgress` cộng chi vào
/// hũ đó, nên lọc danh sách giao dịch theo tập này ra đúng những dòng làm
/// nên con số "đã tiêu" của hũ.
Set<int> categoryIdsInJar(
  Iterable<({int id, int? parentCategoryId, int? jarId})> categories,
  int jarId,
) {
  final jarOf = {for (final c in categories) c.id: c.jarId};
  return {
    for (final c in categories)
      if (effectiveJarId(
            ownJarId: c.jarId,
            parentJarId: c.parentCategoryId == null
                ? null
                : jarOf[c.parentCategoryId],
          ) ==
          jarId)
        c.id,
  };
}
