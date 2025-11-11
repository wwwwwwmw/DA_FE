import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/event.dart';
import '../models/notification.dart';

class ApiService extends ChangeNotifier {
  final String baseUrl;
  late Dio _dio;
  String? _token;
  UserModel? currentUser;
  List<EventModel> events = [];
  List<NotificationModel> notifications = [];

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

  Future<void> fetchNotifications() async {
    final res = await _dio.get('/api/notifications');
    final list = (res.data as List).map((e) => NotificationModel.fromJson(e)).toList();
    notifications = list;
    notifyListeners();
  }
}
