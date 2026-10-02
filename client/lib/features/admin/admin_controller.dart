import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/validation.dart';
import '../auth/auth_controller.dart';
import '../seller/seller_controller.dart';

/// ═══════════════════════════════════════════════════════════════
///  MÀN HÌNH QUẢN LÝ TÀI KHOẢN
/// ═══════════════════════════════════════════════════════════════

/// Một tài khoản trong danh sách quản lý. Đọc trực tiếp từ `users/{uid}`
/// — không có collection riêng, vì Rules đọc `users/{uid}.role` để phân
/// quyền.
class ManagedUser {
  const ManagedUser({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.role,
    required this.isActive,
    required this.createdAt,
  });

  final String uid;
  final String displayName;
  final String email;
  final UserRole role;
  final bool isActive;
  final DateTime? createdAt;

  factory ManagedUser.fromFirestore(String id, Map<String, dynamic> data) {
    return ManagedUser(
      uid: id,
      displayName: (data['display_name'] as String?) ?? '',
      email: (data['email'] as String?) ?? '',
      role: UserRole.fromFirestore(data['role']),
      isActive: (data['is_active'] as bool?) ?? true,
      createdAt: (data['created_at'] as Timestamp?)?.toDate(),
    );
  }
}

final managedUsersProvider = StreamProvider<List<ManagedUser>>((ref) {
  return FirebaseFirestore.instance.collection('users').snapshots().map((snap) {
    final users = snap.docs
        .map((doc) => ManagedUser.fromFirestore(doc.id, doc.data()))
        .toList();
    // Admin lên đầu, rồi theo tên — danh sách dài, sắp xếp giúp tìm
    // được tài khoản cần sửa mà không phải cuộn hết.
    users.sort((a, b) {
      if (a.role.index != b.role.index) return b.role.index.compareTo(a.role.index);
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });
    return users;
  });
});

/// Đổi vai trò. Rules chỉ cho Admin gán `role`, và chỉ trong ba giá trị
/// `validRole()` — nên client gửi đúng ba lựa chọn này, không cho tự nhập.
final accountAdminProvider =
    AsyncNotifierProvider<AccountAdmin, void>(AccountAdmin.new);

class AccountAdmin extends AsyncNotifier<void> {
  @override
  void build() {}

  Future<void> setRole(String uid, UserRole role) async {
    _requireSelf(uid, 'tự đổi vai trò của chính mình');
    final current = FirebaseAuth.instance.currentUser;
    if (current == null) {
      throw StateError('Chưa đăng nhập.');
    }
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({'role': role.name});
    await _writeAudit(
      action: 'set_role',
      targetType: 'users',
      targetId: uid,
      detail: 'role → ${role.name}',
    );
  }

  /// Khoá / mở khoá tài khoản bằng `is_active`.
  ///
  /// Cơ chế này chỉ thật sự chạy được vì `isActive()` đã được gắn vào
  /// `isCustomer()` / `isAdmin()` / `isStaff()` trong `firestore.rules`:
  /// trước đó đặt `is_active = false` vẫn giữ nguyên mọi quyền.
  ///
  /// Cố ý KHÔNG khoá chính tài khoản đang đăng nhập — nếu không thì admin
  /// khoá nhầm chính mình thì mất quyền gán role để mở lại, và trong lúc
  /// demo đó là bị chặn ra ngoài hẳn.
  Future<void> setActive(String uid, bool active) async {
    _requireSelf(uid, 'tự khoá tài khoản của chính mình');
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({'is_active': active});
    await _writeAudit(
      action: active ? 'unlock_user' : 'lock_user',
      targetType: 'users',
      targetId: uid,
      detail: active ? 'is_active → true' : 'is_active → false',
    );
  }

  void _requireSelf(String uid, String what) {
    if (FirebaseAuth.instance.currentUser?.uid == uid) {
      throw StateError('Không thể $what.');
    }
  }

