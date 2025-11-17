import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';

class SystemTab extends StatelessWidget {
  const SystemTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Công cụ hệ thống', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.backup_outlined),
            label: const Text('Sao lưu dữ liệu'),
            onPressed: () async {
              final api = context.read<ApiService>();
              try {
                await api.downloadBackup();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đang tải file backup...')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Lỗi sao lưu: $e')), 
                  );
                }
              }
            },
          ),
          const SizedBox(height: 8),
          if (!kIsWeb) const Text('Lưu ý: Hiện hỗ trợ tải về tốt nhất trên Web.'),
        ],
      ),
    );
  }
}
