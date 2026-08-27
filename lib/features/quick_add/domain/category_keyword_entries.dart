import '../../../data/db/database.dart';
import 'parser/normalizer.dart';
import 'parser/parse_result.dart';

/// Trọng số cho TÊN đầy đủ của một danh mục — xem lý do ở
/// `categoryKeywordEntriesProvider`.
const double kCategoryNameWeight = 2.0;

/// Trọng số cho MỘT TỪ đặc trưng rút từ tên danh mục con.
const double kSubcategoryWordWeight = 1.2;

/// Dựng toàn bộ từ khoá sống (tên danh mục + từ đặc trưng của danh mục con +
/// bảng `category_keywords`) cho `category_matcher`.
///
/// Hàm THUẦN, tách khỏi provider có chủ đích: nó là chỗ quyết định câu văn
/// nào rơi vào danh mục nào, nên phải chạy được trong công cụ soi
/// (`test/tooling/`) trên sổ THẬT mà không cần dựng Riverpod/DB.
List<CategoryKeywordEntry> buildCategoryKeywordEntries({
  required List<Category> categories,
  required List<CategoryKeyword> keywordRows,
}) {
  final parentKeyById = {
    for (final category in categories)
      category.id.toString(): category.parentCategoryId?.toString(),
  };
  return [
    for (final category in categories)
      CategoryKeywordEntry(
        categoryKey: category.id.toString(),
        parentKey: category.parentCategoryId?.toString(),
        keyword: category.name,
        keywordAscii: normalize(category.name).ascii,
        weight: kCategoryNameWeight,
      ),
    ...subcategoryWordSignals(categories),
    for (final row in keywordRows)
      CategoryKeywordEntry(
        categoryKey: row.categoryId.toString(),
        parentKey: parentKeyById[row.categoryId.toString()],
        keyword: row.keyword,
        keywordAscii: row.keywordAscii,
        weight: row.weight,
      ),
  ];
}