  /// `audit_logs` bắt buộc có `user_id` = chính người đang đăng nhập
  /// (Rules chặn ghi dòng thay tên người khác), nên đây là dấu vết của
  /// thao tác, không phải danh sách có thể bịa.
  Future<void> _writeAudit({
    required String action,
    required String targetType,
    required String targetId,
    required String detail,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('audit_logs').add({
      'user_id': uid,
      'action': action,
      'target_type': targetType,
      'target_id': targetId,
      'detail': sanitizeText(detail),
      'created_at': FieldValue.serverTimestamp(),
    });
  }
}

/// Nhật ký thao tác nhạy cảm, mới nhất trước. Rules chỉ cho Admin đọc.
final auditLogsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('audit_logs')
      .orderBy('created_at', descending: true)
      .limit(100)
      .snapshots()
      .map((snap) => snap.docs.map((d) => d.data()).toList());
});

// ═══════════════════════════════════════════════════════════════
//  MÀN HÌNH ADMIN
// ═══════════════════════════════════════════════════════════════

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  static const route = '/admin';

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản trị'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Tài khoản'),
            Tab(text: 'Tồn kho'),
            Tab(text: 'Nhật ký'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _AccountsTab(),
          _StockTab(),
          _AuditTab(),
        ],
      ),
    );
  }
}

// ── Tab 1: tài khoản ──────────────────────────────────────────

class _AccountsTab extends ConsumerWidget {
  const _AccountsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(managedUsersProvider);
    return users.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Lỗi tải danh sách: $e')),
      data: (items) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(managedUsersProvider),
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) =>
              _UserTile(user: items[index], uid: FirebaseAuth.instance.currentUser?.uid),
        ),
      ),
    );
  }
}

class _UserTile extends ConsumerWidget {
  const _UserTile({required this.user, required this.uid});

  final ManagedUser user;
  final String? uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelf = user.uid == uid;
    final admin = ref.read(accountAdminProvider.notifier);

    return Card(
      color: user.isActive ? null : Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ListTile(
        leading: CircleAvatar(child: Text(user.displayName.isEmpty ? '?' : user.displayName[0].toUpperCase())),
        title: Text(
          user.displayName.isEmpty ? '(chưa đặt tên)' : user.displayName,
          style: TextStyle(
            decoration: user.isActive ? null : TextDecoration.lineThrough,
          ),
        ),
        subtitle: Text('${user.email}\n${user.isActive ? 'Hoạt động' : 'Đã khoá'}'),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          enabled: !isSelf,
          tooltip: isSelf ? 'Không thao tác trên tài khoản của chính mình' : 'Thao tác',
          onSelected: (value) async {
            final messenger = ScaffoldMessenger.of(context);
            try {
              if (value == 'toggle') {
                await admin.setActive(user.uid, !user.isActive);
              } else {
                await admin.setRole(user.uid, UserRole.values.byName(value));
              }
              ref.invalidate(managedUsersProvider);
              ref.invalidate(auditLogsProvider);
              messenger.showSnackBar(
                SnackBar(content: Text('Đã cập nhật "${user.displayName}".')),
              );
            } on StateError catch (e) {
              messenger.showSnackBar(SnackBar(content: Text(e.message)));
            } catch (e) {
              messenger.showSnackBar(SnackBar(content: Text('Lỗi: $e')));
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'toggle',
              child: Text(user.isActive ? 'Khoá tài khoản' : 'Mở khoá'),
            ),
            const PopupMenuDivider(),
            for (final role in UserRole.values)
              PopupMenuItem(
                value: role.name,
                enabled: role != user.role,
                child: Text('Đặt vai trò: ${_roleLabel(role)}'),
              ),
          ],
        ),
      ),
    );
  }
}

String _roleLabel(UserRole role) => switch (role) {
      UserRole.customer => 'Khách hàng',
      UserRole.seller => 'Seller',
      UserRole.admin => 'Admin',
    };

// ── Tab 2: tồn kho ───────────────────────────────────────────

