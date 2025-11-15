import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:url_launcher/url_launcher_string.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/event.dart';
import '../models/task.dart';
import '../models/project.dart';
import '../models/notification.dart';
import '../models/department.dart';
import '../models/room.dart';
import '../models/task_comment.dart';

class ApiService extends ChangeNotifier {
  final String baseUrl;
  late Dio _dio;
  String? _token;
  UserModel? currentUser;
  List<EventModel> events = [];
  List<NotificationModel> notifications = [];
  List<DepartmentModel> departments = [];
  List<RoomModel> rooms = [];
  
  // Admin caches (lightweight)
  List<UserModel> _adminUsersCache = [];
  List<TaskModel> tasks = [];
  List<ProjectModel> projects = [];
  Map<String,int> taskStats = { 'todo':0,'in_progress':0,'completed':0 };
  // Reports state
  List<Map<String, dynamic>> reportEventsByMonth = [];
  List<Map<String, dynamic>> reportEventsByDepartment = [];

  ApiService({required this.baseUrl}) {
    _dio = Dio(BaseOptions(baseUrl: baseUrl));
  }

  void setToken(String? token) {
    _token = token;
    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    } else {
      _dio.options.headers.remove('Authorization');
    }
  }

  String? get token => _token;

  Future<bool> login(String email, String password) async {
    final res = await _dio.post('/api/auth/login', data: { 'email': email, 'password': password });
    final data = res.data;
    final token = data['token'] as String;
    final user = UserModel.fromJson(data['user']);
    setToken(token);
    currentUser = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    notifyListeners();
    return true;
  }
  Future<void> loadMe() async {
    if (_token == null) return;
    final res = await _dio.get('/api/auth/me');
    currentUser = UserModel.fromJson(res.data);
    notifyListeners();
  }

  Future<void> logout() async {
    currentUser = null;
    setToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    notifyListeners();
  }

  Future<void> fetchEvents() async {
    final res = await _dio.get('/api/events');
    final list = (res.data as List).map((e) => EventModel.fromJson(e)).toList();
    events = list;
    notifyListeners();
  }

  Future<EventModel> createEvent({required String title, DateTime? start, DateTime? end, String? description, String? roomId, List<String>? participantIds, String? departmentId, bool isGlobal = false}) async {
    final res = await _dio.post('/api/events', data: {
      'title': title,
      if (description != null) 'description': description,
      if (start != null) 'start_time': start.toIso8601String(),
      if (end != null) 'end_time': end.toIso8601String(),
      if (roomId != null) 'roomId': roomId,
      if (participantIds != null) 'participantIds': participantIds,
      if (departmentId != null) 'departmentId': departmentId,
      if (isGlobal) 'isGlobal': true,
    });
    final ev = EventModel.fromJson(res.data);
    events.insert(0, ev);
    notifyListeners();
    return ev;
  }

  Future<EventModel> updateEvent(String id, {String? title, DateTime? start, DateTime? end, String? description, String? roomId, String? status}) async {
    final res = await _dio.put('/api/events/$id', data: {
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (start != null) 'start_time': start.toIso8601String(),
      if (end != null) 'end_time': end.toIso8601String(),
      if (roomId != null) 'roomId': roomId,
      if (status != null) 'status': status,
    });
    final ev = EventModel.fromJson(res.data);
    events = events.map((e) => e.id == id ? ev : e).toList();
    notifyListeners();
    return ev;
  }

  Future<void> deleteEvent(String id) async {
    await _dio.delete('/api/events/$id');
    events.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  Future<void> fetchNotifications() async {
    final res = await _dio.get('/api/notifications');
    final list = (res.data as List).map((e) => NotificationModel.fromJson(e)).toList();
    notifications = list;
    notifyListeners();
  }

  // ============== Departments ==============
  Future<void> fetchDepartments() async {
    final res = await _dio.get('/api/departments');
    departments = (res.data as List).map((e) => DepartmentModel.fromJson(e)).toList();
    notifyListeners();
  }

  // Detail fetchers for deep-linking
  Future<EventModel> fetchEventById(String id) async {
    final res = await _dio.get('/api/events/$id');
    return EventModel.fromJson(res.data);
  }

  Future<TaskModel> fetchTaskById(String id) async {
    final res = await _dio.get('/api/tasks', queryParameters: { 'id': id, 'limit': 1 });
    final list = (res.data as List).map((e) => TaskModel.fromJson(e)).toList();
    if (list.isEmpty) throw Exception('Task not found');
    return list.first;
  }

  Future<DepartmentModel> createDepartment(String name, {String? description}) async {
    final res = await _dio.post('/api/departments', data: {
      'name': name,
      if (description != null) 'description': description,
    });
    final dep = DepartmentModel.fromJson(res.data);
    departments.add(dep);
    notifyListeners();
    return dep;
  }

  Future<DepartmentModel> updateDepartment(String id, {String? name, String? description}) async {
    final res = await _dio.put('/api/departments/$id', data: {
      if (name != null) 'name': name,
      if (description != null) 'description': description,
    });
    final dep = DepartmentModel.fromJson(res.data);
    departments = departments.map((d) => d.id == id ? dep : d).toList();
    notifyListeners();
    return dep;
  }

  Future<void> deleteDepartment(String id) async {
    await _dio.delete('/api/departments/$id');
    departments.removeWhere((d) => d.id == id);
    notifyListeners();
  }

  // ============== Rooms ==============
  Future<void> fetchRooms() async {
    final res = await _dio.get('/api/rooms');
    rooms = (res.data as List).map((e) => RoomModel.fromJson(e)).toList();
    notifyListeners();
  }

  Future<RoomModel> createRoom(String name, {String? location, int? capacity}) async {
    final res = await _dio.post('/api/rooms', data: {
      'name': name,
      if (location != null) 'location': location,
      if (capacity != null) 'capacity': capacity,
    });
    final room = RoomModel.fromJson(res.data);
    rooms.add(room);
    notifyListeners();
    return room;
  }

  Future<RoomModel> updateRoom(String id, {String? name, String? location, int? capacity}) async {
    final res = await _dio.put('/api/rooms/$id', data: {
      if (name != null) 'name': name,
      if (location != null) 'location': location,
      if (capacity != null) 'capacity': capacity,
    });
    final room = RoomModel.fromJson(res.data);
    rooms = rooms.map((r) => r.id == id ? room : r).toList();
    notifyListeners();
    return room;
  }

  Future<void> deleteRoom(String id) async {
    await _dio.delete('/api/rooms/$id');
    rooms.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  Future<void> markNotificationRead(String id) async {
    await _dio.put('/api/notifications/$id/read');
    await fetchNotifications();
  }

  Future<void> rsvp(String participantId, String status) async {
    await _dio.put('/api/participants/$participantId', data: {'status': status});
    await fetchEvents();
  }

  Future<void> requestParticipantAdjustment(String participantId, String note) async {
    await _dio.post('/api/participants/$participantId/request-adjustment', data: {
      'note': note,
    });
    await fetchEvents();
  }

  // ============== Admin APIs ==============
  Future<List<UserModel>> listUsers({int limit = 50, int offset = 0}) async {
    final res = await _dio.get('/api/users', queryParameters: {
      'limit': limit,
      'offset': offset,
    });
    final list = (res.data as List).map((e) => UserModel.fromJson(e)).toList();
    if (offset == 0) {
      _adminUsersCache = list;
    } else {
      _adminUsersCache.addAll(list);
    }
    return list;
  }

  Future<UserModel> adminCreateUser({required String name, required String email, required String password, String role = 'employee', String? departmentId}) async {
    final res = await _dio.post('/api/users', data: {
      'name': name,
      'email': email,
      'password': password,
      'role': role,
      if (departmentId != null) 'departmentId': departmentId,
    });
    final user = UserModel.fromJson(res.data);
    _adminUsersCache.insert(0, user);
    notifyListeners();
    return user;
  }

  Future<UserModel> adminUpdateUser(String id, {String? name, String? departmentId, String? password, String? role}) async {
    final res = await _dio.put('/api/users/$id', data: {
      if (name != null) 'name': name,
      if (departmentId != null) 'departmentId': departmentId,
      if (password != null) 'password': password,
      if (role != null) 'role': role,
    });
    final user = UserModel.fromJson(res.data);
    _adminUsersCache = _adminUsersCache.map((u) => u.id == id ? user : u).toList();
    notifyListeners();
    return user;
  }

  Future<void> adminDeleteUser(String id) async {
    await _dio.delete('/api/users/$id');
    _adminUsersCache.removeWhere((u) => u.id == id);
    notifyListeners();
  }

  Future<UserModel> updateProfile({String? name, String? contact, String? employeePin, String? avatarUrl}) async {
    if (currentUser == null) throw Exception('No user');
    final res = await _dio.put('/api/users/${currentUser!.id}', data: {
      if (name != null) 'name': name,
      if (contact != null) 'contact': contact,
      if (employeePin != null) 'employeePin': employeePin,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
    });
    currentUser = UserModel.fromJson(res.data);
    notifyListeners();
    return currentUser!;
  }

  // ============== Tasks / Projects ==============
  Future<void> fetchTasks({String? status, String? projectId}) async {
    final res = await _dio.get('/api/tasks', queryParameters: {
      if (status != null) 'status': status,
      if (projectId != null) 'projectId': projectId,
      'limit': 200,
    });
    tasks = (res.data as List).map((e) => TaskModel.fromJson(e)).toList();
    notifyListeners();
  }

  Future<TaskModel> createTask({required String title, String? description, DateTime? start, DateTime? end, String? status, String? projectId, String? priority, List<String>? labelIds, String assignmentType = 'open', int capacity = 1, String? departmentId, int? weight}) async {
    final res = await _dio.post('/api/tasks', data: {
      'title': title,
      if (description != null) 'description': description,
      if (start != null) 'start_time': start.toIso8601String(),
      if (end != null) 'end_time': end.toIso8601String(),
      if (status != null) 'status': status,
      if (projectId != null) 'projectId': projectId,
      if (priority != null) 'priority': priority,
      if (labelIds != null) 'labelIds': labelIds,
      'assignment_type': assignmentType,
      'capacity': capacity,
      if (departmentId != null) 'departmentId': departmentId,
      if (weight != null) 'weight': weight,
    });
    final task = TaskModel.fromJson(res.data);
    tasks.insert(0, task);
    notifyListeners();
    return task;
  }

  Future<TaskModel> updateTask(String id, {String? title, String? description, DateTime? start, DateTime? end, String? status, String? projectId, String? priority, List<String>? labelIds, String? assignmentType, int? capacity, int? weight}) async {
    final res = await _dio.put('/api/tasks/$id', data: {
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (start != null) 'start_time': start.toIso8601String(),
      if (end != null) 'end_time': end.toIso8601String(),
      if (status != null) 'status': status,
      if (projectId != null) 'projectId': projectId,
      if (priority != null) 'priority': priority,
      if (labelIds != null) 'labelIds': labelIds,
      if (assignmentType != null) 'assignment_type': assignmentType,
      if (capacity != null) 'capacity': capacity,
      if (weight != null) 'weight': weight,
    });
    final task = TaskModel.fromJson(res.data);
  tasks = tasks.map((t) => t.id == id ? task : t).toList();
    notifyListeners();
    return task;
  }

  Future<void> deleteTask(String id) async {
    await _dio.delete('/api/tasks/$id');
  tasks.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  Future<void> fetchTaskStats() async {
    final res = await _dio.get('/api/tasks/stats/summary');
    final data = res.data as Map<String, dynamic>;
    taskStats = {
      'todo': (data['todo'] ?? 0) as int,
      'in_progress': (data['in_progress'] ?? 0) as int,
      'completed': (data['completed'] ?? 0) as int,
    };
    notifyListeners();
  }

  // ============== Reports ==============
  Future<void> fetchReportEventsByMonth({int? year}) async {
    final res = await _dio.get('/api/reports/eventsByMonth', queryParameters: {
      if (year != null) 'year': year,
    });
    final list = (res.data as List).map<Map<String, dynamic>>((e) => {
      'month': (e['month'] is int) ? e['month'] : int.tryParse('${e['month']}') ?? 0,
      'count': (e['count'] is int) ? e['count'] : int.tryParse('${e['count']}') ?? 0,
    }).toList();
    reportEventsByMonth = list;
    notifyListeners();
  }

  Future<void> fetchReportEventsByDepartment() async {
    final res = await _dio.get('/api/reports/eventsByDepartment');
    final list = (res.data as List).map<Map<String, dynamic>>((e) => {
      'department': e['department']?.toString() ?? 'Khác',
      'count': (e['count'] is int) ? e['count'] : int.tryParse('${e['count']}') ?? 0,
    }).toList();
    reportEventsByDepartment = list;
    notifyListeners();
  }

  Future<void> fetchProjects() async {
    final res = await _dio.get('/api/projects');
    projects = (res.data as List).map((e) => ProjectModel.fromJson(e)).toList();
    notifyListeners();
  }

  Future<ProjectModel> createProject({required String name, String? description, bool createEvent = false, DateTime? eventStart, DateTime? eventEnd, String? roomId}) async {
    final res = await _dio.post('/api/projects', data: {
      'name': name,
      if (description != null) 'description': description,
      if (createEvent) 'createEvent': true,
      if (eventStart != null) 'eventStart': eventStart.toIso8601String(),
      if (eventEnd != null) 'eventEnd': eventEnd.toIso8601String(),
      if (roomId != null) 'roomId': roomId,
    });
    final p = ProjectModel.fromJson(res.data);
    projects.insert(0, p);
    notifyListeners();
    return p;
  }

  Future<ProjectModel> updateProject(String id, {String? name, String? description}) async {
    final res = await _dio.put('/api/projects/$id', data: {
      if (name != null) 'name': name,
      if (description != null) 'description': description,
    });
    final p = ProjectModel.fromJson(res.data);
    projects = projects.map((e) => e.id == id ? p : e).toList();
    notifyListeners();
    return p;
  }

  Future<void> deleteProject(String id) async {
    await _dio.delete('/api/projects/$id');
    projects.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  Future<UserModel> managerCreateEmployee({required String name, required String email, required String password}) async {
    final res = await _dio.post('/api/users', data: {
      'name': name,
      'email': email,
      'password': password,
      'role': 'employee',
      if (currentUser?.departmentId != null) 'departmentId': currentUser!.departmentId,
    });
    return UserModel.fromJson(res.data);
  }

  Future<void> rejectTask(String taskId, String reason) async {
    await _dio.post('/api/tasks/$taskId/reject', data: { 'reason': reason });
    await fetchTasks();
  }

  Future<void> approveTaskRejection(String taskId, {String? userId}) async {
    await _dio.post('/api/tasks/$taskId/rejection/approve', data: {
      if (userId != null) 'userId': userId,
    });
    await fetchTasks();
    await fetchNotifications();
  }

  Future<void> denyTaskRejection(String taskId, {String? userId}) async {
    await _dio.post('/api/tasks/$taskId/rejection/deny', data: {
      if (userId != null) 'userId': userId,
    });
    await fetchTasks();
    await fetchNotifications();
  }

  // Read-only list of tasks for a given project, without mutating global state
  Future<List<TaskModel>> listTasksForProject(String projectId) async {
    final res = await _dio.get('/api/tasks', queryParameters: {
      'projectId': projectId,
      'limit': 200,
    });
    return (res.data as List).map((e) => TaskModel.fromJson(e)).toList();
  }

  // ===== Task Assignment APIs =====
  Future<void> applyTask(String taskId) async {
    await _dio.post('/api/tasks/$taskId/apply');
    await fetchTasks();
  }

  Future<void> assignTask(String taskId, String userId) async {
    await _dio.post('/api/tasks/$taskId/assign', data: { 'userId': userId });
    await fetchTasks();
  }

  Future<void> acceptTask(String taskId) async {
    await _dio.post('/api/tasks/$taskId/accept');
    await fetchTasks();
  }

  Future<void> updateTaskProgress(String taskId, int progress) async {
    await _dio.put('/api/tasks/$taskId/progress', data: { 'progress': progress });
    await fetchTasks();
  }

  // ===== Task Comments =====
  Future<List<TaskCommentModel>> fetchTaskComments(String taskId) async {
    final res = await _dio.get('/api/tasks/$taskId/comments');
    final list = (res.data as List).map((e) => TaskCommentModel.fromJson(e as Map<String, dynamic>)).toList();
    return list;
  }

  Future<TaskCommentModel> addTaskComment(String taskId, String content) async {
    final res = await _dio.post('/api/tasks/$taskId/comments', data: { 'content': content });
    return TaskCommentModel.fromJson(res.data as Map<String, dynamic>);
  }

  // ===== System / Backup =====
  Future<void> downloadBackup() async {
    final endpoint = '/api/backup/create';
    if (kIsWeb) {
      final res = await _dio.get<List<int>>(endpoint, options: Options(responseType: ResponseType.bytes));
      final bytes = res.data;
      if (bytes == null) throw Exception('No data');
      String filename = 'backup.sql';
      final cd = res.headers.map['content-disposition']?.join(';') ?? '';
      final match = RegExp(r'filename\*=UTF-8\''"?([^";]+)"?|filename="?([^";]+)"?').firstMatch(cd);
      if (match != null) {
        filename = match.group(1) ?? match.group(2) ?? filename;
      }
      final blob = html.Blob([bytes], 'application/sql');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)..download = filename;
      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
      html.Url.revokeObjectUrl(url);
    } else {
      // Non-web: hiện tại chỉ thực hiện gọi để server tạo file, và thông báo.
      // Có thể mở rộng: lưu vào thư mục ứng dụng bằng path_provider.
      await _dio.get(endpoint, options: Options(responseType: ResponseType.bytes));
    }
  }

  // ===== Reports export (CSV) =====
  Future<void> exportEventsCSV({DateTime? from, DateTime? to}) async {
    // Build URL with optional from/to and token (for url_launcher without headers)
    final params = <String, String>{};
    if (from != null) params['from'] = from.toIso8601String();
    if (to != null) params['to'] = to.toIso8601String();
    if (_token != null) params['token'] = _token!;
    final qs = params.entries.map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}').join('&');
    final url = '${_dio.options.baseUrl}/api/reports/export/events${qs.isNotEmpty ? '?$qs' : ''}';

    // For web/mobile, use url_launcher so browser downloads respecting Content-Disposition
    final ok = await launchUrlString(url, mode: LaunchMode.externalApplication);
    if (!ok) {
      // Fallback: try direct GET to trigger download behavior (web may still need blob)
      if (kIsWeb) {
        final res = await _dio.get<List<int>>('/api/reports/export/events',
            queryParameters: params..remove('token'),
            options: Options(responseType: ResponseType.bytes));
        final bytes = res.data;
        if (bytes == null) throw Exception('No CSV data');
        String filename = 'events.csv';
        final cd = res.headers.map['content-disposition']?.join(';') ?? '';
        final match = RegExp(r'filename\*=UTF-8\''"?([^";]+)"?|filename="?([^";]+)"?').firstMatch(cd);
        if (match != null) filename = match.group(1) ?? match.group(2) ?? filename;
        final blob = html.Blob([bytes], 'text/csv');
        final blobUrl = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: blobUrl)..download = filename;
        html.document.body?.append(anchor);
        anchor.click();
        anchor.remove();
        html.Url.revokeObjectUrl(blobUrl);
      } else {
        // On mobile/desktop without a browser handler, simply issue the GET to ensure server reachable
        await _dio.get('/api/reports/export/events', queryParameters: params..remove('token'));
      }
    }
  }
}
