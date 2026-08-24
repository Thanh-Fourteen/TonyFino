/// Từ khoá khởi tạo cho một danh mục — `weight` cao hơn nghĩa là tín hiệu
/// mạnh hơn khi `category_matcher` (Phase 7) tính điểm `weight × độ dài khớp`.
class SeedKeyword {
  const SeedKeyword(this.keyword, [this.weight = 1.0]);
  final String keyword;
  final double weight;
}

class CategorySeed {
  const CategorySeed({
    required this.key,
    required this.name,
    required this.kind,
    required this.colorId,
    required this.iconCode,
    required this.keywords,
  });

  /// Khoá ổn định, không đổi kể cả khi đổi `name` hiển thị — dùng để tra cứu
  /// trong migration seed và trong test, không dùng `name` (có thể đổi ngôn ngữ).
  final String key;
  final String name;

  /// `'expense'` hoặc `'income'` — quyết định dấu mặc định gợi ý ở quick-add,
  /// KHÔNG quyết định dấu thật của giao dịch (đó luôn là lựa chọn tường minh).
  final String kind;

  /// Chỉ số vào bảng màu cố định của theme (D10) — TUYỆT ĐỐI không phải hex.
  final int colorId;

  /// Tên icon Material Symbols (package `material_symbols_icons`).
  final String iconCode;

  final List<SeedKeyword> keywords;
}

/// Danh mục CON mặc định (Phase 22 addendum — Tony yêu cầu trực tiếp: "cafe
/// 20k" phải vào "Ăn uống → Tiêu vặt", đúng cách Rolly của Tony đã dùng, xem
/// `docs/decisions.md`). Trước bản này, `_seedDefaultCategories` chỉ tạo
/// danh mục CẤP GỐC — danh mục con chỉ từng có được qua import Rolly hoặc
/// tự tay tạo (Phase 25 `CategoryDetailScreen`). `parentKey` khớp
/// [CategorySeed.key] của danh mục cha.
class SubcategorySeed {
  const SubcategorySeed({
    required this.parentKey,
    required this.name,
    required this.iconCode,
    required this.keywords,
  });

  final String parentKey;
  final String name;
  final String iconCode;
  final List<SeedKeyword> keywords;
}

