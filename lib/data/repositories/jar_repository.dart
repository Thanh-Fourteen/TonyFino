import 'package:drift/drift.dart';

import '../../core/money/money.dart';
import '../../core/result/result.dart';
import '../db/database.dart';
import 'effective_category_amounts.dart';

/// Bộ 6 hũ mặc định — JARS của T. Harv Eker ("Secrets of the Millionaire
/// Mind"), tỉ lệ 55/10/10/10/10/5 cộng đúng 100%.
///
/// KHÔNG tự tạo lúc migration: bật sẵn một phương pháp tài chính lên sổ của
/// người khác là quyết định thay họ. Tony bấm "Dùng mẫu 6 hũ" thì mới có.
const kDefaultJarSeeds =
    <
      ({String name, int percent, int colorId, String iconCode, bool carryOver})
    >[
      (
        name: 'Thiết yếu',
        percent: 55,
        colorId: 0,
        iconCode: 'home',
        carryOver: false,
      ),
      (
        name: 'Tiết kiệm dài hạn',
        percent: 10,
        colorId: 10,
        iconCode: 'savings',
        // Quỹ chìm: dư kỳ này phải cộng dồn, không thì "tiết kiệm dài hạn"
        // chẳng dài hạn ở chỗ nào.
        carryOver: true,
      ),
      (
        name: 'Giáo dục',
        percent: 10,
        colorId: 7,
        iconCode: 'school',
        carryOver: true,
      ),
      (
        name: 'Hưởng thụ',
        percent: 10,
        colorId: 3,
        iconCode: 'theater_comedy',
        carryOver: false,
      ),
      (
        name: 'Tự do tài chính',
        percent: 10,
        colorId: 4,
        iconCode: 'payments',
        carryOver: true,
      ),
      (
        name: 'Cho đi',
        percent: 5,
        colorId: 9,
        iconCode: 'handshake',
        carryOver: false,
      ),
    ];

/// Hai loại hũ — đo NGƯỢC CHIỀU nhau (xem `Jars.kind`).
enum JarKind {
  /// Hũ TIÊU: gom một số danh mục chi; đo tiền RA, vượt hạn mức là xấu.
  spend('spend'),

  /// Hũ TIẾT KIỆM: gắn một quỹ; đo tiền GỬI VÀO quỹ trong kỳ, gửi vượt
  /// mức là tốt. Không có danh mục nào — tiền vào quỹ không phải chi tiêu.
  saving('saving');

  const JarKind(this.dbValue);
  final String dbValue;

  /// Giá trị lạ (sổ ghi từ bản tương lai) rơi về hũ tiêu — loại mặc định,
  /// đúng với mọi hũ có trước khi có khái niệm này.
  static JarKind parse(String raw) =>
      raw == saving.dbValue ? JarKind.saving : JarKind.spend;
}

/// Chiều của một hũ QUỸ (v17) — Tony: *"hũ liên quan tới quỹ có 2 dạng:
/// nạp tiền vào quỹ, sài tiền từ quỹ"*.
enum JarGoalFlow {
  /// Đo tiền NẠP VÀO quỹ trong kỳ. Mốc: phần trăm thu nhập của kỳ (hoặc
  /// đích của các quỹ khi hũ lấy 0%). Gửi nhiều là tốt.
  deposit('in'),

  /// Đo tiền RÚT TỪ quỹ ra tiêu trong kỳ. Mốc tự nhiên là tiền CÒN trong
  /// quỹ — "quỹ khám bệnh còn bao nhiêu" mới là câu hỏi, không phải "tháng
  /// này phải rút bao nhiêu phần trăm thu nhập". Đặt phần trăm > 0 thì đó
  /// là TRẦN rút của kỳ.
  spend('out');

  const JarGoalFlow(this.dbValue);
  final String dbValue;

  static JarGoalFlow parse(String raw) =>
      raw == spend.dbValue ? JarGoalFlow.spend : JarGoalFlow.deposit;
}

extension JarGoalFlowX on Jar {
  JarGoalFlow get flow => JarGoalFlow.parse(goalFlow);
}

/// Một dây nối hũ ↔ quỹ đang được soạn ở UI (chưa ghi xuống DB).
class JarGoalLink {
  const JarGoalLink({required this.goalId, this.percent = 100});

  final int goalId;

  /// Phần của quỹ thuộc về hũ, 1–100. Mặc định 100 = cả quỹ.
  final int percent;

  JarGoalLink copyWith({int? percent}) =>
      JarGoalLink(goalId: goalId, percent: percent ?? this.percent);
}

extension JarKindX on Jar {
  JarKind get jarKind => JarKind.parse(kind);
}

/// Vai trò của một hũ đối với một quỹ — "hũ nào, chiều nào".
class JarGoalRole {
  const JarGoalRole({
    required this.jarId,
    required this.jarName,
    required this.flow,
  });

  final int jarId;
  final String jarName;
  final JarGoalFlow flow;

  String get flowLabel =>
      flow == JarGoalFlow.deposit ? 'nạp vào' : 'tiêu từ';
}

/// Một hũ kèm số liệu của kỳ đang xem.
class JarProgress {
  const JarProgress({
    required this.jar,
    required this.allotted,
    required this.used,
    required this.categoryCount,
    this.goals = const [],
  });