/// 🚨 Từ ĐẶC TRƯNG trong TÊN một danh mục con là từ khoá của chính con đó.
///
/// Bug thật Tony bắt được: "hủ tíu trưa 30k" chỉ ra được danh mục CHA. Tên
/// đầy đủ của con ("Ăn trưa thiết yếu") không nằm trong câu — người ta viết
/// tên món + đúng MỘT chữ đặc trưng ("trưa", "sáng", "chung oxytocin"), nên
/// nếu chỉ so khớp cả tên thì danh mục con gần như không bao giờ giành được.
///
/// "Đặc trưng" ở đây có định nghĩa hẹp và đo được, KHÔNG phải "mọi từ trong
/// tên" — ba bộ lọc, mỗi bộ dập một cách hỏng đã thấy thật:
///
///  1. **Bỏ từ có trong tên CHA.** "Ăn chung oxytocin" dưới "Ăn uống" —
///     chữ "ăn" không phân biệt được con nào với con nào, mà lại là một
///     trong những âm tiết dày đặc nhất tiếng Việt.
///  2. **Bỏ từ dùng chung giữa NHIỀU danh mục.** Sổ Tony có "Ăn sáng thiết
///     yếu", "Mua sắm › Thiết yếu", "Thực phẩm › Thiết yếu" — "thiết"/"yếu"
///     xuất hiện ở cả ba nên nói lên rất ít; giữ lại chỉ làm nhiễu điểm.
///     Ngoại lệ CỐ Ý: từ chỉ buổi ([timeOfDayWords]) luôn được giữ, vì
///     "Ăn sáng/trưa/tối thiết yếu" cùng một cha thì chính chữ buổi mới là
///     thứ phân biệt chúng — đúng ca gốc Tony báo.
///  3. **Bỏ từ quá ngắn và từ chức năng.** Bỏ dấu xong, từ 1–3 ký tự trùng
///     nhan nhản trong tiếng Việt — đúng lớp lỗi `category_seed.dart` đã
///     trả giá bằng dữ liệu đo thật với `'ăn'`/`'nước'`/`'cháo'` trần.
///
/// Chọn NHÁNH vẫn không bị ảnh hưởng: `category_matcher` cộng điểm con về
/// nhánh của cha trước khi so nhánh với nhau, nên một từ đặc trưng của con
/// không kéo được cả câu sang nhánh khác.
Iterable<CategoryKeywordEntry> subcategoryWordSignals(
  List<Category> categories,
) sync* {
  final nameById = {for (final c in categories) c.id: c.name};

  // Từ nào xuất hiện trong tên của bao nhiêu danh mục (lọc 2).
  final categoryCountByWord = <String, int>{};
  for (final category in categories) {
    for (final word in _wordsOf(category.name)) {
      categoryCountByWord.update(word, (n) => n + 1, ifAbsent: () => 1);
    }
  }

  final timeWordsAscii = {
    for (final word in timeOfDayWords.keys) normalize(word).ascii,
  };

  for (final category in categories) {
    final parentId = category.parentCategoryId;
    if (parentId == null) continue;
    final parentWords = _wordsOf(nameById[parentId] ?? '').toSet();

    // CỤM còn lại sau khi bỏ những từ đã nằm trong tên cha. "Ăn chung
    // oxytocin" dưới "Ăn uống" → "chung oxytocin".
    //
    // 🚨 Cụm là thứ DUY NHẤT phân biệt được "Ăn uống › Ăn chung oxytocin"
    // với "Gia đình › Oxytocin" — hai danh mục cùng chứa một tên riêng, chỉ
    // khác chữ "chung". Xét từng từ rời thì "chung" bị loại (quá phổ thông)
    // và "oxytocin" bị loại (dùng chung giữa hai danh mục), nên riêng câu
    // "ốc chung oxytocin" sẽ rơi vào Gia đình — sai. Cụm thì không cần lọc
    // "dùng chung": đủ dài là đã đủ đặc trưng.
    final phraseWords = [
      for (final word in _wordsOf(category.name))
        if (!parentWords.contains(word)) word,
    ];
    if (phraseWords.length >= 2) {
      final phrase = phraseWords.join(' ');
      yield CategoryKeywordEntry(
        categoryKey: category.id.toString(),
        parentKey: parentId.toString(),
        keyword: phrase,
        keywordAscii: phrase,
        weight: kSubcategoryWordWeight,
      );
    }

    for (final word in _wordsOf(category.name).toSet()) {
      final isTimeWord = timeWordsAscii.contains(word);
      if (parentWords.contains(word)) continue;
      if (!isTimeWord && (categoryCountByWord[word] ?? 0) > 1) continue;
      if (!isTimeWord && _isNoiseWord(word)) continue;
      yield CategoryKeywordEntry(
        categoryKey: category.id.toString(),
        parentKey: parentId.toString(),
        keyword: word,
        keywordAscii: word,
        weight: kSubcategoryWordWeight,
      );
    }
  }
}

/// Các từ trong một tên danh mục, đã bỏ dấu và bỏ ký tự không phải chữ/số
/// ("Thức ăn & Đồ uống" → `thuc`, `an`, `do`, `uong`).
Iterable<String> _wordsOf(String name) => normalize(
  name,
).ascii.split(RegExp(r'[^a-z0-9]+')).where((w) => w.isNotEmpty);

/// Tách [text] thành các TỪ đáng đem đi nhớ, giữ nguyên dấu tiếng Việt để
/// hiện lên cho người dùng chọn.
///
/// Trả về `(word: từ có dấu, suggested: có nên tick sẵn không)` — từ nhiễu
/// vẫn hiện ra (người dùng có thể muốn nhớ đúng nó) nhưng không tick sẵn.
/// Dùng ở sheet "Nhớ từ nào" sau khi người dùng sửa danh mục ở màn chat.
///
/// 🚨 Bộ lọc ở đây RỘNG HƠN [_isNoiseWord] một cách CÓ CHỦ ĐÍCH, đừng gộp
/// hai cái làm một. [_isNoiseWord] lọc cho việc app TỰ rút từ trong tên
/// danh mục — ở đó đoán sai là âm thầm làm hỏng phân loại, nên nó bỏ luôn
/// mọi từ ≤3 ký tự. Ở đây thì NGƯỜI DÙNG đang chủ động dạy một câu họ vừa
/// gõ, mà "phở", "ốc", "bún" đều là từ khoá tốt — áp ngưỡng độ dài vào đây
/// nghĩa là im lặng từ chối dạy đúng những món ăn tên ngắn nhất. Chỉ loại
/// từ chức năng, thứ không bao giờ chỉ vào một danh mục nào.
List<({String word, bool suggested})> keywordCandidates(String text) {
  final words = text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  final seen = <String>{};
  final result = <({String word, bool suggested})>[];
  for (final word in words) {
    final ascii = normalize(word).ascii.trim();
    if (ascii.isEmpty || !seen.add(ascii)) continue;
    result.add((word: word, suggested: !_learnStopWords.contains(ascii)));
  }
  return result;
}

