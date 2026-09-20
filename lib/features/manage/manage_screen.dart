import 'package:flutter/material.dart';

import '../../theme/context_ext.dart';
import '../../theme/tokens/icons.dart';
import '../categories/categories_screen.dart';
import '../jars/jars_screen.dart';
import '../notes/notes_screen.dart';
import '../savings/savings_screen.dart';
import '../settings/recurring/recurring_screen.dart';
import '../tags/tags_screen.dart';
import '../transactions/transaction_templates_screen.dart';
import '../wallets/wallets_screen.dart';

/// Màn "Quản lý" — mọi thứ NGƯỜI DÙNG tự tạo và sửa: ví, danh mục, thẻ, hạn
/// mức, hũ, mục tiêu, giao dịch định kỳ, mẫu.
///
/// Tách hẳn khỏi Cài đặt theo yêu cầu của Tony. Lý do đúng chứ không chỉ là
/// sở thích: Cài đặt là nơi chỉnh CÁCH APP CHẠY (giao diện, khoá, sao lưu) —
/// mở ra vài lần rồi thôi. Còn tạo một danh mục hay sửa hạn mức là việc
/// hằng tuần; chôn nó sau icon bánh răng, dưới bốn nhóm khác, là đặt việc
/// làm thường xuyên vào chỗ khó tới nhất. Giờ nó nằm ngay thanh trên cùng,
/// thấy được từ cả bốn tab.
class ManageScreen extends StatelessWidget {
  const ManageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý')),
      body: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: context.space.screenHorizontal,
          vertical: context.space.md,
        ),
        children: [
          _Group(
            title: 'Tiền của tôi',
            children: [
              _ManageRow(
                icon: kIconAccountBalanceWallet,
                label: 'Ví',
                subtitle: 'Tài khoản, số dư ban đầu, chuyển khoản',
                builder: (_) => const WalletsScreen(),
              ),
              _ManageRow(
                icon: kIconEdit,
                label: 'Ghi chú',
                subtitle: 'Gõ gì tuỳ ý: cần mua, cần nhớ, dự tính',
                builder: (_) => const NotesScreen(),
              ),
              _ManageRow(
                icon: kIconInbox,
                label: 'Hũ chia thu nhập',
                subtitle: 'Chia tỉ lệ mỗi khoản thu trước khi tiêu',
                builder: (_) => const JarsScreen(),
              ),
              _ManageRow(
                icon: kIconSavings,
                label: 'Mục tiêu & nợ vay',
                subtitle: 'Tiết kiệm có đích, khoản vay/cho vay',
                builder: (_) => const SavingsScreen(),
              ),
            ],
          ),
          _Group(
            title: 'Cách phân loại',
            children: [
              _ManageRow(
                icon: kIconCategory,
                label: 'Danh mục',
                subtitle: 'Danh mục thu/chi và danh mục con',
                builder: (_) => const CategoriesScreen(),
              ),
              _ManageRow(
                icon: kIconSell,
                label: 'Thẻ',
                subtitle: 'Nhãn cắt ngang danh mục (chuyến đi, dự án…)',
                builder: (_) => const TagsScreen(),
              ),
            ],
          ),
          _Group(
            title: 'Ghi nhanh hơn',
            children: [
              _ManageRow(
                icon: kIconEventRepeat,
                label: 'Giao dịch định kỳ',
                subtitle: 'Khoản lặp lại: tiền nhà, thuê bao…',
                builder: (_) => const RecurringScreen(),
              ),
              _ManageRow(
                icon: kIconBookmark,
                label: 'Mẫu giao dịch',
                subtitle: 'Khoản hay ghi, điền sẵn một chạm',
                builder: (_) => const TransactionTemplatesScreen(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(
            top: context.space.lg,
            bottom: context.space.sm,
          ),
          child: Text(
            title,
            style: context.text.labelMedium?.copyWith(
              color: context.colors.brandText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ...children,
      ],
    );
  }
}

class _ManageRow extends StatelessWidget {
  const _ManageRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.builder,
  });

  final IconData icon;
  final String label;

  /// Một dòng nói RÕ mục này quản cái gì.
  ///
  /// Ở Cài đặt trước đây chỉ có tên trần: "Hũ chia thu nhập" và "Mục tiêu &
  /// nợ vay" cạnh nhau thì không đoán được cái nào chứa cái gì nếu chưa mở
  /// thử — mà đây đúng là màn người ta chỉ ghé khi đang đi tìm.
  final String subtitle;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(context.radii.md),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: builder)),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: context.space.sm),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  // Nền tròn sau icon dùng PETROL, không phải cam: cam ở
                  // 10% trên nền trắng ra một sắc be nhạt — mắt đọc thành
                  // nâu chứ không thành "cam nhạt" (Tony: "các màu nâu ở
                  // các nền icon"). Icon bên trong cũng petrol nên cả cụm
                  // là một khối cùng tông.
                  color: context.colors.brandText.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 20, color: context.colors.brandText),
              ),
              SizedBox(width: context.space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: context.text.bodyLarge),
                    Text(
                      subtitle,
                      style: context.text.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                kIconChevronRight,
                size: 20,
                color: context.colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
