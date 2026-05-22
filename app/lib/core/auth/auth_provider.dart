import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../api/api_client.dart';
import '../api/models.dart';
import '../api/providers.dart';

const _googleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID', defaultValue: '');
const _googleIosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID', defaultValue: '');

GoogleSignIn? _googleSignInInstance;
GoogleSignIn _getGoogleSignIn() => _googleSignInInstance ??= GoogleSignIn(
      clientId: _googleIosClientId.isNotEmpty ? _googleIosClientId : null,
      serverClientId: _googleClientId.isNotEmpty ? _googleClientId : null,
      scopes: ['email', 'profile'],
    );

class AuthState {
  final User? user;
  final bool loading;
  final String? error;
  final bool emailNotVerified;
  final String? unverifiedEmail;

  const AuthState({
    this.user,
    this.loading = false,
    this.error,
    this.emailNotVerified = false,
    this.unverifiedEmail,
  });

  bool get isAuthenticated => user != null;
  bool get isVerified => user?.isVerified ?? false;

  AuthState copyWith({
    User? user,
    bool? loading,
    String? error,
    bool? emailNotVerified,
    String? unverifiedEmail,
    bool clearUser = false,
    bool clearError = false,
    bool clearUnverified = false,
  }) =>
      AuthState(
        user: clearUser ? null : (user ?? this.user),
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
        emailNotVerified: clearUnverified ? false : (emailNotVerified ?? this.emailNotVerified),
        unverifiedEmail: clearUnverified ? null : (unverifiedEmail ?? this.unverifiedEmail),
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
    state = state.copyWith(loading: true, error: null, clearError: true, clearUnverified: true);
    try {
      final res = await api.post('/auth/login', data: {'email': email, 'password': password});
      final token = res.data['access_token'];
      await api.saveToken(token);
      _invalidateData();
      state = AuthState(user: User.fromJson(res.data['user']));
    } on Exception catch (e) {
      final str = e.toString();
      if (str.contains('403') || str.contains('EMAIL_NOT_VERIFIED')) {
        state = state.copyWith(
          loading: false,
          clearError: true,
          emailNotVerified: true,
          unverifiedEmail: email,
        );
      } else {
        state = state.copyWith(loading: false, error: _extractLoginError(e));
      }
    }
  }

  Future<void> register(String name, String email, String password) async {
    state = state.copyWith(loading: true, error: null, clearError: true);
    try {
      final res = await api.post('/auth/register',
          data: {'name': name, 'email': email, 'password': password});
      final token = res.data['access_token'];
      await api.saveToken(token);
      _invalidateData();
      state = AuthState(user: User.fromJson(res.data['user']));
    } on Exception catch (e) {
      final msg = _extractApiError(e, fallback: 'Erro ao criar conta');
      state = state.copyWith(loading: false, error: msg);
    }
  }

  Future<String?> verifyEmail(String email, String code) async {
    try {
      await api.post('/auth/verify-email', data: {'email': email, 'code': code});
      if (state.user != null) {
        // Refresh user to reflect is_verified=true
        final res = await api.get('/auth/me');
        state = AuthState(user: User.fromJson(res.data));
      }
      return null;
    } on Exception catch (e) {
      final str = e.toString();
      if (str.contains('400')) return 'Código inválido ou expirado';
      return 'Erro ao verificar email';
    }
  }

  Future<String?> resendVerification(String email) async {
    try {
      await api.post('/auth/resend-verification', data: {'email': email});
      return null;
    } on Exception catch (e) {
      final str = e.toString();
      if (str.contains('429')) return 'Aguarde antes de solicitar novo código';
      return null; // sempre silencioso para não revelar cadastros
    }
  }

  Future<String?> forgotPassword(String email) async {
    try {
      await api.post('/auth/forgot-password', data: {'email': email});
      return null;
    } on Exception catch (e) {
      final str = e.toString();
      if (str.contains('429')) return 'Aguarde antes de solicitar novo código';
      return null;
    }
  }

  Future<String?> resetPassword(String email, String code, String newPassword) async {
    try {
      await api.post('/auth/reset-password', data: {
        'email': email,
        'code': code,
        'new_password': newPassword,
      });
      return null;
    } on Exception catch (e) {
      final str = e.toString();
      if (str.contains('400')) return 'Código inválido ou expirado';
      if (str.contains('422')) return 'Senha deve ter no mínimo 6 caracteres';
      return 'Erro ao redefinir senha';
    }
  }

  Future<void> googleSignIn() async {
    state = state.copyWith(loading: true, clearError: true, clearUnverified: true);
    try {
      final account = await _getGoogleSignIn().signIn();
      if (account == null) {
        state = state.copyWith(loading: false);
        return;
      }
      final googleAuth = await account.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) {
        state = state.copyWith(loading: false, error: 'Falha na autenticação Google');
        return;
      }
      final res = await api.post('/auth/google', data: {'id_token': idToken});
      final token = res.data['access_token'];
      await api.saveToken(token);
      _invalidateData();
      state = AuthState(user: User.fromJson(res.data['user']));
    } on Exception catch (e) {
      state = state.copyWith(
        loading: false,
        error: _extractApiError(e, fallback: 'Erro ao entrar com Google'),
      );
    }
  }

  void _invalidateData() {
    ref.invalidate(accountsProvider);
    ref.invalidate(categoriesProvider);
    ref.invalidate(transactionsProvider);
    ref.invalidate(recurringProvider);
    ref.invalidate(dashboardProvider);
    ref.invalidate(creditCardBillsProvider);
    ref.invalidate(monthlyReportProvider);
    ref.invalidate(monthlyDetailProvider);
    ref.invalidate(invoiceProvider);
  }

  Future<void> logout() async {
    await api.clearToken();
    state = const AuthState();
  }

  Future<String?> updateProfile({required String name}) async {
    try {
      final res = await api.put('/auth/me', data: {'name': name});
      state = state.copyWith(user: User.fromJson(res.data));
      return null;
    } on Exception catch (e) {
      return _extractApiError(e, fallback: 'Erro ao atualizar perfil');
    }
  }

  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await api.put('/auth/me/password', data: {
        'current_password': currentPassword,
        'new_password': newPassword,
      });
      return null;
    } on Exception catch (e) {
      return _extractApiError(e, fallback: 'Erro ao alterar senha');
    }
  }

  String _extractLoginError(Exception e) {
    final str = e.toString();
    if (str.contains('401')) return 'Email ou senha inválidos';
    if (str.contains('SocketException') || str.contains('Connection')) return 'Sem conexão com o servidor';
    return 'Erro ao fazer login';
  }

  String _extractApiError(Exception e, {required String fallback}) {
    final str = e.toString();
    if (str.contains('400')) return 'Email já cadastrado';
    if (str.contains('401')) return 'Senha atual incorreta';
    if (str.contains('422')) return 'Dados inválidos';
    if (str.contains('SocketException') || str.contains('Connection')) return 'Sem conexão com o servidor';
    return fallback;
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