  final Jar jar;

  JarKind get kind => jar.jarKind;

  /// Hạn mức kỳ này = `percent%` × TỔNG THU của kỳ. Không phải số cố định —
  /// đó chính là điểm khác giữa hũ và ngân sách.
  final Money allotted;

  /// Số DƯƠNG, LUÔN theo đúng CHIỀU của hũ, và luôn là số TỔNG (gross),
  /// không bao giờ là số ròng.
  ///
  /// - Hũ tiêu: đã CHI trong các danh mục của hũ.
  /// - Hũ quỹ chiều "nạp vào": TỔNG tiền đã NẠP vào các quỹ của hũ trong kỳ.
  /// - Hũ quỹ chiều "tiêu từ": TỔNG tiền đã RÚT khỏi các quỹ của hũ trong kỳ.
  ///
  /// 🚨 Vì sao GROSS chứ không phải RÒNG (Tony 2026-09-22, lần 2): cùng MỘT
  /// quỹ được phép nằm trong CẢ HAI hũ ngược chiều — "Tiết kiệm" lo nạp vào,
  /// "Phát sinh trong quỹ dự phòng" lo rút ra. Nếu hũ nạp đo phần ròng thì
  /// mỗi lần hũ kia làm đúng việc của nó (rút tiền đi khám bệnh), con số của
  /// hũ nạp tụt xuống — hai hũ giẫm chân nhau, đúng cảnh "trừ tiền và cộng
  /// tiền lộn xộn lên". Mỗi hũ chỉ đếm dòng tiền THEO CHIỀU CỦA MÌNH thì
  /// chúng độc lập hoàn toàn.
  final Money used;

  final int categoryCount;

  /// Các quỹ hũ tiết kiệm này gom (v15) — rỗng với hũ tiêu, hoặc hũ tiết
  /// kiệm chưa gắn quỹ nào.
  final List<JarGoalProgress> goals;

  String? get goalName => goals.length == 1 ? goals.single.goal.name : null;

  JarGoalFlow get flow => jar.flow;

  /// Hũ QUỸ chiều "tiêu từ quỹ": [used] là tiền đã rút ra tiêu, và mốc so
  /// sánh là tiền CÒN trong quỹ chứ không phải phần trăm thu nhập (trừ khi
  /// Tony đặt một trần > 0).
  bool get spendsFromGoals =>
      kind == JarKind.saving && flow == JarGoalFlow.spend;

  /// Tổng tiền ĐANG CÓ trong các quỹ của hũ (mọi thời gian, đã nhân tỉ lệ
  /// từng quỹ) — khác [used] là dòng tiền TRONG KỲ.
  ///
  /// 🚨 Đây là số của QUỸ, không phải của hũ, nên nó KHÔNG BAO GIỜ được làm
  /// con số chính của thẻ hũ: một quỹ nằm trong hai hũ thì cả hai hũ cùng
  /// khoe một túi tiền, và hũ "nạp vào" sẽ tụt xuống mỗi lần hũ "tiêu từ"
  /// rút tiền — dù hũ nạp đã làm xong việc của nó. Chỉ hiện làm BỐI CẢNH.
  Money get savedTotal => Money.vnd(goals.fold(0, (s, g) => s + g.savedMinor));

  /// Tổng đích của các quỹ (đã nhân tỉ lệ) — mốc cho thanh tiến độ khi hũ
  /// không lấy phần trăm thu nhập nào trong kỳ. 0 = không quỹ nào đặt đích.
  Money get goalTarget => Money.vnd(goals.fold(0, (s, g) => s + g.targetMinor));

  Money get remaining => allotted - used;

  /// Chỉ hũ TIÊU mới "vượt" theo nghĩa xấu. Hũ tiết kiệm gửi quá mức là
  /// đạt mục tiêu, không phải lỗi — đừng tô đỏ nó.
  bool get isOverspent =>
      (kind == JarKind.spend ||
          // Hũ "tiêu từ quỹ" CÓ đặt trần thì vượt trần cũng là vượt.
          (spendsFromGoals && allotted.minorUnits > 0)) &&
      used.minorUnits > allotted.minorUnits;

  /// Hũ tiết kiệm đã gửi đủ phần của kỳ.
  bool get isSavingReached =>
      kind == JarKind.saving &&
      flow == JarGoalFlow.deposit &&
      allotted.minorUnits > 0 &&
      used.minorUnits >= allotted.minorUnits;

  /// Hũ quỹ chiều "nạp vào quỹ" — nhiệm vụ: BỎ TIỀN VÀO các quỹ của hũ.
  bool get depositsToGoals =>
      kind == JarKind.saving && flow == JarGoalFlow.deposit;

  /// Hũ quỹ chiều "nạp vào" mà KHÔNG lấy phần trăm thu nhập nào (0%): kỳ
  /// này không có mốc "phải nạp bao nhiêu", nên thanh chuyển sang đo tiền
  /// đã để dành được trong các quỹ so với tổng đích của chúng.
  ///
  /// Hũ CÓ đặt phần trăm thì mốc của kỳ mới là thứ đáng đo — nhiệm vụ của
  /// nó là "kỳ này nạp đủ X chưa", không phải "bao giờ thì đủ đích".
  bool get tracksGoalTotal =>
      depositsToGoals &&
      allotted.minorUnits == 0 &&
      goals.isNotEmpty &&
      goalTarget.minorUnits > 0;

