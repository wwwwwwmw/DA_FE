// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../models/room.dart';

class RoomsTab extends StatefulWidget {
  const RoomsTab({super.key});
  @override
  State<RoomsTab> createState() => _RoomsTabState();
}

class _RoomsTabState extends State<RoomsTab> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try { await context.read<ApiService>().fetchRooms(); } finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _showCreate() async {
    final nameCtrl = TextEditingController();
    final locCtrl = TextEditingController();
    final capCtrl = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Thêm phòng họp'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Tên *')),
        TextField(controller: locCtrl, decoration: const InputDecoration(labelText: 'Vị trí')),
        TextField(controller: capCtrl, decoration: const InputDecoration(labelText: 'Sức chứa'), keyboardType: TextInputType.number),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy')),
        ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Lưu')),
      ],
    ));
    if (ok == true && nameCtrl.text.trim().isNotEmpty) {
      final cap = int.tryParse(capCtrl.text.trim());
      if (!context.mounted) return;
      await context.read<ApiService>().createRoom(nameCtrl.text.trim(), location: locCtrl.text.trim().isEmpty ? null : locCtrl.text.trim(), capacity: cap);
      if (!mounted) return;
    }
  }

  Future<void> _showEdit(RoomModel room) async {
    final nameCtrl = TextEditingController(text: room.name);
    final locCtrl = TextEditingController(text: room.location ?? '');
    final capCtrl = TextEditingController(text: room.capacity?.toString() ?? '');
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Sửa phòng họp'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Tên *')),
        TextField(controller: locCtrl, decoration: const InputDecoration(labelText: 'Vị trí')),
        TextField(controller: capCtrl, decoration: const InputDecoration(labelText: 'Sức chứa'), keyboardType: TextInputType.number),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy')),
        ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Cập nhật')),
      ],
    ));
    if (ok == true && nameCtrl.text.trim().isNotEmpty) {
      final cap = int.tryParse(capCtrl.text.trim());
      if (!context.mounted) return;
      await context.read<ApiService>().updateRoom(room.id, name: nameCtrl.text.trim(), location: locCtrl.text.trim().isEmpty ? null : locCtrl.text.trim(), capacity: cap);
      if (!mounted) return;
    }
  }

  Future<void> _delete(RoomModel room) async {
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Xóa phòng họp'),
      content: Text('Bạn có chắc chắn xóa "${room.name}"?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy')),
        ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Xóa')),
      ],
    ));
    if (ok == true) {
      if (!context.mounted) return;
      await context.read<ApiService>().deleteRoom(room.id);
      if (!mounted) return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<ApiService>();
    final list = service.rooms;
    return Stack(children: [
      RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          padding: const EdgeInsets.only(bottom: 96, top: 8),
          itemCount: list.length,
          itemBuilder: (c,i){
            final room = list[i];
            return Card(
              child: ListTile(
                leading: const Icon(Icons.meeting_room),
                title: Text(room.name),
                subtitle: Text([
                  if(room.location!=null) room.location!,
                  if(room.capacity!=null) 'Sức chứa: ${room.capacity}'
                ].join(' • ')),
                onTap: () => _showEdit(room),
                trailing: PopupMenuButton<String>(
                  onSelected: (v){ if (v=='edit') _showEdit(room); if (v=='delete') _delete(room); },
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
      if(_loading) const Positioned.fill(child: Center(child: CircularProgressIndicator())),
      Positioned(
        bottom: 16,
        right: 16,
        child: FloatingActionButton(heroTag: 'fab-admin-rooms', onPressed: _showCreate, child: const Icon(Icons.add)),
      )
    ]);
  }
}
