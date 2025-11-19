// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../models/user.dart';
import '../../models/department.dart';

class AdminUsersTab extends StatefulWidget {
  const AdminUsersTab({super.key});

  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab> {
  final _scrollCtrl = ScrollController();
  bool _loading = false;
  int _offset = 0;
  final List<UserModel> _users = [];

  @override
  void initState() {
    super.initState();
    _fetch();
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200 && !_loading) {
        _fetch();
      }
    });
  }

  Future<void> _fetch({bool refresh = false}) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      if (refresh) { _offset = 0; _users.clear(); }
      final api = context.read<ApiService>();
      final result = await api.listUsers(limit: 50, offset: _offset);
      setState(() {
  _users.addAll(result);
  _offset += result.length;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tải người dùng thất bại: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showCreate() async {
    // Preload departments for dropdown
    final api = context.read<ApiService>();
    if (api.departments.isEmpty) {
      await api.fetchDepartments();
    }
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String role = 'employee';
    DepartmentModel? dep;
    final ok = await showDialog<bool>(context: context, builder: (c) {
      return StatefulBuilder(builder: (c, setStateDialog) {
        return AlertDialog(
          title: const Text('Thêm người dùng'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Tên *')),
              TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email *'), keyboardType: TextInputType.emailAddress),
              TextField(controller: passCtrl, decoration: const InputDecoration(labelText: 'Mật khẩu *'), obscureText: true),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                  initialValue: role,
                decoration: const InputDecoration(labelText: 'Vai trò'),
                items: const [
                  DropdownMenuItem(value: 'employee', child: Text('Nhân viên')),
                  DropdownMenuItem(value: 'manager', child: Text('Quản lý')),
                  DropdownMenuItem(value: 'admin', child: Text('Quản trị')),
                ],
                onChanged: (v) => setStateDialog(() => role = v ?? 'employee'),
              ),
              DropdownButtonFormField<DepartmentModel>(
                  initialValue: dep,
                decoration: const InputDecoration(labelText: 'Phòng ban'),
                items: api.departments.map((d) => DropdownMenuItem(value: d, child: Text(d.name))).toList(),
                onChanged: (v) => setStateDialog(() => dep = v),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy')),
            ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Lưu')),
          ],
        );
      });
    });
    if (ok == true && nameCtrl.text.trim().isNotEmpty && emailCtrl.text.trim().isNotEmpty && passCtrl.text.isNotEmpty) {
      try {
        if (!context.mounted) return;
        await api.adminCreateUser(name: nameCtrl.text.trim(), email: emailCtrl.text.trim(), password: passCtrl.text, role: role, departmentId: dep?.id);
        if (!mounted) return;
        await _fetch(refresh: true); // ensure list fresh
      } catch (e) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tạo thất bại: $e')));
      }
    }
  }

  Future<void> _showEdit(UserModel user) async {
    final api = context.read<ApiService>();
    if (api.departments.isEmpty) { await api.fetchDepartments(); }
    final nameCtrl = TextEditingController(text: user.name);
    final passCtrl = TextEditingController();
    String role = user.role;
    DepartmentModel? dep = api.departments.firstWhere((d) => d.id == user.departmentId, orElse: () => DepartmentModel(id: '', name: '')); // placeholder null
    if (dep.id.isEmpty) dep = null;
    final ok = await showDialog<bool>(context: context, builder: (c) {
      return StatefulBuilder(builder: (c, setStateDialog) {
        return AlertDialog(
          title: const Text('Sửa người dùng'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Tên *')),
              TextField(controller: passCtrl, decoration: const InputDecoration(labelText: 'Mật khẩu (đổi nếu nhập)'), obscureText: true),
              DropdownButtonFormField<String>(
                  initialValue: role,
                decoration: const InputDecoration(labelText: 'Vai trò'),
                items: const [
                  DropdownMenuItem(value: 'employee', child: Text('Nhân viên')),
                  DropdownMenuItem(value: 'manager', child: Text('Quản lý')),
                  DropdownMenuItem(value: 'admin', child: Text('Quản trị')),
                ],
                onChanged: (v) => setStateDialog(() => role = v ?? role),
              ),
              DropdownButtonFormField<DepartmentModel>(
                  initialValue: dep,
                decoration: const InputDecoration(labelText: 'Phòng ban'),
                items: api.departments.map((d) => DropdownMenuItem(value: d, child: Text(d.name))).toList(),
                onChanged: (v) => setStateDialog(() => dep = v),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy')),
            ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Cập nhật')),
          ],
        );
      });
    });
    if (ok == true && nameCtrl.text.trim().isNotEmpty) {
      try {
        if (!context.mounted) return;
        await api.adminUpdateUser(user.id, name: nameCtrl.text.trim(), role: role, departmentId: dep?.id.isEmpty == true ? null : dep?.id, password: passCtrl.text.isEmpty ? null : passCtrl.text);
        if (!mounted) return;
        await _fetch(refresh: true);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cập nhật thất bại: $e')));
      }
    }
  }

  Future<void> _delete(UserModel user) async {
    final api = context.read<ApiService>();
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Xóa người dùng'),
      content: Text('Bạn có chắc chắn xóa "${user.name}"?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy')),
        ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Xóa')),
      ],
    ));
    if (ok == true) { try { if (!context.mounted) return; await api.adminDeleteUser(user.id); await _fetch(refresh: true); } catch (e) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Xóa thất bại: $e'))); } }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () => _fetch(refresh: true),
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.only(bottom: 96, top: 8),
            itemCount: _users.length + 1,
            itemBuilder: (_, i) {
              if (i >= _users.length) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(child: _loading ? const CircularProgressIndicator() : const SizedBox.shrink()),
                );
              }
              final u = _users[i];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text(u.name.isNotEmpty ? u.name[0].toUpperCase() : '?')),
                  title: Text(u.name),
                  subtitle: Text('${u.email} • ${u.role}'),
                  onTap: () => _showEdit(u),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') _showEdit(u);
                      if (v == 'delete') _delete(u);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Sửa')),
                      PopupMenuItem(value: 'delete', child: Text('Xóa')),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            heroTag: 'fab-admin-users',
            onPressed: _showCreate,
            child: const Icon(Icons.add),
          ),
        )
      ],
    );
  }
}
