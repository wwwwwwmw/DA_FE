import 'dart:math';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/task.dart';
import '../models/notification.dart' as model;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    // Timezone init (safe to call multiple times)
    tz.initializeTimeZones();
    // tz.local will follow device timezone; explicit setLocalLocation not required here.

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const settings = InitializationSettings(android: androidInit, iOS: iosInit);
    await _plugin.initialize(settings);

    // Request runtime permissions where needed (Android 13+, iOS)
    await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    await _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, badge: true, sound: true);
    _initialized = true;
  }

  Future<void> showNow({required String title, required String body, String? payload}) async {
    const androidDetails = AndroidNotificationDetails(
      'general_channel', 'General',
      importance: Importance.high, priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);
    await _plugin.show(_randomId(), title, body, details, payload: payload);
  }

  Future<void> scheduleAt({
    required int id,
    required DateTime whenLocal,
    required String title,
    required String body,
    String? payload,
  }) async {
    final tzTime = tz.TZDateTime.from(whenLocal, tz.local);
    if (whenLocal.isBefore(DateTime.now())) return; // don't schedule past
    const androidDetails = AndroidNotificationDetails(
      'schedule_channel', 'Schedules',
      importance: Importance.high, priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
    );
  }

  int _randomId() => Random().nextInt(0x7FFFFFFF);

  int _taskIdBase(String taskId) => taskId.hashCode & 0x7FFFFFFF;
  int _taskStartId(String taskId) => _taskIdBase(taskId);
  int _taskEndId(String taskId) => (_taskIdBase(taskId) ^ 0x13579);

  Future<void> cancelTaskReminders(String taskId) async {
    await _plugin.cancel(_taskStartId(taskId));
    await _plugin.cancel(_taskEndId(taskId));
  }

  Future<void> scheduleTaskReminders(Iterable<TaskModel> tasks, {required String? currentUserId}) async {
    if (currentUserId == null) return;
    for (final t in tasks) {
      // only tasks assigned to current user
      final assigned = t.assignments.any((a) => a.userId == currentUserId && a.status != 'rejected');
      if (!assigned) continue;
      // cancel previous scheduling to avoid duplicates
      await cancelTaskReminders(t.id);

      if (t.startTime != null) {
        final when = t.startTime!.subtract(const Duration(minutes: 30));
        await scheduleAt(
          id: _taskStartId(t.id),
          whenLocal: when,
          title: 'Sắp bắt đầu: ${t.title}',
          body: 'Nhiệm vụ của bạn sẽ bắt đầu sau 30 phút.',
        );
      }
      if (t.endTime != null) {
        final when = t.endTime!.subtract(const Duration(minutes: 30));
        await scheduleAt(
          id: _taskEndId(t.id),
          whenLocal: when,
          title: 'Sắp kết thúc: ${t.title}',
          body: 'Nhiệm vụ của bạn sẽ kết thúc sau 30 phút.',
        );
      }
    }
  }

  // Store and emit new server-side notifications (avoid duplicates across restarts)
  Future<void> showNewServerNotifications(Iterable<model.NotificationModel> items) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'notified_server_ids';
    final saved = prefs.getStringList(key) ?? <String>[];
    final known = saved.toSet();
    bool changed = false;
    for (final n in items) {
      if (known.contains(n.id)) continue;
      await showNow(title: n.title, body: n.message);
      known.add(n.id);
      changed = true;
    }
    if (changed) {
      await prefs.setStringList(key, known.toList());
    }
  }
}
