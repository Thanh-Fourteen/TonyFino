import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../../theme/context_ext.dart';
import '../../../theme/tokens/icons.dart';
import '../../../ui/app_card.dart';
import '../../../ui/money_text.dart';
import '../../transactions/transactions_providers.dart';
import 'domain/category_mapping.dart';
import 'domain/rolly_reconciliation.dart';
import 'import_controller.dart';

/// Màn nhập dữ liệu (Phase 9) — chọn file → (Rolly: ánh xạ danh mục) →
/// dry-run diff → commit. Mỗi bước MỘT màn hình rõ ràng, KHÔNG commit ẩn ở
/// đâu giữa chừng — chỉ nút "Xác nhận nhập" ở màn dry-run mới ghi vào DB.
/// 🚨 Màn nhập dữ liệu CỐ Ý KHÔNG che số tiền, dù cờ "ẩn số tiền" đang bật.
///
/// Đây là màn ĐỐI CHIẾU trước khi ghi 362 dòng vào sổ: che số đi thì Tony
/// không kiểm được cái gì sắp được nhập, mà đó chính là toàn bộ mục đích
/// của màn này. Cờ ẩn số dành cho lúc lướt app trước mặt người khác, không
/// phải lúc đang tự tay duyệt dữ liệu của mình.
class ImportScreen extends ConsumerWidget {
  const ImportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step = ref.watch(importControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Nhập / xuất dữ liệu')),
      body: switch (step) {
        ImportIdle() => const _IdleView(),
        ImportBusy() => const Center(child: CircularProgressIndicator()),
        ImportMappingCategories() => _MappingView(step: step),
        ImportReadyForDryRun() => _PreDryRunView(step: step),
        ImportDryRunResult() => _DryRunView(step: step),
        ImportCommitted() => _CommittedView(step: step),
        ImportSavingsPreview() => _SavingsPreviewView(step: step),
        ImportSavingsCommitted() => _SavingsCommittedView(step: step),
        ImportSubcategoryPreview() => _SubcategoryPreviewView(step: step),
        ImportSubcategoryCommitted() => _SubcategoryCommittedView(step: step),
        ImportFailed() => _FailedView(step: step),
      },
    );
  }
}