/// 12 danh mục mặc định + ~300 từ khoá tiếng Việt, rút ra từ vốn từ thật của
/// Rolly (`raw_rolly/input.json`, không commit) rồi viết lại bằng từ vựng
/// chung — không giữ lại tên riêng/biệt danh cá nhân trong dữ liệu đã commit.
const List<CategorySeed> defaultCategorySeeds = [
  CategorySeed(
    key: 'an_uong',
    name: 'Ăn uống',
    kind: 'expense',
    colorId: 0,
    iconCode: 'restaurant',
    keywords: [
      SeedKeyword('trà sữa', 1.2),
      SeedKeyword('ăn sáng', 1.3),
      SeedKeyword('ăn trưa', 1.3),
      SeedKeyword('ăn tối', 1.3),
      SeedKeyword('ăn khuya', 1.1),
      SeedKeyword('cơm trưa', 1.2),
      SeedKeyword('cơm tối', 1.2),
      SeedKeyword('cơm'),
      SeedKeyword('cơm tấm'),
      SeedKeyword('cơm văn phòng'),
      SeedKeyword('phở', 1.2),
      SeedKeyword('bún', 1.1),
      SeedKeyword('bún bò'),
      SeedKeyword('bún riêu'),
      SeedKeyword('bún chả'),
      SeedKeyword('bún đậu'),
      SeedKeyword('hủ tiếu'),
      SeedKeyword('bánh mì', 1.2),
      SeedKeyword('bánh canh'),
      SeedKeyword('bánh tráng'),
      SeedKeyword('bánh xèo'),
      SeedKeyword('bánh cuốn'),
      SeedKeyword('mì gói'),
      SeedKeyword('mì gà'),
      SeedKeyword('mì quảng'),
      SeedKeyword('ốc'),
      SeedKeyword('nước mía'),
      SeedKeyword('nước ép'),
      SeedKeyword('sinh tố'),
      SeedKeyword('trà đá'),
      SeedKeyword('trà chanh'),
      SeedKeyword('chè'),
      SeedKeyword('kem'),
      SeedKeyword('pizza'),
      SeedKeyword('gà rán'),
      SeedKeyword('lẩu'),
      SeedKeyword('nem'),
      SeedKeyword('chả'),
      SeedKeyword('quán ăn'),
      SeedKeyword('quán nhậu'),
      SeedKeyword('nhậu'),
      SeedKeyword('bia'),
      SeedKeyword('rượu'),
      SeedKeyword('nước ngọt'),
      SeedKeyword('nước suối'),
      SeedKeyword('đi chợ', 1.1),
      SeedKeyword('chợ'),

      // ── Bổ sung sau khi ĐO trên 209 ghi chú thật Tony đã gõ ở Rolly
      // (`test/tooling/audit_category_keywords.dart`) — không phải nghĩ ra
      // trong đầu. Đây là những câu bộ khớp trượt nhiều nhất.

      // Cà phê KHÔNG khai ở đây — nó thuộc danh mục CON "Tiêu vặt"
      // (`defaultSubcategorySeeds`), đúng yêu cầu Phase 22 của Tony. Khai ở
      // cả hai cấp chỉ làm điểm số khó lần ra mà kết quả không đổi.

      // HỦ TÍU: chỉ có biến thể 'hủ tiếu'. Tony gõ 'hủ tíu' (8 lần) — cách
      // viết phổ biến ở miền Nam. Hai chuỗi khác nhau hoàn toàn sau khi bỏ
      // dấu ('hu tieu' ≠ 'hu tiu') nên phải khai cả hai.
      SeedKeyword('hủ tíu'),
      SeedKeyword('hủ tiu'),

      // 🚨 CỐ Ý KHÔNG có `SeedKeyword('ăn')` trần.
      //
      // Nghe thì hợp lý, nhưng bộ khớp so trên bản BỎ DẤU: 'ăn' thành 'an'
      // — một trong những âm tiết phổ biến nhất tiếng Việt (an kỳ, bình an,
      // an ninh, an toàn…). Đo thật: nó chỉ thêm 1 câu sai chứ không thêm
      // câu đúng nào, vì "ăn bò"/"ăn mì trưa"/"ăn hủ tíu" đã được chính món
      // ăn ('bò', 'mì', 'hủ tíu') bắt rồi.
      // Đồ uống chung, nhẹ hơn `tiền nước` (1.3) của Nhà cửa nên hoá đơn
      // nước vẫn về đúng chỗ.
      SeedKeyword('nước', 0.9),

      // Món ăn còn thiếu
      SeedKeyword('bò kho'),
      SeedKeyword('bánh bao'),
      SeedKeyword('bánh giò'),
      SeedKeyword('bánh chuối'),
      SeedKeyword('bánh tiêu'),
      SeedKeyword('bánh bèo'),
      SeedKeyword('bánh khọt'),
      SeedKeyword('bánh ướt'),
      SeedKeyword('mì', 1.0),
      SeedKeyword('mì cay'),
      SeedKeyword('mì trộn'),
      // 🚨 KHÔNG dùng 'cháo' trần: bỏ dấu thành 'chao', trùng y hệt 'chào'
      // trong "xin chào" — corpus test bắt được ngay. Khai từng món cụ thể.
      SeedKeyword('cháo lòng'),
      SeedKeyword('cháo gà'),
      SeedKeyword('cháo hàu'),
      SeedKeyword('cháo sườn'),
      SeedKeyword('xôi'),
      SeedKeyword('chân gà'),
      SeedKeyword('tàu hủ'),
      SeedKeyword('tào phớ'),
      SeedKeyword('lạp xưởng'),
      SeedKeyword('pad thái'),
      SeedKeyword('buffet'),
      SeedKeyword('nướng'),
      SeedKeyword('gà'),
      SeedKeyword('bò'),

      // Thực phẩm mua về
      SeedKeyword('trái cây'),
      SeedKeyword('hoa quả'),
      SeedKeyword('chuối'),
      SeedKeyword('gạo'),
      SeedKeyword('thực phẩm', 1.1),
      SeedKeyword('bách hoá xanh'),
      SeedKeyword('bách hóa xanh'),
      SeedKeyword('bhx'),
      SeedKeyword('jollibee'),
    ],
  ),
  CategorySeed(
    key: 'di_chuyen',
    name: 'Di chuyển',
    kind: 'expense',
    colorId: 1,
    iconCode: 'directions_car',
    keywords: [
      SeedKeyword('xăng', 1.3),
      SeedKeyword('đổ xăng', 1.3),
      SeedKeyword('gửi xe', 1.2),
      SeedKeyword('giữ xe', 1.2),
      SeedKeyword('gửi xe máy'),
      SeedKeyword('gửi ô tô'),
      SeedKeyword('grab', 1.2),
      SeedKeyword('be'),
      SeedKeyword('gojek'),
      SeedKeyword('xanh sm'),
      SeedKeyword('taxi', 1.1),
      SeedKeyword('xe ôm'),
      SeedKeyword('xe bus'),
      SeedKeyword('vé xe'),
      SeedKeyword('vé máy bay'),
      SeedKeyword('vé tàu'),
      SeedKeyword('vé metro'),
      SeedKeyword('metro'),
      SeedKeyword('rửa xe'),
      SeedKeyword('bảo dưỡng xe'),
      SeedKeyword('bảo dưỡng xe máy'),
      SeedKeyword('thay nhớt'),
      SeedKeyword('sửa xe'),
      SeedKeyword('vá xe'),
      SeedKeyword('phí đường bộ'),
      SeedKeyword('thu phí'),
      SeedKeyword('đổ dầu'),
      SeedKeyword('sạc xe điện'),
      SeedKeyword('gửi xe tháng'),
    ],
  ),
  CategorySeed(
    key: 'nha_cua',
    name: 'Nhà cửa',
    kind: 'expense',
    colorId: 2,
    iconCode: 'home',
    keywords: [
      SeedKeyword('tiền nhà', 1.3),
      SeedKeyword('tiền trọ', 1.3),
      SeedKeyword('trọ', 1.2),
      SeedKeyword('thuê nhà', 1.2),
      SeedKeyword('tiền điện', 1.3),
      SeedKeyword('tiền nước', 1.3),
      SeedKeyword('điện', 1.1),
      SeedKeyword('hoá đơn nước', 1.3),
      SeedKeyword('hoá đơn điện', 1.3),
      // 🚨 KHÔNG có `SeedKeyword('nước')` trần ở đây.
      //
      // Nó từng có, và nó cướp sạch đồ uống: "nước lọc", "nước dừa", "nước
      // mía", "nước highlands coffee", "nước kana" đều bị xếp vào Nhà cửa.
      // Đo trên 209 ghi chú thật của Tony: 6 câu sai chỉ vì một từ khoá này.
      // Tiền nước vẫn bắt được qua `tiền nước`/`hoá đơn nước`/`sửa ống nước`
      // — dài hơn nên điểm cao hơn, không cần từ trần.
      SeedKeyword('internet', 1.2),
      SeedKeyword('wifi', 1.2),
      SeedKeyword('truyền hình cáp'),
      SeedKeyword('phí quản lý'),
      SeedKeyword('phí chung cư'),
      SeedKeyword('giặt đồ', 1.2),
      SeedKeyword('giặt ủi'),
      SeedKeyword('giặt là'),
      SeedKeyword('sửa nhà'),
      SeedKeyword('sửa ống nước'),
      SeedKeyword('sửa điện'),
      SeedKeyword('mua đồ gia dụng'),
      SeedKeyword('nội thất'),
      SeedKeyword('chăn ga gối'),
      SeedKeyword('bếp gas'),
      SeedKeyword('gas'),
      SeedKeyword('rác'),
      SeedKeyword('vệ sinh'),
    ],
  ),
  CategorySeed(
    key: 'gia_dinh',
    name: 'Gia đình',
    kind: 'expense',
    colorId: 3,
    iconCode: 'family_restroom',
    keywords: [
      SeedKeyword('tiền học con', 1.2),
      SeedKeyword('học phí con'),
      SeedKeyword('sữa cho con'),
      SeedKeyword('bỉm'),
      SeedKeyword('đồ chơi'),
      SeedKeyword('quần áo trẻ em'),
      SeedKeyword('tiền ăn con'),
      SeedKeyword('quà cho mẹ'),
      SeedKeyword('quà cho ba'),
      SeedKeyword('biếu ba mẹ'),
      SeedKeyword('hiếu hỉ'),
      SeedKeyword('đám cưới'),
      SeedKeyword('đám giỗ'),
      SeedKeyword('mừng tuổi'),
      SeedKeyword('lì xì'),
      SeedKeyword('sinh nhật'),
      SeedKeyword('quà tặng'),
      SeedKeyword('tiền tiêu vặt'),
      SeedKeyword('hoa'),
      SeedKeyword('tiền quỹ lớp'),
      SeedKeyword('tiền quỹ'),
      SeedKeyword('khám thai'),
      SeedKeyword('sữa bột'),
      SeedKeyword('tã'),
    ],
  ),
  CategorySeed(
    key: 'mua_sam',
    name: 'Mua sắm',
    kind: 'expense',
    colorId: 4,
    iconCode: 'shopping_bag',
    keywords: [
      SeedKeyword('quần áo', 1.2),
      SeedKeyword('giày dép'),
      SeedKeyword('túi xách'),
      SeedKeyword('đồng hồ'),
      SeedKeyword('mỹ phẩm'),
      SeedKeyword('kem đánh răng'),
      SeedKeyword('bàn chải'),
      SeedKeyword('dầu gội'),
      SeedKeyword('sữa tắm'),
      SeedKeyword('khăn mặt'),
      SeedKeyword('khẩu trang'),
      SeedKeyword('nước rửa tay'),
      SeedKeyword('đồ dùng vệ sinh'),
      SeedKeyword('nhu yếu phẩm'),
      SeedKeyword('đồ gia dụng'),
      SeedKeyword('siêu thị', 1.1),
      SeedKeyword('tạp hoá'),
      SeedKeyword('bách hoá xanh'),
      SeedKeyword('coopmart'),
      SeedKeyword('mua sắm online'),
      SeedKeyword('shopee'),
      SeedKeyword('lazada'),
      SeedKeyword('tiki'),
      SeedKeyword('sách vở'),
      SeedKeyword('văn phòng phẩm'),
    ],
  ),
  CategorySeed(
    key: 'dien_tu',
    name: 'Điện tử',
    kind: 'expense',
    colorId: 5,
    iconCode: 'devices',
    keywords: [
      SeedKeyword('điện thoại', 1.2),
      SeedKeyword('laptop', 1.2),
      SeedKeyword('máy tính'),
      SeedKeyword('tai nghe'),
      SeedKeyword('sạc'),
      SeedKeyword('cáp sạc'),
      SeedKeyword('pin'),
      SeedKeyword('ốp lưng'),
      SeedKeyword('màn hình'),
      SeedKeyword('chuột máy tính'),
      SeedKeyword('bàn phím'),
      SeedKeyword('loa'),
      SeedKeyword('tivi'),
      SeedKeyword('máy ảnh'),
      SeedKeyword('thẻ nhớ'),
      SeedKeyword('nạp thẻ điện thoại', 1.2),
      SeedKeyword('nạp card', 1.1),
      SeedKeyword('cước điện thoại'),
      SeedKeyword('phụ kiện điện tử'),
      SeedKeyword('đồng hồ thông minh'),
    ],
  ),
  CategorySeed(
    key: 'suc_khoe',
    name: 'Sức khỏe',
    kind: 'expense',
    colorId: 6,
    iconCode: 'health_and_safety',
    keywords: [
      SeedKeyword('khám bệnh', 1.3),
      SeedKeyword('khám sức khỏe'),
      SeedKeyword('khám', 1.1),
      SeedKeyword('thuốc', 1.2),
      SeedKeyword('nhà thuốc'),
      SeedKeyword('bệnh viện', 1.1),
      SeedKeyword('phòng khám'),
      SeedKeyword('bảo hiểm y tế'),
      SeedKeyword('bảo hiểm sức khỏe'),
      SeedKeyword('tiêm vắc xin'),
      SeedKeyword('tiêm phòng'),
      SeedKeyword('nha khoa'),
      SeedKeyword('khám răng'),
      SeedKeyword('kính mắt'),
      SeedKeyword('vitamin'),
      SeedKeyword('thực phẩm chức năng'),
      SeedKeyword('xét nghiệm'),
      SeedKeyword('siêu âm'),
      SeedKeyword('đi khám'),
      SeedKeyword('viện phí'),
      SeedKeyword('cấp cứu'),
    ],
  ),
  CategorySeed(
    key: 'lam_dep',
    name: 'Làm đẹp',
    kind: 'expense',
    colorId: 7,
    iconCode: 'spa',
    keywords: [
      SeedKeyword('cắt tóc', 1.3),
      SeedKeyword('gội đầu'),
      SeedKeyword('uốn tóc'),
      SeedKeyword('nhuộm tóc'),
      SeedKeyword('làm nail'),
      SeedKeyword('spa', 1.1),
      SeedKeyword('mát xa'),
      SeedKeyword('mỹ phẩm làm đẹp'),
      SeedKeyword('kem dưỡng da'),
      SeedKeyword('son môi'),
      SeedKeyword('nước hoa'),
      SeedKeyword('chăm sóc da'),
      SeedKeyword('tẩy trang'),
      SeedKeyword('serum'),
      SeedKeyword('kem chống nắng'),
      SeedKeyword('salon tóc'),
      SeedKeyword('làm tóc'),
      SeedKeyword('phun xăm'),
    ],
  ),
  CategorySeed(
    key: 'giao_duc',
    name: 'Giáo dục',
    kind: 'expense',
    colorId: 8,
    iconCode: 'school',
    keywords: [
      SeedKeyword('học phí', 1.3),
      SeedKeyword('tiền học', 1.2),
      SeedKeyword('sách vở học'),
      SeedKeyword('khóa học', 1.1),
      SeedKeyword('học thêm'),
      SeedKeyword('gia sư'),
      SeedKeyword('đồ dùng học tập'),
      SeedKeyword('photo tài liệu'),
      SeedKeyword('in tài liệu'),
      SeedKeyword('thi cử'),
      SeedKeyword('lệ phí thi'),
      SeedKeyword('chứng chỉ'),
      SeedKeyword('tiếng anh'),
      SeedKeyword('ielts'),
      SeedKeyword('khóa học online'),
      SeedKeyword('sách giáo khoa'),
      SeedKeyword('bút'),
      SeedKeyword('vở'),
      SeedKeyword('cặp sách'),
      SeedKeyword('học liệu'),
    ],
  ),
  CategorySeed(
    key: 'giai_tri',
    name: 'Giải trí',
    kind: 'expense',
    colorId: 9,
    iconCode: 'theater_comedy',
    keywords: [
      SeedKeyword('xem phim', 1.2),
      SeedKeyword('vé xem phim', 1.2),
      SeedKeyword('rạp phim'),
      SeedKeyword('du lịch', 1.2),
      SeedKeyword('vé máy bay du lịch'),
      SeedKeyword('khách sạn'),
      SeedKeyword('karaoke'),
      SeedKeyword('game'),
      SeedKeyword('nạp game'),
      SeedKeyword('vé concert'),
      SeedKeyword('ca nhạc'),
      SeedKeyword('bảo tàng'),
      SeedKeyword('công viên'),
      SeedKeyword('du xuân'),
      SeedKeyword('đi chơi', 1.1),
      SeedKeyword('giải trí'),
      SeedKeyword('netflix'),
      SeedKeyword('spotify'),
      SeedKeyword('mua vé'),
      SeedKeyword('tham quan'),
      SeedKeyword('dã ngoại'),
      SeedKeyword('vé số'),
    ],
  ),
  CategorySeed(
    key: 'phat_sinh',
    name: 'Phát sinh',
    kind: 'expense',
    colorId: 10,
    iconCode: 'more_horiz',
    keywords: [
      SeedKeyword('phát sinh'),
      SeedKeyword('chi phí khác'),
      SeedKeyword('tiền lẻ'),
      SeedKeyword('sửa chữa'),
      SeedKeyword('mất tiền'),
      SeedKeyword('bị móc túi'),
      SeedKeyword('hoàn tiền'),
      SeedKeyword('đóng góp'),
      SeedKeyword('quyên góp'),
      SeedKeyword('từ thiện'),
      SeedKeyword('phí phạt'),
      SeedKeyword('phí dịch vụ'),
      SeedKeyword('chi tiêu khác'),
      SeedKeyword('việc đột xuất'),
      SeedKeyword('khác'),
    ],
  ),
  CategorySeed(
    key: 'luong',
    name: 'Lương',
    kind: 'income',
    colorId: 11,
    iconCode: 'payments',
    keywords: [
      SeedKeyword('lương', 1.4),
      SeedKeyword('lương tháng', 1.3),
      SeedKeyword('thưởng', 1.2),
      SeedKeyword('tiền thưởng', 1.2),
      SeedKeyword('thu nhập', 1.1),
      SeedKeyword('lương thêm giờ'),
      SeedKeyword('làm thêm'),
      SeedKeyword('freelance'),
      SeedKeyword('hoa hồng'),
      SeedKeyword('tiền hoàn'),
      SeedKeyword('hoàn tiền lương'),
      SeedKeyword('đầu tư'),
      SeedKeyword('lãi'),
      SeedKeyword('cổ tức'),
      SeedKeyword('tiền lãi ngân hàng'),
      SeedKeyword('bán hàng'),
      SeedKeyword('thu nhập phụ'),
    ],
  ),
];

/// Xem doc comment ở [SubcategorySeed]. Chỉ MỘT danh mục con mặc định tính
/// tới lúc này — cố ý tối thiểu, không đoán thêm danh mục con nào Tony chưa
/// yêu cầu.
const List<SubcategorySeed> defaultSubcategorySeeds = [
  SubcategorySeed(
    parentKey: 'an_uong',
    name: 'Tiêu vặt',
    iconCode: 'local_cafe',
    keywords: [
      SeedKeyword('cà phê', 1.3),
      SeedKeyword('cafe', 1.3),
      // Bỏ dấu xong "cà phê" ra "ca phe" — KHÁC "cafe", nên mỗi cách viết
      // phải khai riêng chứ không ăn theo nhau được.
      SeedKeyword('caphe', 1.3),
      SeedKeyword('coffee', 1.3),
      SeedKeyword('cf', 1.1),
      SeedKeyword('ăn vặt', 1.1),
      SeedKeyword('highlands', 1.2),
      SeedKeyword('starbucks', 1.2),
      SeedKeyword('phúc long', 1.2),
      SeedKeyword('katinat', 1.2),
      SeedKeyword('trà sữa', 1.2),
    ],
  ),
];
