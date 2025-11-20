import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';

class SystemTab extends StatefulWidget {
  const SystemTab({super.key});
  @override
  State<SystemTab> createState() => _SystemTabState();
}

class _SystemTabState extends State<SystemTab> {
  bool _busy = false;

  Future<void> _doBackup() async {
    setState(() => _busy = true);
    final api = context.read<ApiService>();
    try {
      await api.saveBackupFile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã tạo & lưu file backup (.backup)')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi sao lưu: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmRestore() async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) {
      return AlertDialog(
        title: const Text('Phục hồi toàn bộ dữ liệu'),
        content: const Text('Thao tác này sẽ ghi đè toàn bộ cơ sở dữ liệu hiện tại bằng nội dung trong file .backup. Bạn có chắc chắn?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Đồng ý')),
        ],
      );
    });
    if (ok != true) return;
    await _doRestore();
  }

  Future<void> _doRestore() async {
    setState(() => _busy = true);
    final api = context.read<ApiService>();
    try {
      await api.uploadRestore();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phục hồi hoàn tất (ghi đè). Khởi động lại ứng dụng nếu cần.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi phục hồi: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Công cụ hệ thống', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.backup_outlined),
                  title: const Text('Sao lưu toàn bộ CSDL (.backup)'),
                  subtitle: const Text('Tạo snapshot custom format PostgreSQL'),
                  trailing: _busy ? const SizedBox(width:24,height:24,child: CircularProgressIndicator(strokeWidth:2)) : null,
                  onTap: _busy ? null : _doBackup,
                ),
                const Divider(height:0),
                ListTile(
                  leading: const Icon(Icons.restore_outlined),
                  title: const Text('Phục hồi snapshot (.backup)'),
                  subtitle: const Text('Ghi đè toàn bộ dữ liệu hiện tại'),
                  trailing: _busy ? const SizedBox(width:24,height:24,child: CircularProgressIndicator(strokeWidth:2)) : null,
                  onTap: _busy ? null : _confirmRestore,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (!kIsWeb) const Text('Lưu ý: Trên mobile/desktop file sẽ lưu vào thư mục tải xuống / hộp thoại lưu.'),
        ],
      ),
    );
  }
}
