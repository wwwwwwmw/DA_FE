import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/api_service.dart';

class TaskStatusPage extends StatelessWidget {
  const TaskStatusPage({super.key});
  @override
  Widget build(BuildContext context) {
    final stats = context.watch<ApiService>().taskStats;
    final total = stats['todo']! + stats['in_progress']! + stats['completed']!;
    final sections = [
      _sec(stats['todo']!, total, Colors.orange, 'Cần làm'),
      _sec(stats['in_progress']!, total, Colors.blue, 'Đang làm'),
      _sec(stats['completed']!, total, Colors.green, 'Hoàn thành'),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Trạng thái Nhiệm vụ')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(children: [
          SizedBox(height: 220, child: PieChart(PieChartData(sections: sections))),
          const SizedBox(height: 16),
          _legendRow('Hoàn thành', stats['completed']!, Colors.green),
          _legendRow('Đang làm', stats['in_progress']!, Colors.blue),
          _legendRow('Cần làm', stats['todo']!, Colors.orange),
        ]),
      ),
    );
  }

  PieChartSectionData _sec(int value, int total, Color color, String title) {
    final pct = total == 0 ? 0 : (value / total) * 100;
    return PieChartSectionData(color: color, value: value.toDouble(), title: '${pct.round()}%', radius: 60, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold));
  }

  Widget _legendRow(String label, int value, Color color) {
    return Row(children: [
      Container(width: 14, height:14, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width:8),
      Text('$label: $value')
    ]);
  }
}
