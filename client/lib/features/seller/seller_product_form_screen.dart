import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../catalog/catalog_models.dart';
import '../catalog/product_detail_screen.dart';
import 'seller_controller.dart';

class SellerProductFormScreen extends ConsumerStatefulWidget {
  const SellerProductFormScreen({super.key, this.product});

  final CatalogProduct? product;

  @override
  ConsumerState<SellerProductFormScreen> createState() => _SellerProductFormScreenState();
}

class _SellerProductFormScreenState extends ConsumerState<SellerProductFormScreen> {
  late final TextEditingController _name;
  late final TextEditingController _sku;
  late final TextEditingController _price;
  late final TextEditingController _stock;
  late final TextEditingController _description;
  String? _categoryId;
  bool _saving = false;

  final List<MapEntry<TextEditingController, TextEditingController>> _specRows = [];

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _name = TextEditingController(text: product?.name ?? '');
    _sku = TextEditingController(text: product?.sku ?? '');
    _price = TextEditingController(text: product?.price.toString() ?? '');
    _stock = TextEditingController();
    _description = TextEditingController(text: product?.description ?? '');
    _categoryId = product?.categoryId;
    if (product != null) {
      _specRows.addAll(
        product.specs.entries.map(
          (e) => MapEntry(TextEditingController(text: e.key), TextEditingController(text: e.value)),
        ),
      );
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _sku.dispose();
    _price.dispose();
    _stock.dispose();
    _description.dispose();
    for (final row in _specRows) {
      row.key.dispose();
      row.value.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final price = double.tryParse(_price.text.replaceAll('.', ''));
    if (price == null || _name.text.trim().isEmpty || _sku.text.trim().isEmpty) {
      _showError('Vui lòng nhập đầy đủ tên, mã SKU và giá hợp lệ.');
      return;
    }
    // `firestore.rules` bắt buộc `products.category_id is string` — bỏ trống
    // thì Rules chặn, nên chặn ngay ở form để khỏi gửi lên rồi mới nhận lỗi.
    if (_categoryId == null || _categoryId!.isEmpty) {
      _showError('Vui lòng chọn danh mục sản phẩm.');
      return;
    }

    setState(() => _saving = true);
    final notifier = ref.read(sellerProductsProvider.notifier);
    final specs = _specRows
        .map((row) => {'key': row.key.text, 'value': row.value.text})
        .toList();

    try {
      await (_isEdit
          ? notifier.updateProduct(
              widget.product!.id,
              name: _name.text,
              sku: _sku.text,
              price: price,
              description: _description.text,
              categoryId: _categoryId,
              specs: specs,
            )
          : notifier.create(
              name: _name.text,
              sku: _sku.text,
              price: price,
              description: _description.text,
              categoryId: _categoryId,
              stock: int.tryParse(_stock.text.replaceAll('.', '')),
              specs: specs,
            ));

      await notifier.refresh();
      if (mounted) context.pop();
    } on Exception catch (error) {
      if (mounted) _showError(error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(sellerCategoriesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Sửa sản phẩm' : 'Thêm sản phẩm')),
      body: Form(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ProductImage(imageData: widget.product?.imageData, height: 180),
            ),
            const SizedBox(height: 8),
            Text(
              'Ảnh sản phẩm sẽ được thêm ở giai đoạn sau.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Tên sản phẩm *'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _sku,
                    enabled: !_isEdit,
                    decoration: InputDecoration(
                      labelText: 'SKU *',
                      helperText: _isEdit ? 'Không đổi được SKU' : null,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _price,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Giá (VNĐ) *'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: _categoryId,
                    decoration: const InputDecoration(labelText: 'Danh mục'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('—'),
                      ),
                      ...?categories.value?.map(
                        (category) => DropdownMenuItem<String?>(
                          value: category.id,
                          child: Text(category.name),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => _categoryId = value),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _stock,
                    keyboardType: TextInputType.number,
                    enabled: !_isEdit,
                    decoration: InputDecoration(
                      labelText: 'Tồn nhập kho',
                      helperText: _isEdit ? 'Chỉ khi tạo' : null,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Mô tả'),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text('Thông số', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => setState(() {
                    _specRows.add(
                      MapEntry(TextEditingController(), TextEditingController()),
                    );
                  }),
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm thông số'),
                ),
              ],
            ),
            ..._specRows.indexed.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: entry.$2.key,
                        decoration: const InputDecoration(labelText: 'Tên'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: entry.$2.value,
                        decoration: const InputDecoration(labelText: 'Giá trị'),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        setState(() {
                          entry.$2.key.dispose();
                          entry.$2.value.dispose();
                          _specRows.remove(entry.$2);
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_isEdit ? 'Lưu thay đổi' : 'Tạo sản phẩm'),
            ),
          ],
        ),
      ),
    );
  }
}