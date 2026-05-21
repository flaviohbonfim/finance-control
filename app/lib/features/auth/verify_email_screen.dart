import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_theme.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  final String email;
  const VerifyEmailScreen({super.key, required this.email});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  late String _effectiveEmail;

  final _controllers = List.generate(6, (_) => TextEditingController());
  final _focusNodes = List.generate(6, (_) => FocusNode());
  final _keyFocusNodes = List.generate(6, (_) => FocusNode());

  String? _error;
  bool _loading = false;
  bool _resendLoading = false;
  String? _resendMessage;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _effectiveEmail = widget.email;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_effectiveEmail.isEmpty) {
      _effectiveEmail = ref.read(authProvider).user?.email ?? '';
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) { c.dispose(); }
    for (final f in _focusNodes) { f.dispose(); }
    for (final f in _keyFocusNodes) { f.dispose(); }
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _cooldown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _cooldown--);
      if (_cooldown <= 0) { t.cancel(); }
    });
  }

  String get _code => _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '').split('').take(6).toList();
      for (var i = 0; i < digits.length && i < 6; i++) {
        _controllers[i].text = digits[i];
      }
      final next = digits.length < 6 ? digits.length : 5;
      _focusNodes[next].requestFocus();
      setState(() => _error = null);
      return;
    }
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    setState(() => _error = null);
  }

  void _onKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
    }
  }

  Future<void> _submit() async {
    final code = _code;
    if (code.length < 6) {
      setState(() => _error = 'Digite os 6 dígitos do código');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final error = await ref.read(authProvider.notifier).verifyEmail(_effectiveEmail, code);
    if (!mounted) return;
    if (error != null) {
      for (final c in _controllers) { c.clear(); }
      _focusNodes[0].requestFocus();
      setState(() { _loading = false; _error = error; });
    }
  }

  Future<void> _resend() async {
    if (_cooldown > 0 || _resendLoading) return;
    setState(() { _resendLoading = true; _resendMessage = null; });
    await ref.read(authProvider.notifier).resendVerification(_effectiveEmail);
    if (!mounted) return;
    setState(() { _resendLoading = false; _resendMessage = 'Código reenviado!'; });
    _startCooldown();
  }

  @override
  Widget build(BuildContext context) {
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
                  const Text('Verifique seu email', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(
                    'Enviamos um código de 6 dígitos para\n$_effectiveEmail',
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 32),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (i) => Padding(
                      padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
                      child: SizedBox(
                        width: 46, height: 56,
                        child: KeyboardListener(
                          focusNode: _keyFocusNodes[i],
                          onKeyEvent: (e) => _onKeyEvent(i, e),
                          child: TextFormField(
                            controller: _controllers[i],
                            focusNode: _focusNodes[i],
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            maxLength: i == 0 ? 6 : 1,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                            decoration: InputDecoration(
                              counterText: '',
                              contentPadding: EdgeInsets.zero,
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: _error != null ? AppTheme.red : Theme.of(context).dividerColor,
                                  width: 2,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: context.appPrimary, width: 2),
                              ),
                            ),
                            onChanged: (v) => _onDigitChanged(i, v),
                          ),
                        ),
                      ),
                    )),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    _ErrorBox(_error!),
                  ],

                  if (_resendMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.green.withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.withAlpha(60)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.check_circle_outline, color: Colors.green, size: 16),
                        const SizedBox(width: 8),
                        Text(_resendMessage!, style: const TextStyle(color: Colors.green, fontSize: 13)),
                      ]),
                    ),
                  ],

                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: (_loading || _code.length < 6) ? null : _submit,
                    child: _loading
                        ? const SizedBox(height: 20, width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                        : const Text('Verificar email'),
                  ),
                  const SizedBox(height: 16),

                  Center(
                    child: _cooldown > 0
                        ? Text('Reenviar em ${_cooldown}s',
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))
                        : TextButton(
                            onPressed: _resendLoading ? null : _resend,
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                                children: [
                                  const TextSpan(text: 'Não recebeu? '),
                                  TextSpan(
                                    text: 'Reenviar código',
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

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox(this.message);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.red.withAlpha(20),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.red.withAlpha(60)),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline, color: AppTheme.red, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(color: AppTheme.red, fontSize: 13))),
        ]),
      );
}
