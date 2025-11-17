import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../reports/event_report_page.dart';
import '../../services/api_service.dart';
import '../../models/event.dart';

class EventsAdminTab extends StatefulWidget {
  const EventsAdminTab({super.key});
  @override
  State<EventsAdminTab> createState() => _EventsAdminTabState();
}

class _EventsAdminTabState extends State<EventsAdminTab> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try { await context.read<ApiService>().fetchEvents(); } finally { if(mounted) setState(()=>_loading=false); }
  }

  Future<void> _showCreate() async {
    DateTime? start; DateTime? end;
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    Future<void> pickStart() async {
      final date = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: DateTime.now());
      if (date == null) return; final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
      if (time != null) start = DateTime(date.year,date.month,date.day,time.hour,time.minute);
      setState((){});
    }
    Future<void> pickEnd() async {
      final date = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: start ?? DateTime.now());
      if (date == null) return; final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
      if (time != null) end = DateTime(date.year,date.month,date.day,time.hour,time.minute);
      setState((){});
    }
    final ok = await showDialog<bool>(context: context, builder: (c) => StatefulBuilder(builder: (c,setStateDialog){
      return AlertDialog(
        title: const Text('Tạo lịch'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Tiêu đề *')),
          TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Mô tả')),
          const SizedBox(height:8),
          Row(children:[Expanded(child: Text(start==null? 'Chọn bắt đầu':'Bắt đầu: ${start!.toLocal()}')), TextButton(onPressed: () async {await pickStart(); setStateDialog((){});}, child: const Text('Chọn'))]),
          Row(children:[Expanded(child: Text(end==null? 'Chọn kết thúc':'Kết thúc: ${end!.toLocal()}')), TextButton(onPressed: () async {await pickEnd(); setStateDialog((){});}, child: const Text('Chọn'))]),
        ])),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(c,false), child: const Text('Hủy')),
          ElevatedButton(onPressed: ()=>Navigator.pop(c,true), child: const Text('Lưu')),
        ],
      );
    }));
    if (ok == true && titleCtrl.text.trim().isNotEmpty && start!=null && end!=null) {
      await context.read<ApiService>().createEvent(title: titleCtrl.text.trim(), description: descCtrl.text.trim().isEmpty? null: descCtrl.text.trim(), start: start, end: end);
      if (!mounted) return;
    }
  }

  Future<void> _showEdit(EventModel ev) async {
    DateTime? start = ev.startTime; DateTime? end = ev.endTime;
    final titleCtrl = TextEditingController(text: ev.title);
    final descCtrl = TextEditingController(text: ev.description ?? '');
    Future<void> pickStart() async {
      final date = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: start ?? DateTime.now());
      if (date == null) return; final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(start ?? DateTime.now()));
      if (time != null) start = DateTime(date.year,date.month,date.day,time.hour,time.minute); setState((){});
    }
    Future<void> pickEnd() async {
      final date = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: end ?? start ?? DateTime.now());
      if (date == null) return; final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(end ?? DateTime.now()));
      if (time != null) end = DateTime(date.year,date.month,date.day,time.hour,time.minute); setState((){});
    }
    final ok = await showDialog<bool>(context: context, builder: (c) => StatefulBuilder(builder:(c,setStateDialog){
      return AlertDialog(
        title: const Text('Sửa lịch'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Tiêu đề *')),
          TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Mô tả')),
          const SizedBox(height:8),
          Row(children:[Expanded(child: Text(start==null? 'Chọn bắt đầu':'Bắt đầu: ${start!.toLocal()}')), TextButton(onPressed: () async {await pickStart(); setStateDialog((){});}, child: const Text('Chọn'))]),
          Row(children:[Expanded(child: Text(end==null? 'Chọn kết thúc':'Kết thúc: ${end!.toLocal()}')), TextButton(onPressed: () async {await pickEnd(); setStateDialog((){});}, child: const Text('Chọn'))]),
        ])),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(c,false), child: const Text('Hủy')),
          ElevatedButton(onPressed: ()=>Navigator.pop(c,true), child: const Text('Cập nhật')),
        ],
      );
    }));
    if (ok == true && titleCtrl.text.trim().isNotEmpty && start!=null && end!=null) {
      await context.read<ApiService>().updateEvent(ev.id, title: titleCtrl.text.trim(), description: descCtrl.text.trim().isEmpty? null: descCtrl.text.trim(), start: start, end: end);
      if (!mounted) return;
    }
  }

  Future<void> _delete(EventModel ev) async {
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Xóa lịch'),
      content: Text('Bạn có chắc chắn xóa "${ev.title}"?'),
      actions: [TextButton(onPressed: ()=>Navigator.pop(c,false), child: const Text('Hủy')), ElevatedButton(onPressed: ()=>Navigator.pop(c,true), child: const Text('Xóa'))],
    ));
    if (ok == true) await context.read<ApiService>().deleteEvent(ev.id);
    if (!mounted) return;
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<ApiService>();
    final list = service.events;
    return Stack(children: [
      RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          padding: const EdgeInsets.only(bottom: 80),
            itemCount: list.length,
            itemBuilder: (c,i){
              final ev = list[i];
              final startStr = ev.startTime.toLocal().toString();
              final endStr = ev.endTime.toLocal().toString();
              return ListTile(
                title: Text(ev.title),
                subtitle: Text('$startStr → $endStr\nTrạng thái: ${ev.status}'),
                onTap: ()=>_showEdit(ev),
                isThreeLine: true,
                trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: ()=>_delete(ev)),
              );
            }
        ),
      ),
      if(_loading) const Positioned.fill(child: Center(child: CircularProgressIndicator())),
      Positioned(
        bottom: 16,
        right: 16,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            FloatingActionButton.extended(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EventReportPage())),
              icon: const Icon(Icons.insights),
              label: const Text('Báo cáo'),
            ),
            const SizedBox(height: 12),
            FloatingActionButton(onPressed: _showCreate, child: const Icon(Icons.add)),
          ],
        ),
      ),
    ]);
  }
}
