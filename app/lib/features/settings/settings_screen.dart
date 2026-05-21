import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/utils/platform_utils.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeProvider);
    final user = ref.watch(authProvider).user;

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isDesktop ? 720 : double.infinity),
          child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          // Profile card
          if (user != null) ...[
            _SectionLabel('Conta'),
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _openEditProfile(context, ref),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.appSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.appBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: context.appPrimary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: context.appPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.name,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(user.email,
                              style: const TextStyle(
                                  fontSize: 12, color: AppTheme.textMuted)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Theme selector
          _SectionLabel('Aparência'),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isDesktop ? 5 : 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: isDesktop ? 1.1 : 0.95,
            ),
            itemCount: AppThemeVariant.values.length,
            itemBuilder: (_, i) {
              final variant = AppThemeVariant.values[i];
              return _ThemeCard(
                variant: variant,
                selected: current == variant,
                onTap: () => ref.read(themeProvider.notifier).set(variant),
              );
            },
          ),

          const SizedBox(height: 32),

          // Telegram
          _SectionLabel('Telegram'),
          const SizedBox(height: 8),
          const _TelegramSection(),

          const SizedBox(height: 32),

          // Logout
          _SectionLabel('Sessão'),
          const SizedBox(height: 8),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _confirmLogout(context, ref),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: context.appSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.appBorder),
              ),
              child: const Row(
                children: [
                  Icon(Icons.logout, color: AppTheme.red, size: 20),
                  SizedBox(width: 12),
                  Text('Sair da conta',
                      style: TextStyle(
                          color: AppTheme.red, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
        ],
          ),
        ),
      ),
    );
  }

  void _openEditProfile(BuildContext context, WidgetRef ref) {
    showAdaptiveSheet(
      context: context,
      builder: (_) => _EditProfileSheet(ref: ref),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.appSurface,
        title: const Text('Sair da conta'),
        content: const Text('Deseja encerrar a sessão?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authProvider.notifier).logout();
            },
            child: const Text('Sair'),
          ),
        ],
      ),
    );
  }
}

// ── Edit profile bottom sheet ─────────────────────────────────────────────────

class _EditProfileSheet extends ConsumerStatefulWidget {
  final WidgetRef ref;
  const _EditProfileSheet({required this.ref});

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: inset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: context.appBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Editar perfil',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 12),

          // Tabs
          TabBar(
            controller: _tabs,
            tabs: const [
              Tab(text: 'Dados pessoais'),
              Tab(text: 'Alterar senha'),
            ],
          ),

