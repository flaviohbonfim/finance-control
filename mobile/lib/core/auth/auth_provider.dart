import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../api/models.dart';

class AuthState {
  final User? user;
  final bool loading;
  final String? error;

  const AuthState({this.user, this.loading = false, this.error});

  bool get isAuthenticated => user != null;
  AuthState copyWith({User? user, bool? loading, String? error, bool clearUser = false}) =>
      AuthState(
        user: clearUser ? null : (user ?? this.user),
        loading: loading ?? this.loading,
        error: error,
      );
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  Future<void> checkAuth() async {
    final token = await api.getToken();
    if (token == null) return;
    try {
      final res = await api.get('/auth/me');
      state = AuthState(user: User.fromJson(res.data));
    } catch (_) {
      await api.clearToken();
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final res = await api.post('/auth/login', data: {'email': email, 'password': password});
      final token = res.data['access_token'];
      await api.saveToken(token);
      state = AuthState(user: User.fromJson(res.data['user']));
    } on Exception catch (e) {
      final msg = _extractError(e);
      state = state.copyWith(loading: false, error: msg);
    }
  }

  Future<void> logout() async {
    await api.clearToken();
    state = const AuthState();
  }

  String _extractError(Exception e) {
    final str = e.toString();
    if (str.contains('401') || str.contains('Incorrect')) return 'Email ou senha incorretos';
    if (str.contains('SocketException') || str.contains('Connection')) return 'Sem conexão com o servidor';
    return 'Erro ao fazer login';
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