/// Từ quá ngắn hoặc quá phổ thông để nói lên bất cứ điều gì về danh mục.
///
/// Ngưỡng 3 ký tự KHÔNG phải con số tuỳ tiện: bỏ dấu xong, gần như mọi âm
/// tiết tiếng Việt ngắn đều đụng một âm tiết khác ("ăn"→`an`, "đồ"→`do`,
/// "bố"→`bo` trùng "bò"). Danh sách bên dưới là những từ 4+ ký tự vẫn không
/// phân biệt được gì, rút từ chính tên danh mục trong sổ Tony.
bool _isNoiseWord(String asciiWord) =>
    asciiWord.length <= 3 || _noiseWords.contains(asciiWord);

/// Gom các từ ĐÃ CHỌN thành những CỤM LIÊN TIẾP theo đúng thứ tự trong câu
/// gốc — mỗi cụm là một từ khoá sẽ được học.
///
/// 🚨 Tiếng Việt ghép từ bằng khoảng trắng, nên chọn từng từ rồi lưu từng
/// từ là làm hỏng nghĩa: "hủ tíu" tách ra thành "hủ" và "tíu" — hai chuỗi
/// một mình vô nghĩa, lại còn khớp bậy vào "hủ nút", "tíu tít". Gom liên
/// tiếp thì "hủ tíu trưa" chọn cả ba từ ra đúng MỘT khoá `hủ tíu trưa`.
///
/// Bỏ một từ ở GIỮA thì cụm đứt làm hai — "bún chả với tee" bỏ "với" cho ra
/// `bún chả` và `tee`, KHÔNG phải `bún chả tee` (chuỗi đó không có trong
/// câu nào cả, `category_matcher` đòi các từ phải liên tiếp).
List<String> groupIntoPhrases(String text, Set<String> selectedWords) {
  final phrases = <String>[];
  var current = <String>[];
  for (final word in text.trim().split(RegExp(r'\s+'))) {
    if (word.isEmpty) continue;
    if (selectedWords.contains(word)) {
      current.add(word);
    } else if (current.isNotEmpty) {
      phrases.add(current.join(' '));
      current = [];
    }
  }
  if (current.isNotEmpty) phrases.add(current.join(' '));
  return phrases;
}

/// Từ chức năng — nối câu, chỉ định, số đếm. Không bao giờ là tín hiệu
/// danh mục dù người dùng có gõ bao nhiêu lần.
const _learnStopWords = {
  'va',
  'voi',
  'cho',
  'cua',
  'o',
  'tai',
  'thi',
  'la',
  'roi',
  'nay',
  'nua',
  'luon',
  'cai',
  'mot',
  'cung',
  'de',
  've',
  'cac',
  'nhung',
  'ma',
  'khi',
  'do',
};

const _noiseWords = {
  'khac', // "Điện tử › Khác"
  'chung', // "Ăn chung oxytocin" — "chung" một mình không chỉ vào ai
  'thiet',
  'yeu',
  'phat',
  'sinh', // "Phát sinh" (tên của cả một danh mục gốc lẫn nhiều con)
  'ngan',
  'dai',
  'han', // "Ngắn hạn"/"Dài hạn"
  'tien', // "tiền …"
  'mua',
  'ban',
};