          // Tab views — fixed height avoids overflow with keyboard
          SizedBox(
            height: 280,
            child: TabBarView(
              controller: _tabs,
              children: [
                _ProfileForm(ref: ref),
                _PasswordForm(ref: ref),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Profile form (name + email) ───────────────────────────────────────────────

class _ProfileForm extends ConsumerStatefulWidget {
  final WidgetRef ref;
  const _ProfileForm({required this.ref});

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _nameCtrl = TextEditingController(text: user?.name ?? '');
    _emailCtrl = TextEditingController(text: user?.email ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final err = await ref.read(authProvider.notifier).updateProfile(
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
        );
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _saving = false;
        _error = err;
      });
    } else {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil atualizado')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nome'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Informe o nome' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'E-mail'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Informe o e-mail';
                if (!v.contains('@')) return 'E-mail inválido';
                return null;
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  style: const TextStyle(color: AppTheme.red, fontSize: 13)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Salvar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Password form ─────────────────────────────────────────────────────────────

class _PasswordForm extends ConsumerStatefulWidget {
  final WidgetRef ref;
  const _PasswordForm({required this.ref});

  @override
  ConsumerState<_PasswordForm> createState() => _PasswordFormState();
}

class _PasswordFormState extends ConsumerState<_PasswordForm> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _saving = false;
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;
  String? _error;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final err = await ref.read(authProvider.notifier).changePassword(
          currentPassword: _currentCtrl.text,
          newPassword: _newCtrl.text,
        );
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _saving = false;
        _error = err;
      });
    } else {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Senha alterada com sucesso')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _currentCtrl,
              obscureText: !_showCurrent,
              decoration: InputDecoration(
                labelText: 'Senha atual',
                suffixIcon: IconButton(
                  icon: Icon(_showCurrent
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                      size: 20),
                  onPressed: () =>
                      setState(() => _showCurrent = !_showCurrent),
                ),
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Informe a senha atual' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _newCtrl,
              obscureText: !_showNew,
              decoration: InputDecoration(
                labelText: 'Nova senha',
                suffixIcon: IconButton(
                  icon: Icon(_showNew
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                      size: 20),
                  onPressed: () => setState(() => _showNew = !_showNew),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Informe a nova senha';
                if (v.length < 6) return 'Mínimo 6 caracteres';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmCtrl,
              obscureText: !_showConfirm,
              decoration: InputDecoration(
                labelText: 'Confirmar nova senha',
                suffixIcon: IconButton(
                  icon: Icon(_showConfirm
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                      size: 20),
                  onPressed: () =>
                      setState(() => _showConfirm = !_showConfirm),
                ),
              ),
              validator: (v) =>
                  v != _newCtrl.text ? 'As senhas não coincidem' : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  style: const TextStyle(color: AppTheme.red, fontSize: 13)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Alterar senha'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Telegram section ──────────────────────────────────────────────────────────

class _TelegramSection extends StatefulWidget {
  const _TelegramSection();

  @override
  State<_TelegramSection> createState() => _TelegramSectionState();
}

class _TelegramSectionState extends State<_TelegramSection> {
  bool _loading = true;
  bool _linked = false;
  DateTime? _linkedAt;
  bool _polling = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    try {
      final res = await api.get('/telegram/status');
      if (!mounted) return;
      setState(() {
        _linked = res.data['linked'] as bool;
        final at = res.data['linked_at'];
        _linkedAt = at != null ? DateTime.tryParse(at as String) : null;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generateLink() async {
    try {
      final res = await api.post('/telegram/generate-link');
      final url = Uri.parse(res.data['url'] as String);
      await launchUrl(url, mode: LaunchMode.externalApplication);
      _startPolling();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao gerar link do Telegram')),
        );
      }
    }
  }

  void _startPolling() {
    if (!mounted) return;
    setState(() => _polling = true);
    int attempts = 0;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      attempts++;
      await _checkStatus();
      if (_linked || attempts >= 10) {
        _pollTimer?.cancel();
        if (mounted) setState(() => _polling = false);
      }
    });
  }

  Future<void> _unlink() async {
    setState(() => _loading = true);
    try {
      await api.delete('/telegram/unlink');
    } catch (_) {}
    await _checkStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appBorder),
      ),
      child: _loading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          : _linked
              ? _buildLinked()
              : _buildUnlinked(),
    );
  }

  Widget _buildLinked() {
    final dateStr = _linkedAt != null
        ? '${_linkedAt!.day.toString().padLeft(2, '0')}/${_linkedAt!.month.toString().padLeft(2, '0')}/${_linkedAt!.year}'
        : '';
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF2CA5E0).withAlpha(25),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.telegram, color: Color(0xFF2CA5E0), size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Conta vinculada',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              if (dateStr.isNotEmpty)
                Text('Desde $dateStr',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textMuted)),
            ],
          ),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: AppTheme.red),
          onPressed: _unlink,
          child: const Text('Desvincular',
              style: TextStyle(fontSize: 13)),
        ),
      ],
    );
  }

  Widget _buildUnlinked() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: context.appBorder.withAlpha(80),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.telegram,
                  color: AppTheme.textMuted, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Não vinculado',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  Text('Use o assistente IA pelo Telegram',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.textMuted)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _polling
            ? Row(
                children: [
                  const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Aguardando confirmação no Telegram…',
                        style: TextStyle(
                            fontSize: 13, color: AppTheme.textMuted)),
                  ),
                  TextButton(
                    onPressed: () {
                      _pollTimer?.cancel();
                      setState(() => _polling = false);
                    },
                    child: const Text('Cancelar'),
                  ),
                ],
              )
            : SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.telegram, size: 18),
                  label: const Text('Vincular ao Telegram'),
                  onPressed: _generateLink,
                ),
              ),
      ],
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.textMuted,
          letterSpacing: 0.8,
        ),
      );
}

// ── Theme card ────────────────────────────────────────────────────────────────

class _ThemeCard extends StatelessWidget {
  final AppThemeVariant variant;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.variant,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.palettes[variant]!;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? p.primary : p.border,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(color: p.primary.withValues(alpha: 0.3), blurRadius: 6)]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _dot(p.bg, p.border),
                const SizedBox(width: 5),
                _dot(p.surface, p.border),
                const SizedBox(width: 5),
                _dot(p.primary, Colors.transparent),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                variant.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: !p.isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4),
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              size: 14,
              color: selected ? p.primary : p.border,
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot(Color fill, Color stroke) => Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: Border.all(color: stroke, width: 0.5),
        ),
      );
}
