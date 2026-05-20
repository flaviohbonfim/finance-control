import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Para dev local troque pela URL abaixo conforme o ambiente:
//   iOS Simulator  → http://localhost:8000/api/v1
//   Android Emu    → http://10.0.2.2:8000/api/v1
//   Dispositivo    → http://<SEU_IP>:8000/api/v1
const _apiBase = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://finance.apti.dev/api/v1',
);

class ApiClient {
  static final ApiClient _instance = ApiClient._();
  factory ApiClient() => _instance;
  ApiClient._();

  final _storage = const FlutterSecureStorage();

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
          final token = await _storage.read(key: 'jwt_token');
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

  Future<void> saveToken(String token) => _storage.write(key: 'jwt_token', value: token);
  Future<void> clearToken() => _storage.delete(key: 'jwt_token');
  Future<String?> getToken() => _storage.read(key: 'jwt_token');

  Future<Response> get(String path, {Map<String, dynamic>? params}) =>
      _dio.get(path, queryParameters: params);

  Future<Response> post(String path, {dynamic data}) => _dio.post(path, data: data);
  Future<Response> put(String path, {dynamic data}) => _dio.put(path, data: data);
  Future<Response> delete(String path) => _dio.delete(path);
}

final api = ApiClient();
