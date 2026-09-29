import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/validation.dart';
import 'seller_controller.dart';

/// Quản lý danh mục sản phẩm.
///
/// Danh mục bị ẩn chứ không xoá cứng: sản phẩm cũ vẫn trỏ tới `doc.id` của
/// danh mục, xoá hẳn sẽ làm mất nhãn của những sản phẩm đó.
class SellerCategoryScreen extends ConsumerWidget {
  const SellerCategoryScreen({super.key});

  static const route = '/seller/categories';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(allCategoriesProvider);
    final usage = ref.watch(categoryUsageProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Danh mục sản phẩm')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Thêm danh mục'),
      ),
      body: categories.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(error.toString(), textAlign: TextAlign.center),
          ),
        ),
        data: (items) => items.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.category_outlined, size: 48),
                    const SizedBox(height: 12),
                    const Text('Chưa có danh mục nào.'),
                    const SizedBox(height: 8),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'Cần ít nhất một danh mục trước khi tạo sản phẩm.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                // Danh sách đến từ listener nên không cần kéo làm mới thật,
                // invalidate chỉ để người dùng có cách ép lấy lại.
                onRefresh: () async => ref.invalidate(allCategoriesProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final category = items[index];
                    return _CategoryTile(
                      category: category,
                      productCount: usage.value?[category.id] ?? 0,
                      onRename: () => _rename(context, ref, category),
                      onToggleHidden: () =>
                          _toggleHidden(context, ref, category),
                    );
                  },
                ),
              ),
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final name = await _promptForName(context, title: 'Thêm danh mục');
    if (name == null || !context.mounted) return;
    await _run(
      ScaffoldMessenger.of(context),
      action: () => ref.read(categoryAdminProvider.notifier).create(name: name),
      success: 'Đã thêm danh mục "$name".',
    );
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    CategoryItem category,
  ) async {
    final name = await _promptForName(
      context,
      title: 'Đổi tên danh mục',
      initialValue: category.name,
    );
    if (name == null || !context.mounted) return;
    await _run(
      ScaffoldMessenger.of(context),
      action: () => ref
          .read(categoryAdminProvider.notifier)
          .rename(category.id, name: name),
      success: 'Đã đổi tên thành "$name".',
    );
  }

  Future<void> _toggleHidden(
    BuildContext context,
    WidgetRef ref,
    CategoryItem category,
  ) async {
    final admin = ref.read(categoryAdminProvider.notifier);
    if (category.isLive) {
      final count = ref.read(categoryUsageProvider).value?[category.id] ?? 0;
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Ẩn "${category.name}"?'),
          content: Text(
            count > 0
                ? 'Có $count sản phẩm đang dùng danh mục này. Chúng vẫn '
                    'còn bán bình thường, chỉ là không chọn được danh mục này '
                    'khi tạo hoặc sửa sản phẩm mới.'
                : 'Danh mục sẽ không hiện trong danh sách chọn. Có thể hiện '
                    'lại bất cứ lúc nào.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Ẩn'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      if (!context.mounted) return;
      await _run(
        ScaffoldMessenger.of(context),
        action: () => admin.setDeleted(category.id, deleted: true),
        success: 'Đã ẩn "${category.name}".',
      );
    } else {
      await _run(
        ScaffoldMessenger.of(context),
        action: () => admin.setDeleted(category.id, deleted: false),
        success: 'Đã hiện lại "${category.name}".',
      );
    }
  }
}

/// Hộp thoại nhập tên, trả `null` nếu huỷ. Chặn ngay khi gõ sai thay vì để
/// người dùng bấm "Lưu" rồi mới nhận lỗi.
Future<String?> _promptForName(
  BuildContext context, {
  required String title,
  String initialValue = '',
}) async {
  final controller = TextEditingController(text: initialValue);
  final formKey = GlobalKey<FormState>();

  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Form(
        key: formKey,
        child: TextFormField(
          controller: controller,
          autofocus: true,
          maxLength: kMaxCategoryNameLength,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Tên danh mục',
            helperText: 'Ví dụ: Điện thoại, Laptop, Phụ kiện',
          ),
          validator: validateCategoryName,
          onFieldSubmitted: (_) {
            if (formKey.currentState?.validate() ?? false) {
              Navigator.pop(context, sanitizeText(controller.text));
            }
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () {
            if (formKey.currentState?.validate() ?? false) {
              Navigator.pop(context, sanitizeText(controller.text));
            }
          },
          child: const Text('Lưu'),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}

/// Chạy một lệnh ghi, báo lỗi lên màn hình thay vì ném ra ngoài.
///
/// Nhận `ScaffoldMessengerState` thay vì `BuildContext` vì sau `await`
/// thì `context` có thể đã bị tháo khỏi cây widget; `messenger` thì vẫn
/// dùng được và vẫn trỏ đúng `Scaffold` đang mở.
Future<void> _run(
  ScaffoldMessengerState messenger, {
  required Future<void> Function() action,
  required String success,
}) async {
  // Lấy màu TRƯỚC khi await: sau await thì `messenger.context` đọc lên sẽ
  // bị báo là dùng BuildContext qua async gap.
  final errorColor = Theme.of(messenger.context).colorScheme.error;
  try {
    await action();
    messenger.showSnackBar(SnackBar(content: Text(success)));
  } on Exception catch (error) {
    messenger.showSnackBar(
      SnackBar(content: Text(_readableError(error)), backgroundColor: errorColor),
    );
  }
}

/// `StateError` của controller mang thông điệp cho người dùng; lỗi từ
/// Firestore thì không, nên tách riêng thay vì in thẳng `Exception: ...`.
String _readableError(Object error) {
  if (error is StateError) return error.message.toString();
  final text = error.toString();
  if (text.contains('permission-denied')) {
    return 'Không đủ quyền. Chỉ seller hoặc admin mới quản lý được danh mục.';
  }
  return text;
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.productCount,
    required this.onRename,
    required this.onToggleHidden,
  });

  final CategoryItem category;
  final int productCount;
  final VoidCallback onRename;
  final VoidCallback onToggleHidden;

  @override
  Widget build(BuildContext context) {
    final hidden = !category.isLive;
    return Card(
      color: hidden
          ? Theme.of(context).colorScheme.surfaceContainerHighest
          : null,
      child: ListTile(
        leading: Icon(
          hidden ? Icons.visibility_off_outlined : Icons.folder_outlined,
        ),
        title: Text(
          category.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          hidden
              ? 'Đang ẩn · $productCount sản phẩm'
              : '$productCount sản phẩm · ${category.id}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Đổi tên',
              icon: const Icon(Icons.edit_outlined),
              onPressed: onRename,
            ),
            IconButton(
              tooltip: hidden ? 'Hiện lại' : 'Ẩn',
              icon: Icon(
                hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              ),
              onPressed: onToggleHidden,
            ),
          ],
        ),
      ),
    );
  }
}
