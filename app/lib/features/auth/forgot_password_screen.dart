import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_theme.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _sent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Informe um email válido');
      return;
    }
    setState(() { _loading = true; _error = null; });
    await ref.read(authProvider.notifier).forgotPassword(email);
    if (!mounted) return;
    setState(() { _loading = false; _sent = true; });
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(color: Colors.green.withAlpha(30), shape: BoxShape.circle),
                      child: const Icon(Icons.mark_email_read_outlined, color: Colors.green, size: 32),
                    ),
                    const SizedBox(height: 24),
                    const Text('Verifique seu email',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    Text(
                      'Se o email ${_emailCtrl.text.trim()} estiver cadastrado, você receberá um código em breve.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () => context.push('/reset-password', extra: _emailCtrl.text.trim()),
                      child: const Text('Inserir código'),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => context.pop(),
                      child: Text('Voltar ao login',
                          style: TextStyle(color: context.appPrimary, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(color: context.appPrimary, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Text('Finance Control', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 40),
                  const Text('Esqueci minha senha',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  const Text('Informe seu email para receber o código de recuperação',
                      style: TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(height: 32),

                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 12),
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
                        Expanded(child: Text(_error!, style: const TextStyle(color: AppTheme.red, fontSize: 13))),
                      ]),
                    ),
                  ],

                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(height: 20, width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                        : const Text('Enviar código'),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: () => context.pop(),
                      child: Text('Voltar ao login',
                          style: TextStyle(color: context.appPrimary, fontWeight: FontWeight.w600)),
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