class _IdleView extends ConsumerWidget {
  const _IdleView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(importControllerProvider.notifier);
    return ListView(
      padding: EdgeInsets.all(context.space.screenHorizontal),
      children: [
        Text('Nhập từ Rolly', style: context.text.titleMedium),
        SizedBox(height: context.space.xs),
        Text(
          'Chọn file JSON đã kéo từ Rolly (raw_rolly/input.json, hoặc gộp '
          'thêm category_view để có tên danh mục thật). Mọi bước sau đều '
          'xem trước được trước khi ghi bất cứ gì vào sổ.',
          style: context.text.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        SizedBox(height: context.space.xs),
        Text(
          'MỘT file gộp cả bốn mảng {"input", "category_view", "subcategory", '
          '"savings"} dùng được cho CẢ BA nút trên màn này — tải một lần, '
          'chọn lại chính file đó ở từng bước, theo đúng thứ tự từ trên '
          'xuống.',
          style: context.text.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        SizedBox(height: context.space.sm),
        FilledButton(
          onPressed: controller.pickRollyFile,
          child: const Text('Chọn file JSON Rolly'),
        ),
        SizedBox(height: context.space.xxl),
        Text('Lịch sử tiết kiệm Rolly', style: context.text.titleMedium),
        SizedBox(height: context.space.xs),
        Text(
          'Chọn file JSON gộp {"savings": [...], "input": [...]} để nhập mục '
          'tiêu tiết kiệm cũ + gắn lại vào các giao dịch chuyển khoản đã có '
          'sẵn (Phase 9). Không import ngân sách/nợ vay/giao dịch định kỳ ở '
          'đây — dữ liệu Rolly của Tony không có gì thuộc ba loại đó.',
          style: context.text.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        SizedBox(height: context.space.sm),
        OutlinedButton(
          onPressed: controller.pickRollySavingsFile,
          child: const Text('Chọn file JSON tiết kiệm Rolly'),
        ),
        SizedBox(height: context.space.xxl),
        Text('Danh mục phụ Rolly', style: context.text.titleMedium),
        SizedBox(height: context.space.xs),
        Text(
          'Chọn file JSON gộp {"subcategory": [...], "input": [...]} để khôi '
          'phục danh mục phụ (vd "Giao thông → Xăng/Gửi xe") cho các giao '
          'dịch đã nhập từ Phase 9 — importer lúc đó bỏ qua field này.',
          style: context.text.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        SizedBox(height: context.space.sm),
        OutlinedButton(
          onPressed: controller.pickRollySubcategoryFile,
          child: const Text('Chọn file JSON danh mục phụ Rolly'),
        ),
        SizedBox(height: context.space.xxl),
        Text('CSV', style: context.text.titleMedium),
        SizedBox(height: context.space.xs),
        Text(
          'Nhập/xuất giao dịch bằng CSV — định dạng riêng của TonyFino, tự '
          'đọc lại được chính file mình xuất ra.',
          style: context.text.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        SizedBox(height: context.space.sm),
        Row(
          children: [
            OutlinedButton(
              onPressed: controller.pickCsvFile,
              child: const Text('Chọn file CSV'),
            ),
            SizedBox(width: context.space.sm),
            OutlinedButton(
              onPressed: controller.exportCsv,
              child: const Text('Xuất CSV'),
            ),
          ],
        ),
      ],
    );
  }
}

class _MappingView extends ConsumerWidget {
  const _MappingView({required this.step});
  final ImportMappingCategories step;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(importControllerProvider.notifier);
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final usages = step.parseResult.categoryUsages;
    final decidedCount = usages
        .where(
          (u) =>
              step.mapping[u.bucket] is MappingToCategory ||
              step.mapping[u.bucket] is MappingUncategorized,
        )
        .length;

    return Column(
      children: [
        if (step.parseResult.issues.isNotEmpty)
          Container(
            width: double.infinity,
            color: context.colors.budgetWarn.withValues(alpha: 0.12),
            padding: EdgeInsets.all(context.space.sm),
            child: Text(
              '${step.parseResult.issues.length} dòng bất thường bị bỏ qua — '
              '${step.parseResult.issues.first}'
              '${step.parseResult.issues.length > 1 ? ' (và ${step.parseResult.issues.length - 1} dòng khác)' : ''}',
              style: context.text.bodySmall?.copyWith(
                color: context.colors.budgetWarn,
              ),
            ),
          ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.all(context.space.screenHorizontal),
            children: [
              Text(
                'Ánh xạ mỗi danh mục Rolly sang một danh mục TonyFino ($decidedCount/${usages.length} đã chọn)',
                style: context.text.titleMedium,
              ),
              SizedBox(height: context.space.sm),
              for (final usage in usages)
                Padding(
                  padding: EdgeInsets.only(bottom: context.space.sm),
                  child: AppCard(
                    // Bố cục DỌC (tên trên, dropdown dưới) thay vì Row: nhãn
                    // '➕ Tạo mới "Thức ăn & Đồ uống"' dài hơn hẳn tên danh
                    // mục có sẵn, nhét chung một hàng thì hoặc tràn, hoặc
                    // (với isExpanded) làm Row nhận ràng buộc vô hạn và ném
                    // assertion layout — bắt được ngay bằng widget test.
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${usage.title} (${usage.transactionCount} giao dịch)',
                          style: context.text.bodyMedium,
                        ),
                        if (usage.bucket.isSavingsTransferBucket) ...[
                          SizedBox(height: context.space.xxs),
                          Text(
                            'Đây là tiền chuyển vào/ra tiết kiệm, không phải '
                            'khoản chi — để "Chưa phân loại". Nó được gắn vào '
                            'mục tiêu tiết kiệm ở bước sau, tự động.',
                            style: context.text.labelSmall?.copyWith(
                              color: context.colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                        SizedBox(height: context.space.xs),
                        DropdownButton<MappingChoice>(
                          // `items` bên dưới CHỈ chứa `MappingToCategory`/
                          // `MappingUncategorized` — `MappingUndecided` (chưa
                          // chọn) không khớp item nào, phải đổi thành `null`
                          // để `DropdownButton` hiện `hint` thay vì ném
                          // assertion "0 item khớp value" (bug thật bắt được
                          // bằng widget test).
                          isExpanded: true,
                          value: switch (step.mapping[usage.bucket]) {
                            final MappingToCategory choice => choice,
                            final MappingUncategorized choice => choice,
                            final MappingCreateCategory choice => choice,
                            MappingUndecided() || null => null,
                          },
                          hint: Text(
                            'Chưa chọn',
                            style: TextStyle(color: context.colors.budgetWarn),
                          ),
                          items: [
                            // "Tạo mới" đứng ĐẦU danh sách, không phải cuối:
                            // menu của DropdownButton chỉ dựng phần thấy
                            // được và cuộn được — với 13 danh mục mặc định
                            // thì mọi thứ xếp sau chúng đều nằm dưới đáy,
                            // phải cuộn mới thấy. Đó chính là lý do lựa chọn
                            // đúng cho "Giặt đồ" gần như vô hình, còn danh
                            // mục có sẵn ở ngay trước mắt.
                            if (usage.bucket.rollyCategoryId != null)
                              DropdownMenuItem(
                                value: MappingCreateCategory(
                                  name: usage.title,
                                  kind: usage.kind,
                                ),
                                child: Text('➕ Tạo mới "${usage.title}"'),
                              ),
                            for (final c in categories)
                              DropdownMenuItem(
                                value: MappingToCategory(c.id),
                                child: Text(c.name),
                              ),
                            const DropdownMenuItem(
                              value: MappingUncategorized(),
                              child: Text('Chưa phân loại'),
                            ),
                          ],
                          onChanged: (choice) {
                            if (choice != null) {
                              controller.setCategoryMapping(
                                usage.bucket,
                                choice,
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        SafeArea(
          minimum: EdgeInsets.all(context.space.screenHorizontal),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: step.allDecided ? controller.confirmMapping : null,
              child: const Text('Tiếp tục → xem trước'),
            ),
          ),
        ),
      ],
    );
  }
}

class _PreDryRunView extends ConsumerWidget {
  const _PreDryRunView({required this.step});
  final ImportReadyForDryRun step;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(importControllerProvider.notifier);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.space.screenHorizontal),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${step.rows.length} giao dịch sẵn sàng xem trước',
              style: context.text.titleMedium,
            ),
            if (step.unmatchedCategoryNames.isNotEmpty) ...[
              SizedBox(height: context.space.sm),
              Text(
                'Tên danh mục không khớp (sẽ để Chưa phân loại): '
                '${step.unmatchedCategoryNames.join(', ')}',
                textAlign: TextAlign.center,
                style: context.text.bodySmall?.copyWith(
                  color: context.colors.budgetWarn,
                ),
              ),
            ],
            SizedBox(height: context.space.lg),
            FilledButton(
              onPressed: controller.runDryRun,
              child: const Text('Xem trước (dry-run)'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DryRunView extends ConsumerWidget {
  const _DryRunView({required this.step});
  final ImportDryRunResult step;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(importControllerProvider.notifier);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.all(context.space.screenHorizontal),
            children: [
              Text('Dry-run diff', style: context.text.titleMedium),
              SizedBox(height: context.space.sm),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${step.newCount} giao dịch MỚI sẽ được thêm'),
                    Text(
                      '${step.duplicateCount} đã có sẵn (sourceId trùng) — sẽ bỏ qua',
                      style: TextStyle(color: context.colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (step.reconciliation != null) ...[
                SizedBox(height: context.space.lg),
                Text(
                  'Báo cáo đối chiếu (đối chiếu tay với oracle Phase 2)',
                  style: context.text.titleMedium,
                ),
                SizedBox(height: context.space.sm),
                _ReconciliationTable(report: step.reconciliation!),
              ],
            ],
          ),
        ),
        SafeArea(
          minimum: EdgeInsets.all(context.space.screenHorizontal),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: step.newCount == 0 ? null : controller.commit,
              child: Text(
                step.newCount == 0
                    ? 'Không có gì mới để nhập'
                    : 'Xác nhận nhập ${step.newCount} giao dịch',
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReconciliationTable extends StatelessWidget {
  const _ReconciliationTable({required this.report});
  final RollyReconciliationReport report;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final month in report.months)
            Padding(
              padding: EdgeInsets.only(bottom: context.space.xs),
              child: Row(
                children: [
                  SizedBox(width: 72, child: Text(month.yearMonth)),
                  Expanded(child: Text('${month.transactionCount} giao dịch')),
                  MoneyText(
                    Money.vnd(month.expenseMinor),
                    size: MoneySize.small,
                  ),
                  SizedBox(width: context.space.sm),
                  MoneyText(
                    Money.vnd(month.incomeMinor),
                    size: MoneySize.small,
                  ),
                ],
              ),
            ),
          const Divider(),
          Text('Tổng: ${report.totalTransactionCount} giao dịch'),
          Text('Chi: ${Money.vnd(report.totalExpenseMinor).format()}'),
          Text('Thu: ${Money.vnd(report.totalIncomeMinor).format()}'),
          if (report.savingsTransferCount > 0)
            Text(
              '${report.savingsTransferCount} giao dịch chuyển khoản/tiết kiệm '
              '(không tính vào Chi/Thu ở trên)',
              style: TextStyle(color: context.colors.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

class _CommittedView extends ConsumerWidget {
  const _CommittedView({required this.step});
  final ImportCommitted step;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(importControllerProvider.notifier);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.space.screenHorizontal),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(kIconCheckCircle, color: context.colors.incomeText, size: 48),
            SizedBox(height: context.space.sm),
            Text(
              'Đã nhập ${step.inserted} giao dịch mới',
              style: context.text.titleMedium,
            ),
            if (step.skippedDuplicate > 0)
              Text(
                '${step.skippedDuplicate} dòng đã có sẵn từ trước, đã bỏ qua',
              ),
            // Hai bước chạy nối tiếp — nói rõ đã làm gì, không im lặng ghi
            // thêm dữ liệu rồi để Tony tự đoán.
            if (step.followUpSubcategory case final sub?)
              Text(
                'Danh mục phụ: ${sub.reassigned} giao dịch được gán lại, '
                '${sub.createdSubcategories} danh mục phụ mới'
                '${sub.alreadyDone > 0 ? ' (${sub.alreadyDone} đã đúng từ trước)' : ''}',
                textAlign: TextAlign.center,
                style: context.text.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            if (step.followUpSavings case final sav?)
              Text(
                'Tiết kiệm: ${sav.insertedGoals} mục tiêu mới, '
                '${sav.linkedContributions} giao dịch được gắn vào mục tiêu'
                '${sav.skippedDuplicateGoals > 0 ? ' (${sav.skippedDuplicateGoals} đã có sẵn)' : ''}',
                textAlign: TextAlign.center,
                style: context.text.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            if (step.followUpError case final err?) ...[
              SizedBox(height: context.space.sm),
              Text(
                'Giao dịch đã nhập xong và vẫn đúng, nhưng bước sau chưa '
                'chạy được — $err. Chọn lại file đó ở đúng mục bên dưới để '
                'chạy tay.',
                textAlign: TextAlign.center,
                style: context.text.bodyMedium?.copyWith(
                  color: context.colors.budgetWarn,
                ),
              ),
            ],
            if (step.reconciliation != null) ...[
              SizedBox(height: context.space.lg),
              _ReconciliationTable(report: step.reconciliation!),
            ],
            SizedBox(height: context.space.lg),
            OutlinedButton(
              onPressed: controller.reset,
              child: const Text('Xong'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavingsPreviewView extends ConsumerWidget {
  const _SavingsPreviewView({required this.step});
  final ImportSavingsPreview step;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(importControllerProvider.notifier);
    return Column(
      children: [
        if (step.issues.isNotEmpty)
          Container(
            width: double.infinity,
            color: context.colors.budgetWarn.withValues(alpha: 0.12),
            padding: EdgeInsets.all(context.space.sm),
            child: Text(
              '${step.issues.length} dòng bất thường bị bỏ qua — ${step.issues.first}',
              style: context.text.bodySmall?.copyWith(
                color: context.colors.budgetWarn,
              ),
            ),
          ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.all(context.space.screenHorizontal),
            children: [
              Text(
                '${step.newCount} mục tiêu MỚI, ${step.existingSourceIds.length} đã có sẵn',
                style: context.text.titleMedium,
              ),
              SizedBox(height: context.space.sm),
              for (final goal in step.goals)
                Padding(
                  padding: EdgeInsets.only(bottom: context.space.sm),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(goal.name)),
                            MoneyText(
                              Money.vnd(goal.targetAmountMinor),
                              size: MoneySize.small,
                            ),
                          ],
                        ),
                        Text(
                          step.existingSourceIds.contains(goal.sourceId)
                              ? 'Đã có sẵn — bỏ qua'
                              : '${step.contributionSourceIdsByRollyGoalId[goal.rollyGoalId]?.length ?? 0} '
                                    'giao dịch đóng góp sẽ gắn lại vào mục tiêu này'
                                    '${goal.totalContributedMinor != null ? ' (oracle Rolly: ${Money.vnd(goal.totalContributedMinor!).format()})' : ''}',
                          style: context.text.bodySmall?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        SafeArea(
          minimum: EdgeInsets.all(context.space.screenHorizontal),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: step.newCount == 0
                  ? null
                  : controller.commitSavingsImport,
              child: Text(
                step.newCount == 0
                    ? 'Không có gì mới để nhập'
                    : 'Xác nhận nhập ${step.newCount} mục tiêu',
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SavingsCommittedView extends ConsumerWidget {
  const _SavingsCommittedView({required this.step});
  final ImportSavingsCommitted step;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(importControllerProvider.notifier);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.space.screenHorizontal),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(kIconCheckCircle, color: context.colors.incomeText, size: 48),
            SizedBox(height: context.space.sm),
            Text(
              'Đã nhập ${step.summary.insertedGoals} mục tiêu mới',
              style: context.text.titleMedium,
            ),
            if (step.summary.skippedDuplicateGoals > 0)
              Text(
                '${step.summary.skippedDuplicateGoals} mục tiêu đã có sẵn từ trước, đã bỏ qua',
              ),
            Text(
              '${step.summary.linkedContributions} giao dịch đã được gắn lại vào mục tiêu',
            ),
            SizedBox(height: context.space.lg),
            OutlinedButton(
              onPressed: controller.reset,
              child: const Text('Xong'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubcategoryPreviewView extends ConsumerWidget {
  const _SubcategoryPreviewView({required this.step});
  final ImportSubcategoryPreview step;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(importControllerProvider.notifier);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.space.screenHorizontal),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${step.entries.length} giao dịch có thể khôi phục danh mục phụ',
              style: context.text.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (step.issues.isNotEmpty) ...[
              SizedBox(height: context.space.sm),
              Text(
                '${step.issues.length} dòng bất thường bị bỏ qua — ${step.issues.first}',
                textAlign: TextAlign.center,
                style: context.text.bodySmall?.copyWith(
                  color: context.colors.budgetWarn,
                ),
              ),
            ],
            SizedBox(height: context.space.sm),
            Text(
              'Giao dịch đã là danh mục con từ trước (chạy lại lần 2) sẽ tự '
              'động bỏ qua, không đụng tới.',
              textAlign: TextAlign.center,
              style: context.text.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            SizedBox(height: context.space.lg),
            FilledButton(
              onPressed: step.entries.isEmpty
                  ? null
                  : controller.commitSubcategoryBackfill,
              child: Text(
                'Xác nhận khôi phục ${step.entries.length} giao dịch',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubcategoryCommittedView extends ConsumerWidget {
  const _SubcategoryCommittedView({required this.step});
  final ImportSubcategoryCommitted step;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(importControllerProvider.notifier);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.space.screenHorizontal),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(kIconCheckCircle, color: context.colors.incomeText, size: 48),
            SizedBox(height: context.space.sm),
            Text(
              'Đã gán lại ${step.summary.reassigned} giao dịch vào danh mục phụ',
              style: context.text.titleMedium,
              textAlign: TextAlign.center,
            ),
            Text(
              '${step.summary.createdSubcategories} danh mục phụ mới được tạo',
            ),
            if (step.summary.alreadyDone > 0)
              Text(
                '${step.summary.alreadyDone} giao dịch đã là danh mục con từ trước, đã bỏ qua',
              ),
            SizedBox(height: context.space.lg),
            OutlinedButton(
              onPressed: controller.reset,
              child: const Text('Xong'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FailedView extends ConsumerWidget {
  const _FailedView({required this.step});
  final ImportFailed step;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(importControllerProvider.notifier);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.space.screenHorizontal),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(kIconError, color: context.colors.expenseFill, size: 48),
            SizedBox(height: context.space.sm),
            Text(step.message, textAlign: TextAlign.center),
            SizedBox(height: context.space.lg),
            FilledButton(
              onPressed: controller.reset,
              child: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}