class _StockTab extends ConsumerWidget {
  const _StockTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(stockRowsProvider);
    return rows.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Lỗi tải tồn kho: $e')),
      data: (items) => items.isEmpty
          ? const Center(child: Text('Chưa có dòng tồn kho nào.'))
          : RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(stockRowsProvider);
                ref.invalidate(stockMovementsProvider);
              },
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) =>
                    _StockTile(row: items[index]),
              ),
            ),
    );
  }
}

class _StockTile extends ConsumerWidget {
  const _StockTile({required this.row});

  final StockRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        title: Text(row.productName, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          'Thực tế ${row.stockOnHand} · Giữ chỗ ${row.stockReserved} · '
          'Bán được ${row.stockAvailable}',
        ),
        trailing: OutlinedButton(
          onPressed: () => _openAdjustDialog(context, ref),
          child: const Text('Điều chỉnh'),
        ),
      ),
    );
  }

  Future<void> _openAdjustDialog(BuildContext context, WidgetRef ref) async {
    var type = MovementType.purchase;
    var plus = _kDeltaPlus;
    final reasonCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    // Bắt `ScaffoldMessenger` TRƯỚC `await`: sau khoảng nghỉ bất đồng bộ thì
    // `context` có thể đã bị tháo khỏi cây widget, và dùng lại nó là lỗi
    // thật. Giữ tham chiếu `State` này thì an toàn.
    final messenger = ScaffoldMessenger.of(context);

    final done = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Điều chỉnh tồn — ${row.productName}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: _kDeltaPlus, label: Text('Tăng')),
                    ButtonSegment(value: false, label: Text('Giảm')),
                  ],
                  selected: {plus},
                  onSelectionChanged: (s) => setState(() => plus = s.first),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Số lượng',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<MovementType>(
                  initialValue: type,
                  decoration: const InputDecoration(
                    labelText: 'Loại biến động',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final t in MovementType.values)
                      DropdownMenuItem(value: t, child: Text(t.label)),
                  ],
                  onChanged: (t) => setState(() => type = t ?? type),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Lý do (bắt buộc)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Ghi nhận'),
            ),
          ],
        ),
      ),
    );

    if (done != true) return;

    final qty = parseAmount(qtyCtrl.text) ?? 0;
    final delta = plus ? qty : -qty;
    try {
      await adjustStock(
        productId: row.productId,
        delta: delta,
        type: type,
        reason: reasonCtrl.text,
        onChanged: () {
          ref.invalidate(stockRowsProvider);
          ref.invalidate(stockMovementsProvider);
        },
      );
      messenger.showSnackBar(
        SnackBar(content: Text('Đã ghi nhận ${delta > 0 ? '+' : ''}$delta cho "${row.productName}".')),
      );
    } on StateError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }
}

/// Chiều điều chỉnh. Dùng `bool` (tăng / giảm) thay vì enum riêng vì
/// `SegmentedButton` dùng `Set<bool>` — kiểu phải khớp với giá trị truyền
/// vào, nên enum sẽ không gán được.
const bool _kDeltaPlus = true;

// ── Tab 3: nhật ký ───────────────────────────────────────────

class _AuditTab extends ConsumerWidget {
  const _AuditTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(auditLogsProvider);
    return logs.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Lỗi tải nhật ký: $e')),
      data: (items) => items.isEmpty
          ? const Center(child: Text('Chưa có thao tác nào được ghi.'))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final log = items[index];
                final at = (log['created_at'] as Timestamp?)?.toDate();
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.history),
                  title: Text('${log['action']} · ${log['target_type']}'),
                  subtitle: Text(
                    '${log['detail'] ?? ''}\n'
                    'bởi ${(log['user_id'] as String?)?.substring(0, 8)}…'
                    '${at == null ? '' : ' · ${at.toLocal()}'}',
                  ),
                  isThreeLine: true,
                );
              },
            ),
    );
  }
}