  /// Tiền quỹ TĂNG hay GIẢM ròng trong kỳ (nạp − rút), CÓ DẤU.
  ///
  /// Đây là số của QUỸ, chỉ dùng làm bối cảnh — [used] mới là số đo nhiệm
  /// vụ của hũ. Chỗ nào hiện nó phải đọc DẤU rồi đổi CHỮ, không in số âm.
  Money get periodNet =>
      Money.vnd(goals.fold(0, (s, g) => s + g.netMinor));

  /// Hũ "tiêu từ quỹ" KHÔNG đặt trần: thanh đo phần quỹ đã tiêu trong kỳ so
  /// với chính quỹ đó lúc đầu kỳ (= còn lại + đã tiêu).
  bool get tracksGoalDrawdown =>
      spendsFromGoals && allotted.minorUnits == 0 && goals.isNotEmpty;

  /// Tiền còn trong các quỹ sau khi đã tiêu — chính là [savedTotal], đặt
  /// tên riêng cho chỗ gọi đọc ra nghĩa.
  Money get goalBalance => savedTotal;

  double get ratio {
    if (tracksGoalTotal) {
      final target = goalTarget.minorUnits;
      return target == 0 ? 0 : savedTotal.minorUnits / target;
    }
    if (tracksGoalDrawdown) {
      final atStart = savedTotal.minorUnits + used.minorUnits;
      return atStart <= 0 ? 0 : used.minorUnits / atStart;
    }
    if (allotted.minorUnits == 0) return 0;
    // [used] luôn ≥ 0 (gross theo chiều của hũ) nên thanh không bao giờ
    // chạy ngược — giữ `clamp` phòng dữ liệu lạ.
    final r = used.minorUnits / allotted.minorUnits;
    return r < 0 ? 0 : r;
  }
}

/// Một quỹ trong một hũ tiết kiệm, kèm số liệu đã NHÂN tỉ lệ của dây nối.
class JarGoalProgress {
  const JarGoalProgress({
    required this.goal,
    required this.percent,
    required this.inMinor,
    required this.outMinor,
    required this.savedMinor,
    required this.fullSavedMinor,
  });

  final SavingsGoal goal;

  /// Phần của quỹ này thuộc hũ, 0–100 (mặc định 100 = cả quỹ).
  final int percent;

  /// Tiền NẠP VÀO quỹ trong kỳ (số dương), đã nhân [percent].
  final int inMinor;

  /// Tiền RÚT RA khỏi quỹ trong kỳ (số dương), đã nhân [percent].
  final int outMinor;

  /// Tiền đã NẠP vào quỹ trong kỳ — TỔNG, không trừ phần rút ra.
  ///
  /// 🚨 Cả hai chiều đều dùng số TỔNG, đối xứng nhau. Quỹ khám bệnh tháng
  /// này nạp 1tr rồi lấy 300k đi khám: "tháng này nạp vào bao nhiêu" = 1tr,
  /// "tháng này tiêu từ quỹ bao nhiêu" = 300k. Không câu nào trả lời bằng
  /// 700k cả. Số ròng là câu trả lời cho một câu hỏi THỨ BA ("quỹ phình ra
  /// bao nhiêu") — đó là câu hỏi của QUỸ, xem [netMinor].
  int get depositedMinor => inMinor;

  /// Tiền đã rút ra tiêu trong kỳ — TỔNG, không trừ phần nạp vào.
  int get withdrawnMinor => outMinor;

  /// Quỹ TĂNG/GIẢM ròng trong kỳ = nạp − rút, CÓ DẤU. Số của QUỸ, không
  /// phải số đo nhiệm vụ của hũ nào.
  int get netMinor => inMinor - outMinor;

  /// Tiền đang có trong quỹ (mọi thời gian), đã nhân [percent].
  final int savedMinor;

  /// Tiền đang có trong quỹ, KHÔNG nhân tỉ lệ — dùng để cộng tổng theo QUỸ
  /// mà không đếm hai lần khi một quỹ nằm trong nhiều hũ.
  final int fullSavedMinor;

  /// Đích của quỹ, đã nhân [percent]. 0 = quỹ không đặt đích.
  int get targetMinor => goal.targetAmountMinor * percent ~/ 100;
}

/// Bộ hũ của một kỳ + nguồn chia của nó.
///
/// [income] đi kèm danh sách chứ không để màn tự lấy từ chỗ khác: màn Hũ
/// phải cho thấy "10% của CÁI GÌ" — con số đó mà không hiện ra thì không ai
/// kiểm được hạn mức từng hũ có đúng không.
class JarsOverview {
  const JarsOverview({required this.income, required this.jars});

  static const empty = JarsOverview(income: Money.vnd(0), jars: []);

  /// Tổng THU của kỳ — cùng định nghĩa với ô "Thu" ở Trang chủ.
  final Money income;
  final List<JarProgress> jars;

