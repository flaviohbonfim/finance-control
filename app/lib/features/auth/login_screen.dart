import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/platform_utils.dart';
import 'google_sign_in_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();
  @override
  Widget build(BuildContext context) => Row(children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('ou', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        ),
        const Expanded(child: Divider()),
      ]);
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) return;
    await ref.read(authProvider.notifier).login(email, pass);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isDesktop ? 440 : double.infinity),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: context.appPrimary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Text('Finance Control',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 40),
                  const Text('Entrar na conta',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  const Text('Acesse para gerenciar suas finanças',
                      style: TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(height: 32),

                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _passCtrl,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => context.push('/forgot-password'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text('Esqueci minha senha',
                          style: TextStyle(color: context.appPrimary, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Email não verificado
                  if (auth.emailNotVerified) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withAlpha(25),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.withAlpha(80)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Email não verificado',
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                const SizedBox(height: 2),
                                GestureDetector(
                                  onTap: () => context.push(
                                    '/verify-email',
                                    extra: auth.unverifiedEmail ?? _emailCtrl.text.trim(),
                                  ),
                                  child: Text(
                                    'Clique aqui para verificar seu email',
                                    style: TextStyle(
                                      color: context.appPrimary,
                                      fontSize: 13,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Erro genérico
                  if (auth.error != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.red.withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.red.withAlpha(60)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.error_outline, color: AppTheme.red, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(auth.error!,
                            style: const TextStyle(color: AppTheme.red, fontSize: 13))),
                      ]),
                    ),
                    const SizedBox(height: 12),
                  ],

                  const SizedBox(height: 12),

                  ElevatedButton(
                    onPressed: auth.loading ? null : _submit,
                    child: auth.loading
                        ? const SizedBox(height: 20, width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                        : const Text('Entrar'),
                  ),

                  if (supportsGoogleSignIn) ...[
                    const SizedBox(height: 16),
                    const _OrDivider(),
                    const SizedBox(height: 16),
                    GoogleSignInButton(
                      loading: auth.loading,
                      onPressed: () => ref.read(authProvider.notifier).googleSignIn(),
                    ),
                  ],

                  const SizedBox(height: 16),

                  Center(
                    child: TextButton(
                      onPressed: () => context.push('/register'),
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                          children: [
                            const TextSpan(text: 'Não tem conta? '),
                            TextSpan(
                              text: 'Criar conta',
                              style: TextStyle(color: context.appPrimary, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
