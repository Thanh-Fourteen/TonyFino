import 'package:flutter/material.dart';

import '../data/db/database.dart' show Category;
import '../theme/context_ext.dart';

/// Nhãn danh mục HAI TẦNG dùng chung: tên danh mục CHA + tên danh mục CON
/// tách ra bằng dấu `›`.
///
/// Tony đã nói rõ hai lần: "một giao dịch thuộc một danh mục, trong danh mục
/// thì có thể có danh mục con hoặc không — không được làm phẳng". Danh sách
/// giao dịch (`TransactionRow`) làm đúng từ trước bằng chip, nhưng những
/// hàng GỌN một dòng (transcript màn chat) vẫn in mỗi tên danh mục con:
/// nhìn thấy "Tiêu vặt" thì không biết nó thuộc Ăn uống hay Mua sắm.
///
/// Chỗ này không đủ bề ngang cho một chip nên dùng dấu `›`, nhưng vẫn là
/// hai tầng tường minh — và tầng CHA đứng trước, vì đó là thứ nhóm mọi giao
/// dịch lại với nhau.
String twoTierCategoryLabel(Category? category, Map<int, Category> byId) {
  if (category == null) return 'Chưa phân loại';
  final parentId = category.parentCategoryId;
  if (parentId == null) return category.name;
  final parent = byId[parentId];
  if (parent == null) return category.name;
  return '${parent.name} › ${category.name}';
}

/// Danh mục dùng để lấy MÀU/ICON của một hàng — luôn là danh mục CHA nếu có,
/// để mọi bữa ăn cùng một icon dù ghi vào danh mục con nào.
Category? displayCategory(Category? category, Map<int, Category> byId) {
  if (category == null) return null;
  final parentId = category.parentCategoryId;
  if (parentId == null) return category;
  return byId[parentId] ?? category;
}

/// Kiểu chữ cho nhãn hai tầng ở hàng gọn — tầng con nhạt hơn không làm được
/// trong một `Text` đơn, nên giữ một kiểu chung và dựa vào dấu `›` để tách.
TextStyle? twoTierLabelStyle(BuildContext context) =>
    context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant);