  bool get isEmpty => jars.isEmpty;

  int get totalPercent => jars.fold(0, (s, p) => s + p.jar.percent);

  Money get totalAllotted =>
      Money.vnd(jars.fold(0, (s, p) => s + p.allotted.minorUnits));

  /// Đã TIÊU trong kỳ — CHỈ hũ tiêu.
  ///
  /// 🚨 Không gộp tiền gửi quỹ vào đây nữa. Một ô "Đã dùng" cộng chung tiền
  /// tiêu với tiền để dành khiến tiết kiệm đọc ra như mất tiền (Tony
  /// 2026-09-22) — hai thứ ngược nghĩa nhau thì phải là hai con số.
  Money get totalSpent => Money.vnd(
    jars.fold(0, (s, p) => p.kind == JarKind.spend ? s + p.used.minorUnits : s),
  );

  /// Đã NẠP VÀO QUỸ trong kỳ — tổng tiền bỏ vào quỹ của các hũ chiều "nạp
  /// vào quỹ". Số TỔNG, luôn ≥ 0.
  Money get totalSaved => Money.vnd(
    jars.fold(0, (s, p) => p.depositsToGoals ? s + p.used.minorUnits : s),
  );

  /// Đã RÚT TỪ QUỸ ra tiêu trong kỳ (hũ chiều "tiêu từ quỹ").
  ///
  /// Đứng RIÊNG, không trừ vào [totalRemaining]: tiền này đến từ quỹ đã
  /// dành dụm những kỳ TRƯỚC, không phải từ thu nhập kỳ này — trừ nó vào
  /// phần còn lại của kỳ là tính một đồng hai lần.
  Money get totalDrawnFromGoals => Money.vnd(
    jars.fold(0, (s, p) => p.spendsFromGoals ? s + p.used.minorUnits : s),
  );

  /// Tổng phần CÒN LẠI của TỪNG hũ, cộng lại — cố ý KHÔNG phải
  /// `totalAllotted − totalSpent − totalSaved`.
  ///
  /// 🚨 Cộng theo từng hũ rồi mới tổng, và kẹp ở 0 cho mỗi hũ. Hai lý do,
  /// cả hai đều bắt được khi bấm thật trên máy:
  ///
  /// 1. Nguyên tắc cốt lõi của phương pháp phong bì: một hũ tiêu quá phần
  ///    của nó KHÔNG được âm thầm ăn vào phần còn lại của hũ khác.
  /// 2. Trừ thẳng [totalSaved] làm cả bộ hũ báo "Vượt" chỉ vì Tony chuyển
  ///    một khoản tiết kiệm CŨ vào quỹ: thu nhập kỳ này 1tr mà nạp 7tr vào
  ///    quỹ (tiền của những kỳ trước đang nằm trong ví) ra "Vượt
  ///    6.050.000". Nạp vượt mức là chuyện TỐT, không phải lỗi.
  Money get totalRemaining => Money.vnd(
    jars.fold(0, (s, p) {
      final left = p.allotted.minorUnits - p.used.minorUnits;
      return left > 0 ? s + left : s;
    }),
  );

  /// Tổng phần VƯỢT của những hũ mà vượt là XẤU — hũ tiêu, và hũ "tiêu từ
  /// quỹ" có đặt trần. Hũ nạp quỹ vượt mức là đạt mục tiêu, không vào đây.
  Money get totalOverspent => Money.vnd(
    jars.fold(
      0,
      (s, p) => p.isOverspent
          ? s + (p.used.minorUnits - p.allotted.minorUnits)
          : s,
    ),
  );

  /// Tổng tiền ĐANG CÓ trong mọi quỹ mà các hũ đang theo dõi (mọi thời
  /// gian) — khác [totalSaved] là phần bỏ vào TRONG KỲ.
  ///
  /// 🚨 Gom theo QUỸ, mỗi quỹ đúng MỘT lần, và lấy số dư ĐẦY ĐỦ. Một quỹ
  /// nằm trong cả hũ "Tiết kiệm" lẫn hũ "Phát sinh" là chuyện bình thường
  /// (hai nhiệm vụ ngược chiều trên cùng một túi tiền) — cộng `savedTotal`
  /// của từng hũ lại là đếm đúng túi tiền đó hai lần.
  Money get totalInGoals {
    final byGoal = <int, int>{};
    for (final jar in jars) {
      for (final g in jar.goals) {
        byGoal[g.goal.id] = g.fullSavedMinor;
      }
    }
    return Money.vnd(byGoal.values.fold(0, (s, v) => s + v));
  }

  /// Số QUỸ khác nhau mà các hũ đang theo dõi — đếm mỗi quỹ một lần.
  int get distinctGoalCount =>
      {for (final j in jars) for (final g in j.goals) g.goal.id}.length;
}

class JarRepository {
  JarRepository(this._db);
  final AppDatabase _db;

  Stream<List<Jar>> watchActive(int walletId) => _activeQuery(walletId).watch();

  SimpleSelectStatement<$JarsTable, Jar> _activeQuery(int walletId) {
    return _db.select(_db.jars)
      ..where((j) => j.walletId.equals(walletId) & j.isArchived.equals(false))
      ..orderBy([
        (j) => OrderingTerm.asc(j.sortOrder),
        (j) => OrderingTerm.asc(j.id),
      ]);
  }

