import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/api_service.dart';

class EventReportPage extends StatefulWidget {
  const EventReportPage({super.key});

  @override
  State<EventReportPage> createState() => _EventReportPageState();
}

class _EventReportPageState extends State<EventReportPage> {
  bool _loading = true;
  int _year = DateTime.now().year;
  String _status = ''; // all
  String _type = '';   // all
  String? _departmentId; // all
  DateTimeRange? _range; // optional override of year

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = context.read<ApiService>();
      await api.fetchDepartments();
      await api.fetchReportEventsByMonth(
        year: _range == null ? _year : null,
        from: _range?.start,
        to: _range?.end,
        status: _status.isEmpty ? null : _status,
        type: _type.isEmpty ? null : _type,
        departmentId: _departmentId,
      );
      await api.fetchReportEventsByDepartment(
        from: _range?.start,
        to: _range?.end,
        status: _status.isEmpty ? null : _status,
        type: _type.isEmpty ? null : _type,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<BarChartGroupData> _buildBarGroups(List<Map<String, dynamic>> rows) {
    final map = {for (var m = 1; m <= 12; m++) m: 0};
    for (final r in rows) {
      final m = (r['month'] ?? 0) as int;
      final c = (r['count'] ?? 0) as int;
      if (map.containsKey(m)) map[m] = c;
    }
    return map.entries.map((e) {
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(toY: e.value.toDouble(), color: const Color(0xFF2D9CDB), width: 12, borderRadius: BorderRadius.circular(4)),
        ],
      );
    }).toList();
  }

  List<PieChartSectionData> _buildPieSections(List<Map<String, dynamic>> rows) {
    final total = rows.fold<int>(0, (a, b) => a + ((b['count'] ?? 0) as int));
    if (total == 0) {
      return [PieChartSectionData(value: 1, color: Colors.grey.shade300, title: 'No data', radius: 50, titleStyle: const TextStyle(fontSize: 10))];
    }
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.cyan,
      Colors.teal,
      Colors.indigo,
      Colors.amber,
      Colors.brown,
      Colors.pink,
      Colors.lime,
    ];
    return List.generate(rows.length, (i) {
      final r = rows[i];
      final v = (r['count'] ?? 0) as int;
      final pct = total == 0 ? 0.0 : (v * 100.0 / total);
      return PieChartSectionData(
        value: v.toDouble(),
        color: colors[i % colors.length],
        title: '${r['department']}: ${pct.toStringAsFixed(1)}% ',
        radius: 60,
        titleStyle: const TextStyle(fontSize: 11, color: Colors.white),
      );
    });
  }

  String _fmtRange(DateTimeRange r) {
    String fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
    return '${fmt(r.start)} → ${fmt(r.end)}';
  }

  @override
  Widget build(BuildContext context) {
    final api = context.watch<ApiService>();
    final byMonth = api.reportEventsByMonth;
    final byDept = api.reportEventsByDepartment;
    final departments = api.departments;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Báo cáo Lịch công tác'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Text('Chế độ:'), const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: _range == null ? 'year' : 'range',
                        items: const [
                          DropdownMenuItem(value: 'year', child: Text('Theo năm')),
                          DropdownMenuItem(value: 'range', child: Text('Khoảng thời gian')),
                        ],
                        onChanged: (v) async {
                          if (v == null) return;
                          setState(() {
                            if (v == 'year') { _range = null; }
                            else { _range ??= DateTimeRange(start: DateTime(_year,1,1), end: DateTime(_year,12,31,23,59,59)); }
                          });
                          await _load();
                        },
                      )
                    ]),
                    if (_range == null) Row(mainAxisSize: MainAxisSize.min, children: [
                      const Text('Năm:'), const SizedBox(width: 8),
                      DropdownButton<int>(
                        value: _year,
                        items: [for (var y = DateTime.now().year - 4; y <= DateTime.now().year + 1; y++) DropdownMenuItem(value: y, child: Text('$y'))],
                        onChanged: (v) async { if (v == null) return; setState(() => _year = v); await _load(); },
                      )
                    ])
                    else Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(_range == null ? 'Chọn khoảng thời gian' : _fmtRange(_range!)), const SizedBox(width: 8),
                      TextButton(
                        onPressed: () async {
                          final now = DateTime.now();
                          final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(now.year - 5),
                            lastDate: DateTime(now.year + 5),
                            initialDateRange: _range,
                          );
                          if (picked != null) { setState(() => _range = picked); await _load(); }
                        },
                        child: const Text('Chọn'),
                      )
                    ]),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Text('Trạng thái:'), const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: _status,
                        items: const [
                          DropdownMenuItem(value: '', child: Text('Tất cả')),
                          DropdownMenuItem(value: 'pending', child: Text('pending')),
                          DropdownMenuItem(value: 'approved', child: Text('approved')),
                          DropdownMenuItem(value: 'rejected', child: Text('rejected')),
                          DropdownMenuItem(value: 'completed', child: Text('completed')),
                        ],
                        onChanged: (v) async { setState(()=>_status = v ?? ''); await _load(); },
                      ),
                    ]),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Text('Loại:'), const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: _type,
                        items: const [
                          DropdownMenuItem(value: '', child: Text('Tất cả')),
                          DropdownMenuItem(value: 'work', child: Text('Lịch công tác')),
                          DropdownMenuItem(value: 'meeting', child: Text('Lịch họp')),
                        ],
                        onChanged: (v) async { setState(()=>_type = v ?? ''); await _load(); },
                      ),
                    ]),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Text('Phòng ban:'), const SizedBox(width: 8),
                      DropdownButton<String?>(
                        value: _departmentId,
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Tất cả')),
                          for (final d in departments) DropdownMenuItem(value: d.id, child: Text(d.name)),
                        ],
                        onChanged: (v) async { setState(()=>_departmentId = v); await _load(); },
                      ),
                    ]),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final from = _range?.start ?? DateTime(_year, 1, 1);
                        final to = _range?.end ?? DateTime(_year, 12, 31, 23, 59, 59);
                        await context.read<ApiService>().exportEventsCSV(
                          from: from,
                          to: to,
                          status: _status.isEmpty? null : _status,
                          type: _type.isEmpty? null : _type,
                          departmentId: _departmentId,
                        );
                      },
                      icon: const Icon(Icons.download),
                      label: const Text('Xuất file CSV'),
                    )
                  ]),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Số lượng lịch theo tháng', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 220,
                          child: BarChart(
                            BarChartData(
                              gridData: const FlGridData(show: false),
                              titlesData: FlTitlesData(
                                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      final m = value.toInt();
                                      if (m < 1 || m > 12) return const SizedBox.shrink();
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 4.0),
                                        child: Text('$m', style: const TextStyle(fontSize: 10)),
                                      );
                                    },
                                  ),
                                ),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              ),
                              barGroups: _buildBarGroups(byMonth),
                              borderData: FlBorderData(show: false),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Phân bố lịch theo phòng ban', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 260,
                          child: PieChart(
                            PieChartData(
                              sections: _buildPieSections(byDept),
                              sectionsSpace: 2,
                              centerSpaceRadius: 40,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: byDept.map((e) => Chip(label: Text('${e['department']}: ${e['count']}'))).toList(),
                        )
                      ]),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
