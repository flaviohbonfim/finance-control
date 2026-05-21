import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Para dev local troque pela URL abaixo conforme o ambiente:
//   iOS Simulator  → http://localhost:8000/api/v1
//   Android Emu    → http://10.0.2.2:8000/api/v1
//   Dispositivo    → http://<SEU_IP>:8000/api/v1
const _apiBase = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://finance.apti.dev/api/v1',
);

// On desktop, flutter_secure_storage requires Keychain entitlements that need
// a development signing certificate. shared_preferences is used instead —
// OS-level user isolation provides equivalent security on desktop.
bool get _isDesktop =>
    !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

const _tokenKey = 'jwt_token';

class ApiClient {
  static final ApiClient _instance = ApiClient._();
  factory ApiClient() => _instance;
  ApiClient._();

  final _secureStorage = const FlutterSecureStorage();

  late final Dio _dio = Dio(
    BaseOptions(
      baseUrl: _apiBase,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ),
  )..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (err, handler) {
          handler.next(err);
        },
      ),
    );

  Dio get dio => _dio;

  Future<void> saveToken(String token) async {
    if (_isDesktop) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
    } else {
      await _secureStorage.write(key: _tokenKey, value: token);
    }
  }

  Future<void> clearToken() async {
    if (_isDesktop) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
    } else {
      await _secureStorage.delete(key: _tokenKey);
    }
  }

  Future<String?> getToken() async {
    if (_isDesktop) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_tokenKey);
    } else {
      return _secureStorage.read(key: _tokenKey);
    }
  }

  Future<Response> get(String path, {Map<String, dynamic>? params}) =>
      _dio.get(path, queryParameters: params);

  Future<Response> post(String path, {dynamic data}) => _dio.post(path, data: data);
  Future<Response> put(String path, {dynamic data}) => _dio.put(path, data: data);
  Future<Response> delete(String path) => _dio.delete(path);
}

final api = ApiClient();