  /// Hũ + số liệu kỳ `[start, end)`.
  ///
  /// Thu nhập của kỳ tính MỘT LẦN cho cả bộ hũ (mọi hũ chia từ cùng một
  /// nguồn), rồi mỗi hũ lấy `percent%` của nó. Chi tính qua
  /// [effectiveCategoryAmounts] để giao dịch TÁCH DÒNG (Phase 14) rơi đúng
  /// vào danh mục của từng dòng con chứ không dồn hết vào danh mục cha.
  Stream<JarsOverview> watchProgress({
    required int walletId,
    required DateTime start,
    required DateTime end,
  }) {
    final eff = effectiveCategoryAmounts(_db);
    final effCategoryId = eff.ref(_db.transactions.categoryId);
    final effAmount = eff.ref(_db.transactions.amountMinor);
    final effOccurredAt = eff.ref(_db.transactions.occurredAt);
    final effIsTransfer = eff.ref(_db.transactions.isTransfer);
    final effWalletId = eff.ref(_db.transactions.walletId);
    final effGoalId = eff.ref(_db.transactions.goalId);

    final inWindow =
        effOccurredAt.isBiggerOrEqualValue(start) &
        effOccurredAt.isSmallerThanValue(end) &
        effIsTransfer.equals(false) &
        effWalletId.equals(walletId);

    // Tổng THU của kỳ — nguồn chia cho mọi hũ.
    //
    // 🚨 PHẢI loại dòng gắn quỹ (`goal_id`), y hệt ô "Thu" ở Trang chủ
    // (`ReportsRepository.watchPeriodSummary`). Trước đây chỗ này đếm mọi
    // dòng dương, nên RÚT tiền từ quỹ về ví bị coi là thu nhập: hạn mức mọi
    // hũ phình theo, và "10%" của hũ không còn là 10% của con số "Thu" Tony
    // nhìn thấy ngay trên cùng màn hình.
    final incomeExpr = effAmount.sum(
      filter: inWindow & effAmount.isBiggerThanValue(0) & effGoalId.isNull(),
    );
    final incomeQuery = eff.selectOnly()..addColumns([incomeExpr]);

    // Chi theo hũ. 🚨 Phần lớn giao dịch thật ghi vào danh mục CON ("Ăn
    // uống → Ăn trưa thiết yếu"). Hũ hiệu lực = `COALESCE(của chính nó, của
    // cha)`: danh mục con xếp riêng vào một hũ thì theo hũ đó (cùng một "Ăn
    // uống" có con ở hũ Thiết yếu, con ở hũ Hưởng thụ), chưa xếp thì thừa
    // hưởng hũ của cha.
    final c = _db.categories;
    final parent = _db.categories.createAlias('parent_category');
    final effectiveJarId = coalesce([c.jarId, parent.jarId]);

    // Dòng gắn quỹ KHÔNG phải chi tiêu — nó là tiền chuyển sang túi tiết
    // kiệm, và được tính ở hũ tiết kiệm bên dưới. Để nó lọt vào đây thì một
    // lần nạp quỹ (thường mang danh mục "Phát sinh") bị đếm HAI lần: vừa là
    // chi của hũ tiêu, vừa là tiền gửi của hũ tiết kiệm.
    final spentExpr = effAmount.sum(
      filter: inWindow & effAmount.isSmallerThanValue(0) & effGoalId.isNull(),
    );
    final spentQuery =
        eff.selectOnly().join([
            innerJoin(c, c.id.equalsExp(effCategoryId), useColumns: false),
            leftOuterJoin(
              parent,
              parent.id.equalsExp(c.parentCategoryId),
              useColumns: false,
            ),
          ])
          ..addColumns([effectiveJarId, spentExpr])
          ..where(effectiveJarId.isNotNull())
          ..groupBy([effectiveJarId]);

    // Gửi RÒNG vào từng quỹ trong kỳ: nạp là dòng ÂM gắn quỹ, rút là dòng
    // DƯƠNG — `-SUM` ra số tiền quỹ thực sự tăng thêm (cùng quy ước với
    // `SavingsGoalRepository`).
    // TÁCH hai chiều thay vì chỉ lấy số ròng: hũ "nạp vào quỹ" đọc phần
    // ròng, hũ "tiêu từ quỹ" (v17) đọc phần RÚT RA — số ròng một mình không
    // tách được hai câu hỏi đó.
    final inExpr = effAmount.sum(
      filter: inWindow & effAmount.isSmallerThanValue(0),
    );
    final outExpr = effAmount.sum(
      filter: inWindow & effAmount.isBiggerThanValue(0),
    );
    final savedQuery = eff.selectOnly()
      ..addColumns([effGoalId, inExpr, outExpr])
      ..where(effGoalId.isNotNull())
      ..groupBy([effGoalId]);

    // Tiền ĐANG CÓ trong từng quỹ — KHÔNG giới hạn kỳ (đó là điểm khác với
    // [savedQuery]). Dùng chung quy ước dấu với `SavingsGoalRepository`.
    final balanceExpr = effAmount.sum();
    final balanceQuery = eff.selectOnly()
      ..addColumns([effGoalId, balanceExpr])
      ..where(effGoalId.isNotNull())
      ..groupBy([effGoalId]);

    // Đếm mọi danh mục ĐƯỢC XẾP TƯỜNG MINH vào hũ, cả cha lẫn con — từ khi
    // danh mục con xếp riêng được, "3 danh mục" phải gồm cả con đã tách ra.
    // Con chỉ THỪA HƯỞNG hũ của cha thì không đếm thêm: đếm vậy ra những con
    // số vô nghĩa như "9 danh mục" cho hũ có đúng một danh mục cha.
    final countQuery = _db.selectOnly(c)
      ..addColumns([c.jarId, c.id.count()])
      ..where(c.jarId.isNotNull() & c.isArchived.equals(false))
      ..groupBy([c.jarId]);

    // 🚨 Nguồn phát PHẢI theo dõi MỌI bảng các truy vấn bên dưới đọc.
    //
    // Các truy vấn gộp trong `asyncMap` là đọc MỘT LẦN; nếu stream chỉ
    // theo dõi `jars` thì xếp danh mục hay ghi giao dịch mới không làm nó
    // phát lại — màn Hũ đứng im cho tới khi mở lại app (đã bắt tận tay trên
    // máy). `customSelect(readsFrom:)` khai báo phụ thuộc tường minh.
    final tick = _db
        .customSelect(
          'SELECT 1',
          readsFrom: {
            _db.jars,
            _db.categories,
            _db.transactions,
            _db.transactionLines,
            _db.savingsGoals,
            _db.jarGoals,
          },
        )
        .watch();

    return tick.asyncMap((_) async {
      // `.get()`, KHÔNG `watchActive(...).first`: mở một stream phụ rồi lấy
      // phần tử đầu bên trong `asyncMap` làm `pumpAndSettle` treo vô hạn ở
      // widget test (bẫy đã ghi ở project_tonyfino_gotchas — bắt lại lần
      // này khi màn Giao dịch bắt đầu hiện dải "Chi theo hũ").
      final jars = await _activeQuery(walletId).get();
      final incomeMinor = (await incomeQuery.getSingle()).read(incomeExpr) ?? 0;
      if (jars.isEmpty) {
        return JarsOverview(income: Money.vnd(incomeMinor), jars: const []);
      }
      final spentByJar = {
        for (final row in await spentQuery.get())
          row.read(effectiveJarId)!: row.read(spentExpr) ?? 0,
      };
      // Nạp là dòng ÂM (ví trừ tiền) nên đảo dấu để ra số dương "đã nạp";
      // rút là dòng DƯƠNG, giữ nguyên.
      final inByGoal = {
        for (final row in await savedQuery.get())
          row.read(effGoalId)!: (
            inMinor: -(row.read(inExpr) ?? 0),
            outMinor: row.read(outExpr) ?? 0,
          ),
      };
      final balanceByGoal = {
        for (final row in await balanceQuery.get())
          row.read(effGoalId)!: -(row.read(balanceExpr) ?? 0),
      };
      final countByJar = {
        for (final row in await countQuery.get())
          row.read(c.jarId)!: row.read(c.id.count()) ?? 0,
      };
      // Dây nối hũ ↔ quỹ (v15) + bản ghi quỹ, đọc một lần cho cả bộ hũ.
      final links =
          await (_db.select(_db.jarGoals)
                ..where((l) => l.jarId.isIn([for (final j in jars) j.id]))
                ..orderBy([(l) => OrderingTerm.asc(l.goalId)]))
              .get();
      final goalById = links.isEmpty
          ? const <int, SavingsGoal>{}
          : {
              for (final g
                  in await (_db.select(_db.savingsGoals)..where(
                        (g) => g.id.isIn(links.map((l) => l.goalId).toSet()),
                      ))
                      .get())
                g.id: g,
            };
      final goalsByJar = <int, List<JarGoalProgress>>{};
      for (final link in links) {
        final goal = goalById[link.goalId];
        if (goal == null) continue;
        (goalsByJar[link.jarId] ??= []).add(
          JarGoalProgress(
            goal: goal,
            percent: link.percent,
            // Làm tròn XUỐNG như hạn mức hũ, cùng lý do.
            inMinor:
                (inByGoal[link.goalId]?.inMinor ?? 0) * link.percent ~/ 100,
            outMinor:
                (inByGoal[link.goalId]?.outMinor ?? 0) * link.percent ~/ 100,
            savedMinor: (balanceByGoal[link.goalId] ?? 0) * link.percent ~/ 100,
            fullSavedMinor: balanceByGoal[link.goalId] ?? 0,
          ),
        );
      }

      return JarsOverview(
        income: Money.vnd(incomeMinor),
        jars: [
          for (final jar in jars)
            JarProgress(
              jar: jar,
              // Làm tròn XUỐNG: hũ hứa ít hơn thực tế một đồng thì vô hại,
              // hứa nhiều hơn thì tổng các hũ vượt thu nhập.
              allotted: Money.vnd(incomeMinor * jar.percent ~/ 100),
              used: switch (jar.jarKind) {
                JarKind.spend => Money.vnd(-(spentByJar[jar.id] ?? 0)),
                // Hũ tiết kiệm gom NHIỀU quỹ: cộng phần thuộc hũ của từng
                // quỹ (v15), theo ĐÚNG chiều của hũ (v17).
                // Mỗi chiều chỉ đếm dòng tiền CỦA CHÍNH NÓ, và đếm số
                // TỔNG — xem `JarProgress.used`. Nhờ vậy một quỹ nằm trong
                // cả hai hũ ngược chiều thì hai hũ không giẫm chân nhau.
                JarKind.saving => Money.vnd(
                  (goalsByJar[jar.id] ?? const <JarGoalProgress>[]).fold(0, (
                    sum,
                    g,
                  ) {
                    return switch (jar.flow) {
                      JarGoalFlow.deposit => sum + g.depositedMinor,
                      JarGoalFlow.spend => sum + g.withdrawnMinor,
                    };
                  }),
                ),
              },
              categoryCount: jar.jarKind == JarKind.spend
                  ? countByJar[jar.id] ?? 0
                  : 0,
              goals: goalsByJar[jar.id] ?? const <JarGoalProgress>[],
            ),
        ],
      );
    });
  }

