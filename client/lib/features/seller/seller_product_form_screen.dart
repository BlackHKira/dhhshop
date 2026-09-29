import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/validation.dart';
import '../catalog/catalog_models.dart';
import '../catalog/product_detail_screen.dart';
import 'product_image_picker.dart';
import 'seller_category_screen.dart';
import 'seller_controller.dart';

class SellerProductFormScreen extends ConsumerStatefulWidget {
  const SellerProductFormScreen({super.key, this.product});

  final CatalogProduct? product;

  @override
  ConsumerState<SellerProductFormScreen> createState() => _SellerProductFormScreenState();
}

class _SellerProductFormScreenState extends ConsumerState<SellerProductFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _sku;
  late final TextEditingController _price;
  late final TextEditingController _stock;
  late final TextEditingController _description;

  /// Ảnh hiện tại: sản phẩm đang sửa thì lấy ảnh cũ, còn sản phẩm mới thì
  /// rỗng cho tới khi người dùng chọn. Giữ nguyên chuỗi này khi lưu nghĩa
  /// là "không đổi ảnh" — nếu để `null` mỗi lần sửa thì mất ảnh.
  late String _imageData;
  String? _categoryId;
  bool _saving = false;
  bool _pickingImage = false;

  /// Cờ riêng cho từng dòng thông số để báo lỗi ngay cạnh ô nhập.
  final Map<int, String?> _specErrors = {};
  final List<MapEntry<TextEditingController, TextEditingController>> _specRows = [];

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _name = TextEditingController(text: product?.name ?? '');
    _sku = TextEditingController(text: product?.sku ?? '');
    _price = TextEditingController(text: product?.price.toStringAsFixed(0) ?? '');
    _stock = TextEditingController();
    _description = TextEditingController(text: product?.description ?? '');
    _imageData = product?.imageData ?? '';
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
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_categoryId == null || _categoryId!.isEmpty) {
      _toast('Vui lòng chọn danh mục sản phẩm.');
      return;
    }
    if (!_validateSpecRows()) return;

    final price = parseAmount(_price.text);
    if (price == null) return;

    setState(() => _saving = true);
    final notifier = ref.read(sellerProductsProvider.notifier);
    final specs = _specRows
        .map((row) => {'key': row.key.text, 'value': row.value.text})
        .toList();

    try {
      if (_isEdit) {
        await notifier.updateProduct(
          widget.product!.id,
          name: _name.text,
          sku: _sku.text,
          price: price.toDouble(),
          description: _description.text,
          categoryId: _categoryId!,
          imageData: _imageData,
          specs: specs,
        );
      } else {
        await notifier.create(
          name: _name.text,
          sku: _sku.text,
          price: price.toDouble(),
          description: _description.text,
          categoryId: _categoryId!,
          stock: parseAmount(_stock.text) ?? 0,
          imageData: _imageData,
          specs: specs,
        );
      }
      if (mounted) context.pop();
    } on Exception catch (error) {
      if (mounted) _toast(_readableError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool _validateSpecRows() {
    var ok = true;
    setState(() {
      _specErrors.clear();
      for (var i = 0; i < _specRows.length; i++) {
        final error = validateSpec(_specRows[i].key.text, _specRows[i].value.text);
        _specErrors[i] = error;
        if (error != null) ok = false;
      }
    });
    if (!ok) _toast('Có dòng thông số chưa hợp lệ, xem lại phần thông số.');
    return ok;
  }

  Future<void> _pickImage() async {
    setState(() => _pickingImage = true);
    try {
      final data = await pickProductImage();
      if (data == null || !mounted) return;
      setState(() => _imageData = data);
    } on ImageTooLargeException catch (error) {
      if (mounted) _toast(error.message);
    } on Exception catch (error) {
      if (mounted) _toast('Không mở được thư viện ảnh: ${error.toString()}');
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(activeCategoriesProvider);
    // Một danh mục bị ẩn giữa lúc đang mở form thì lựa chọn hiện tại không
    // còn trong danh sách. Tìm trong `allCategoriesProvider` (gồm cả mục đã
    // ẩn) rồi chèn lại vào dropdown, để không âm thầm mất danh mục đang
    // chọn khi bấm lưu.
    final missing = ref.watch(allCategoriesProvider).value
        ?.where((c) => c.id == _categoryId)
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Sửa sản phẩm' : 'Thêm sản phẩm')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildImagePicker(),
            const SizedBox(height: 20),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Tên sản phẩm *'),
              validator: validateProductName,
              maxLength: kMaxNameLength,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _sku,
                    enabled: !_isEdit,
                    decoration: InputDecoration(
                      labelText: 'SKU *',
                      helperText: _isEdit ? 'Không đổi được SKU' : null,
                    ),
                    validator: validateSku,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: kMaxSkuLength,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _price,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Giá (VNĐ) *',
                      helperText: 'Nhập 1500000 hoặc 1.500.000',
                    ),
                    validator: validatePrice,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: categories.when(
                    loading: () => const InputDecorator(
                      decoration: InputDecoration(labelText: 'Danh mục'),
                      child: LinearProgressIndicator(),
                    ),
                    error: (error, _) => InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Danh mục',
                        errorText: 'Không tải được danh mục',
                      ),
                      child: const Text('—'),
                    ),
                    data: (items) {
                      final hasSelected =
                          _categoryId == null || items.any((c) => c.id == _categoryId);
                      return DropdownButtonFormField<String>(
                        initialValue: _categoryId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Danh mục *'),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('— Chọn danh mục —'),
                          ),
                          if (missing != null && !hasSelected)
                            DropdownMenuItem<String>(
                              value: missing.id,
                              child: Text('${missing.name} (đang ẩn)',
                                  overflow: TextOverflow.ellipsis),
                            ),
                          for (final category in items)
                            DropdownMenuItem<String>(
                              value: category.id,
                              child: Text(category.name, overflow: TextOverflow.ellipsis),
                            ),
                        ],
                        onChanged: (value) => setState(() => _categoryId = value),
                        validator: (value) =>
                            (value == null || value.isEmpty) ? 'Chọn danh mục' : null,
                      );
                    },
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
                    validator: validateStock,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              maxLines: 4,
              maxLength: kMaxDescriptionLength,
              decoration: const InputDecoration(labelText: 'Mô tả'),
              validator: validateDescription,
            ),
            const SizedBox(height: 8),
            _buildSpecs(),
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

  Widget _buildImagePicker() {
    final hasImage = _imageData.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ProductImage(imageData: _imageData, height: 180),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickingImage ? null : _pickImage,
                icon: _pickingImage
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.photo_library_outlined),
                label: Text(hasImage ? 'Đổi ảnh' : 'Chọn ảnh'),
              ),
            ),
            if (hasImage) ...[
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _imageData = kEmptyImage),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Bỏ ảnh'),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Ảnh được nén về tối đa ${kImageTargetBytes ~/ 1024} KB trước khi lưu. '
          'Giới hạn Firestore là 1 MiB cho mỗi tài liệu nên ảnh quá lớn sẽ bị từ chối.',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        TextButton.icon(
          onPressed: () => context.push(SellerCategoryScreen.route),
          icon: const Icon(Icons.folder_outlined, size: 18),
          label: const Text('Quản lý danh mục'),
        ),
      ],
    );
  }

  Widget _buildSpecs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              label: const Text('Thêm'),
            ),
          ],
        ),
        for (final entry in _specRows.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: entry.$2.key,
                    decoration: InputDecoration(
                      labelText: 'Tên',
                      errorText: _specErrors[entry.$1],
                    ),
                    onChanged: (_) => setState(() => _specErrors.remove(entry.$1)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: entry.$2.value,
                    decoration: const InputDecoration(labelText: 'Giá trị'),
                    onChanged: (_) => setState(() => _specErrors.remove(entry.$1)),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() {
                    entry.$2.key.dispose();
                    entry.$2.value.dispose();
                    _specRows.removeAt(entry.$1);
                    _specErrors.remove(entry.$1);
                  }),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

String _readableError(Object error) {
  if (error is StateError) return error.message.toString();
  final text = error.toString();
  if (text.contains('permission-denied')) {
    return 'Không đủ quyền ghi sản phẩm.';
  }
  return text;
}
