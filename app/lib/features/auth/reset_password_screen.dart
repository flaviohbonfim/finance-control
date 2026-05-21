import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_theme.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  final String email;
  const ResetPasswordScreen({super.key, required this.email});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _codeControllers = List.generate(6, (_) => TextEditingController());
  final _codeFocusNodes = List.generate(6, (_) => FocusNode());
  final _codeKeyFocusNodes = List.generate(6, (_) => FocusNode());
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  String? _codeError;
  String? _error;
  bool _success = false;

  @override
  void dispose() {
    for (final c in _codeControllers) { c.dispose(); }
    for (final f in _codeFocusNodes) { f.dispose(); }
    for (final f in _codeKeyFocusNodes) { f.dispose(); }
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  String get _code => _codeControllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '').split('').take(6).toList();
      for (var i = 0; i < digits.length && i < 6; i++) {
        _codeControllers[i].text = digits[i];
      }
      final next = digits.length < 6 ? digits.length : 5;
      _codeFocusNodes[next].requestFocus();
      setState(() => _codeError = null);
      return;
    }
    if (value.isNotEmpty && index < 5) { _codeFocusNodes[index + 1].requestFocus(); }
    setState(() => _codeError = null);
  }

  void _onKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _codeControllers[index].text.isEmpty &&
        index > 0) {
      _codeFocusNodes[index - 1].requestFocus();
      _codeControllers[index - 1].clear();
    }
  }

  Future<void> _submit() async {
    final code = _code;
    if (code.length < 6) {
      setState(() => _codeError = 'Digite os 6 dígitos do código');
      return;
    }
    if (_passCtrl.text.length < 6) {
      setState(() => _error = 'Senha deve ter no mínimo 6 caracteres');
      return;
    }
    if (_passCtrl.text != _confirmCtrl.text) {
      setState(() => _error = 'As senhas não coincidem');
      return;
    }
    setState(() { _loading = true; _error = null; _codeError = null; });
    final error = await ref.read(authProvider.notifier)
        .resetPassword(widget.email, code, _passCtrl.text);
    if (!mounted) return;
    if (error != null) {
      if (error.contains('Código')) {
        for (final c in _codeControllers) { c.clear(); }
        _codeFocusNodes[0].requestFocus();
        setState(() { _loading = false; _codeError = error; });
      } else {
        setState(() { _loading = false; _error = error; });
      }
    } else {
      setState(() { _loading = false; _success = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_success) {
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
                      child: const Icon(Icons.check_circle_outline, color: Colors.green, size: 32),
                    ),
                    const SizedBox(height: 24),
                    const Text('Senha redefinida!',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    const Text('Sua senha foi alterada com sucesso.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textSecondary)),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Ir para o login'),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
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
              const Text('Nova senha', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Digite o código enviado para\n${widget.email}',
                  style: const TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 32),

              const Text('Código de verificação',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),

              Row(
                children: List.generate(6, (i) => Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
                  child: SizedBox(
                    width: 46, height: 56,
                    child: KeyboardListener(
                      focusNode: _codeKeyFocusNodes[i],
                      onKeyEvent: (e) => _onKeyEvent(i, e),
                      child: TextFormField(
                        controller: _codeControllers[i],
                        focusNode: _codeFocusNodes[i],
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
                              color: _codeError != null ? AppTheme.red : Theme.of(context).dividerColor,
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

              if (_codeError != null) ...[
                const SizedBox(height: 6),
                Text(_codeError!, style: const TextStyle(color: AppTheme.red, fontSize: 12)),
              ],

              const SizedBox(height: 20),

              TextFormField(
                controller: _passCtrl,
                obscureText: _obscurePass,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Nova senha',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscurePass = !_obscurePass),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _confirmCtrl,
                obscureText: _obscureConfirm,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Confirmar nova senha',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
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
                    : const Text('Redefinir senha'),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => context.pop(),
                  child: Text('Solicitar novo código',
                      style: TextStyle(color: context.appPrimary, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