  Future<Result<void, AppError>> seedDefaultJars(int walletId) async {
    try {
      await _db.transaction(() async {
        final existing = await (_db.select(
          _db.jars,
        )..where((j) => j.walletId.equals(walletId))).get();
        if (existing.isNotEmpty) return;
        for (var i = 0; i < kDefaultJarSeeds.length; i++) {
          final seed = kDefaultJarSeeds[i];
          await _db
              .into(_db.jars)
              .insert(
                JarsCompanion.insert(
                  walletId: walletId,
                  name: seed.name,
                  percent: seed.percent,
                  categoryColorId: seed.colorId,
                  iconCode: seed.iconCode,
                  carryOver: Value(seed.carryOver),
                  sortOrder: Value(i),
                ),
              );
        }
      });
      return const Ok(null);
    } catch (e) {
      return Err(AppError('Không tạo được bộ hũ mặc định.', cause: e));
    }
  }

  Future<Result<int, AppError>> insert({
    required int walletId,
    required String name,
    required int percent,
    required int categoryColorId,
    required String iconCode,
    bool carryOver = false,
    JarKind kind = JarKind.spend,
    JarGoalFlow flow = JarGoalFlow.deposit,
    List<JarGoalLink> goals = const [],
  }) async {
    try {
      final maxOrder =
          await (_db.selectOnly(_db.jars)
                ..addColumns([_db.jars.sortOrder.max()])
                ..where(_db.jars.walletId.equals(walletId)))
              .map((r) => r.read(_db.jars.sortOrder.max()))
              .getSingle();
      final id = await _db
          .into(_db.jars)
          .insert(
            JarsCompanion.insert(
              walletId: walletId,
              name: name,
              percent: percent,
              categoryColorId: categoryColorId,
              iconCode: iconCode,
              carryOver: Value(carryOver),
              sortOrder: Value((maxOrder ?? -1) + 1),
              kind: Value(kind.dbValue),
              goalFlow: Value(flow.dbValue),
            ),
          );
      // Quỹ chỉ có nghĩa với hũ tiết kiệm — hũ tiêu mà mang theo quỹ "ma"
      // thì sau này đổi loại sẽ tự dưng đếm tiền của quỹ đó.
      if (kind == JarKind.saving) await _writeGoalLinks(id, goals);
      return Ok(id);
    } catch (e) {
      return Err(AppError('Không tạo được hũ.', cause: e));
    }
  }

