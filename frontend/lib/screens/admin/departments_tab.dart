// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../models/department.dart';

class DepartmentsTab extends StatefulWidget {
  const DepartmentsTab({super.key});

  @override
  State<DepartmentsTab> createState() => _DepartmentsTabState();
}

class _DepartmentsTabState extends State<DepartmentsTab> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      await context.read<ApiService>().fetchDepartments();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showCreate() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (c) {
      return AlertDialog(
        title: const Text('Thêm phòng ban'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Tên *')),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Mô tả')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy')),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Lưu')),
        ],
      );
    });
    if (ok == true && nameCtrl.text.trim().isNotEmpty) {
      if (!context.mounted) return;
      await context.read<ApiService>().createDepartment(nameCtrl.text.trim(), description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim());
      if (!mounted) return;
    }
  }

  Future<void> _showEdit(DepartmentModel dep) async {
    final nameCtrl = TextEditingController(text: dep.name);
    final descCtrl = TextEditingController(text: dep.description ?? '');
    final ok = await showDialog<bool>(context: context, builder: (c) {
      return AlertDialog(
        title: const Text('Sửa phòng ban'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Tên *')),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Mô tả')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy')),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Cập nhật')),
        ],
      );
    });
    if (ok == true && nameCtrl.text.trim().isNotEmpty) {
      if (!context.mounted) return;
      await context.read<ApiService>().updateDepartment(dep.id, name: nameCtrl.text.trim(), description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim());
      if (!mounted) return;
    }
  }

  Future<void> _delete(DepartmentModel dep) async {
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Xóa phòng ban'),
      content: Text('Bạn có chắc chắn xóa "${dep.name}"?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy')),
        ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Xóa')),
      ],
    ));
    if (ok == true) {
      if (!context.mounted) return;
      await context.read<ApiService>().deleteDepartment(dep.id);
      if (!mounted) return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<ApiService>();
    final list = service.departments;
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _load,
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 96, top: 8),
            itemCount: list.length,
            itemBuilder: (c, i) {
              final dep = list[i];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.apartment),
                  title: Text(dep.name),
                  subtitle: dep.description == null ? null : Text(dep.description!),
                  onTap: () => _showEdit(dep),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') _showEdit(dep);
                      if (v == 'delete') _delete(dep);
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
        if (_loading) const Positioned.fill(child: Center(child: CircularProgressIndicator())),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            heroTag: 'fab-admin-departments',
            onPressed: _showCreate,
            child: const Icon(Icons.add),
          ),
        )
      ],
    );
  }
}