  Future<Result<void, AppError>> update({
    required int id,
    required String name,
    required int percent,
    required int categoryColorId,
    required String iconCode,
    required bool carryOver,
    JarKind kind = JarKind.spend,
    JarGoalFlow flow = JarGoalFlow.deposit,
    List<JarGoalLink> goals = const [],
  }) async {
    try {
      await _db.transaction(() async {
        await (_db.update(_db.jars)..where((j) => j.id.equals(id))).write(
          JarsCompanion(
            name: Value(name),
            percent: Value(percent),
            categoryColorId: Value(categoryColorId),
            iconCode: Value(iconCode),
            carryOver: Value(carryOver),
            kind: Value(kind.dbValue),
            goalFlow: Value(flow.dbValue),
          ),
        );
        await _writeGoalLinks(id, kind == JarKind.saving ? goals : const []);
        // Hũ tiết kiệm không gom danh mục. Đổi một hũ tiêu thành hũ tiết
        // kiệm mà để nguyên dây nối thì các danh mục đó KẸT: chi của chúng
        // không còn tính vào hũ nào, và bảng chọn danh mục của hũ tiết kiệm
        // lại không hiện để gỡ ra được.
        if (kind == JarKind.saving) {
          await (_db.update(_db.categories)..where((c) => c.jarId.equals(id)))
              .write(const CategoriesCompanion(jarId: Value(null)));
        }
      });
      return const Ok(null);
    } catch (e) {
      return Err(AppError('Không sửa được hũ.', cause: e));
    }
  }

  /// Ghi lại TOÀN BỘ dây nối hũ ↔ quỹ: xoá hết rồi chèn lại đúng danh sách
  /// mới. Gọi trong transaction của caller — nửa chừng mà hỏng thì hũ mất
  /// sạch quỹ mà vẫn còn là hũ tiết kiệm.
  ///
  /// Bỏ qua dây nối tỉ lệ 0 (không đóng góp gì, chỉ làm rối bảng) và kẹp
  /// tỉ lệ vào 1–100.
  Future<void> _writeGoalLinks(int jarId, List<JarGoalLink> goals) async {
    await (_db.delete(_db.jarGoals)..where((l) => l.jarId.equals(jarId))).go();
    final seen = <int>{};
    for (final link in goals) {
      if (!seen.add(link.goalId)) continue;
      final percent = link.percent.clamp(1, 100);
      await _db
          .into(_db.jarGoals)
          .insert(
            JarGoalsCompanion.insert(
              jarId: jarId,
              goalId: link.goalId,
              percent: Value(percent),
            ),
          );
    }
  }

  /// Quỹ nào đang được hũ nào theo dõi, và theo CHIỀU nào — nguồn cho bảng
  /// chọn quỹ ở sheet sửa hũ.
  ///
  /// Vì sao cần: một quỹ nằm trong hai hũ NGƯỢC chiều là cách dùng đúng
  /// ("Tiết kiệm" lo nạp vào, "Phát sinh" lo rút ra). Nhưng nằm trong hai
  /// hũ CÙNG chiều thì dòng tiền của nó bị đếm hai lần, và không có gì trên
  /// màn hình nói ra điều đó. Sheet sửa hũ hiện luôn vai trò cũ để Tony
  /// thấy trước khi tick.
  Future<Map<int, List<JarGoalRole>>> goalJarRoles(int walletId) async {
    final jars = await (_db.select(_db.jars)
          ..where((j) => j.walletId.equals(walletId) & j.isArchived.equals(false)))
        .get();
    final savingJars = {
      for (final j in jars)
        if (j.jarKind == JarKind.saving) j.id: j,
    };
    if (savingJars.isEmpty) return const {};
    final links = await (_db.select(
      _db.jarGoals,
    )..where((l) => l.jarId.isIn(savingJars.keys))).get();
    final out = <int, List<JarGoalRole>>{};
    for (final link in links) {
      final jar = savingJars[link.jarId]!;
      (out[link.goalId] ??= []).add(
        JarGoalRole(jarId: jar.id, jarName: jar.name, flow: jar.flow),
      );
    }
    return out;
  }

  /// Dây nối hiện có của một hũ — nguồn cho sheet sửa hũ.
  Future<List<JarGoalLink>> goalLinksOf(int jarId) async {
    final rows =
        await (_db.select(_db.jarGoals)
              ..where((l) => l.jarId.equals(jarId))
              ..orderBy([(l) => OrderingTerm.asc(l.goalId)]))
            .get();
    return [
      for (final r in rows) JarGoalLink(goalId: r.goalId, percent: r.percent),
    ];
  }

  /// Ghi thứ tự mới sau khi Tony kéo thả: [jarIdsInOrder] là TOÀN BỘ hũ
  /// đang hiện, đúng thứ tự mới. Ghi lại `sortOrder = vị trí` cho mọi hũ
  /// trong MỘT transaction — đổi chỗ từng cặp thì giữa chừng có hai hũ trùng
  /// `sortOrder` và stream phát ra một thứ tự nửa vời.
  Future<Result<void, AppError>> reorder(List<int> jarIdsInOrder) async {
    try {
      await _db.transaction(() async {
        for (var i = 0; i < jarIdsInOrder.length; i++) {
          await (_db.update(_db.jars)
                ..where((j) => j.id.equals(jarIdsInOrder[i])))
              .write(JarsCompanion(sortOrder: Value(i)));
        }
      });
      return const Ok(null);
    } catch (e) {
      return Err(AppError('Không đổi được thứ tự hũ.', cause: e));
    }
  }

  Future<Result<void, AppError>> archive(int id) async {
    try {
      await _db.transaction(() async {
        // Gỡ danh mục khỏi hũ trước: để lại `jarId` trỏ vào hũ đã lưu trữ
        // thì những danh mục đó biến mất khỏi mọi hũ đang hiện mà vẫn không
        // xếp lại được — kẹt ở trạng thái vô hình.
        await (_db.update(_db.categories)..where((c) => c.jarId.equals(id)))
            .write(const CategoriesCompanion(jarId: Value(null)));
        await (_db.update(_db.jars)..where((j) => j.id.equals(id))).write(
          const JarsCompanion(isArchived: Value(true)),
        );
      });
      return const Ok(null);
    } catch (e) {
      return Err(AppError('Không lưu trữ được hũ.', cause: e));
    }
  }

  Future<Result<void, AppError>> setCategoryJar({
    required int categoryId,
    required int? jarId,
  }) async {
    try {
      await (_db.update(_db.categories)..where((c) => c.id.equals(categoryId)))
          .write(CategoriesCompanion(jarId: Value(jarId)));
      return const Ok(null);
    } catch (e) {
      return Err(AppError('Không xếp được danh mục vào hũ.', cause: e));
    }
  }
}
