import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/api/models.dart';
import '../../core/api/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/currency_text.dart';
import 'launch_modal.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

Color _hexColor(String hex) {
  try {
    return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
  } catch (_) {
    return AppTheme.primaryColor;
  }
}

String _freqLabel(String f) => f == 'yearly' ? 'Anual' : 'Mensal';

// ── Screen ────────────────────────────────────────────────────────────────────

class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recurringAsync = ref.watch(recurringProvider);

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 20),
            child: Row(
              children: [
                const Text('Recorrentes',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Novo recorrente',
                  onPressed: () => _openForm(context, ref, null),
                ),
              ],
            ),
          ),
          Expanded(
            child: recurringAsync.when(
              data: (list) => _buildList(context, ref, list),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erro: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
      BuildContext context, WidgetRef ref, List<RecurringTransaction> list) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.repeat_outlined, size: 52, color: AppTheme.textMuted),
            const SizedBox(height: 12),
            const Text('Nenhum recorrente cadastrado',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 15)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Criar recorrente'),
              onPressed: () => _openForm(context, ref, null),
            ),
          ],
        ),
      );
    }

    final active = list.where((r) => r.active).toList();
    final inactive = list.where((r) => !r.active).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        if (active.isNotEmpty) ...[
          _sectionHeader('Ativos'),
          ...active.map((r) => _RecurringTile(
                rt: r,
                onEdit: () => _openForm(context, ref, r),
                onDelete: () => _confirmDelete(context, ref, r),
                onToggleActive: () => _toggleActive(context, ref, r),
                onLaunch: () => _openLaunch(context, ref, r),
              )),
        ],
        if (inactive.isNotEmpty) ...[
          if (active.isNotEmpty) const SizedBox(height: 4),
          _sectionHeader('Inativos'),
          ...inactive.map((r) => _RecurringTile(
                rt: r,
                onEdit: () => _openForm(context, ref, r),
                onDelete: () => _confirmDelete(context, ref, r),
                onToggleActive: () => _toggleActive(context, ref, r),
                onLaunch: null,
              )),
        ],
      ],
    );
  }

  Widget _sectionHeader(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMuted,
                letterSpacing: 0.3)),
      );

  void _openForm(BuildContext context, WidgetRef ref, RecurringTransaction? rt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RecurringFormSheet(
        rt: rt,
        onSaved: () => ref.invalidate(recurringProvider),
      ),
    );
  }

  void _openLaunch(BuildContext context, WidgetRef ref, RecurringTransaction rt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.appSurface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => LaunchModal(
        rt: rt,
        onDone: () {
          ref.invalidate(recurringProvider);
          ref.invalidate(dashboardProvider);
        },
      ),
    );
  }

  Future<void> _toggleActive(
      BuildContext context, WidgetRef ref, RecurringTransaction rt) async {
    try {
      await api.put('/recurring-transactions/${rt.id}',
          data: {'active': !rt.active});
      ref.invalidate(recurringProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, RecurringTransaction rt) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.appSurface,
        title: const Text('Excluir recorrente'),
        content: Text('Deseja excluir "${rt.description}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await api.delete('/recurring-transactions/${rt.id}');
                ref.invalidate(recurringProvider);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erro ao excluir: $e')));
                }
              }
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }
}

// ── Recurring tile ────────────────────────────────────────────────────────────

class _RecurringTile extends StatelessWidget {
  final RecurringTransaction rt;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleActive;
  final VoidCallback? onLaunch;

  const _RecurringTile({
    required this.rt,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
    required this.onLaunch,
  });

  @override
  Widget build(BuildContext context) {
    final catColor = rt.categoryColor != null
        ? _hexColor(rt.categoryColor!)
        : context.appPrimary;
    final isIncome = rt.isIncome;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration:
                  BoxDecoration(color: catColor.withAlpha(30), shape: BoxShape.circle),
              child: Icon(
                isIncome ? Icons.trending_up : Icons.trending_down,
                size: 18,
                color: catColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(rt.description,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (rt.launchedThisMonth)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.green.withAlpha(25),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('Lançado',
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.green)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      _chip(_freqLabel(rt.frequency), context.appPrimary),
                      const SizedBox(width: 6),
                      _chip(
                        isIncome ? 'Receita' : 'Despesa',
                        isIncome ? AppTheme.green : AppTheme.red,
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        rt.isFixed && rt.amount != null
                            ? fmtBrl(rt.amount!)
                            : 'Variável',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isIncome ? AppTheme.green : AppTheme.red,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '· dia ${rt.dueDay}${rt.dueMonth != null ? '/${rt.dueMonth}' : ''}',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textMuted),
                      ),
                      if (rt.accountName != null) ...[
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '· ${rt.accountName}',
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textMuted),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onLaunch != null && !rt.launchedThisMonth)
                  IconButton(
                    icon: Icon(Icons.play_circle_outline,
                        color: context.appPrimary, size: 22),
                    tooltip: 'Lançar',
                    onPressed: onLaunch,
                  ),
                PopupMenuButton<String>(
                  color: context.appSurface,
                  icon: const Icon(Icons.more_vert,
                      size: 20, color: AppTheme.textMuted),
                  onSelected: (v) {
                    if (v == 'edit') onEdit();
                    if (v == 'toggle') onToggleActive();
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Editar')),
                    PopupMenuItem(
                      value: 'toggle',
                      child: Text(rt.active ? 'Desativar' : 'Ativar'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Excluir',
                          style: TextStyle(color: AppTheme.red)),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w600, color: color)),
      );
}

// ── Recurring form sheet ──────────────────────────────────────────────────────

class _RecurringFormSheet extends ConsumerStatefulWidget {
  final RecurringTransaction? rt;
  final VoidCallback onSaved;

  const _RecurringFormSheet({required this.rt, required this.onSaved});

  @override
  ConsumerState<_RecurringFormSheet> createState() =>
      _RecurringFormSheetState();
}

class _RecurringFormSheetState extends ConsumerState<_RecurringFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late final _descCtrl =
      TextEditingController(text: widget.rt?.description ?? '');
  late final _amountCtrl = TextEditingController(
      text: widget.rt?.amount?.toStringAsFixed(2).replaceAll('.', ',') ?? '');
  late final _dueDayCtrl =
      TextEditingController(text: widget.rt?.dueDay.toString() ?? '');
  late final _dueMonthCtrl =
      TextEditingController(text: widget.rt?.dueMonth?.toString() ?? '');

  late String _type = widget.rt?.type ?? 'expense';
  late String _frequency = widget.rt?.frequency ?? 'monthly';
  late bool _isFixed = widget.rt?.isFixed ?? true;
  late bool _active = widget.rt?.active ?? true;
  late int? _accountId = widget.rt?.accountId;
  late int? _categoryId = widget.rt?.categoryId;
  late DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _saving = false;

  bool get _isEdit => widget.rt != null;
  bool get _isYearly => _frequency == 'yearly';

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.dispose();
    _dueDayCtrl.dispose();
    _dueMonthCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isEnd}) async {
    final initial = isEnd ? (_endDate ?? DateTime.now()) : _startDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null) {
      setState(() {
        if (isEnd) {
          _endDate = picked;
        } else {
          _startDate = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecione a conta')));
      return;
    }
    setState(() => _saving = true);

    final amountRaw =
        _amountCtrl.text.trim().replaceAll('.', '').replaceAll(',', '.');
    final amount =
        _isFixed && amountRaw.isNotEmpty ? double.tryParse(amountRaw) : null;
    final dueDay = int.tryParse(_dueDayCtrl.text.trim()) ?? 1;
    final dueMonth =
        _isYearly ? int.tryParse(_dueMonthCtrl.text.trim()) : null;
    final fmt = DateFormat('yyyy-MM-dd');

    final body = {
      'type': _type,
      'description': _descCtrl.text.trim(),
      'is_fixed': _isFixed,
      'frequency': _frequency,
      'due_day': dueDay,
      if (dueMonth != null) 'due_month': dueMonth,
      if (amount != null) 'amount': amount,
      if (!_isEdit) 'account_id': _accountId,
      if (!_isEdit) 'start_date': fmt.format(_startDate),
      if (_isEdit) 'account_id': _accountId,
      if (_isEdit) 'start_date': fmt.format(_startDate),
      if (_endDate != null) 'end_date': fmt.format(_endDate!),
      if (_categoryId != null) 'category_id': _categoryId,
      'active': _active,
    };

    try {
      if (_isEdit) {
        await api.put('/recurring-transactions/${widget.rt!.id}', data: body);
      } else {
        await api.post('/recurring-transactions', data: body);
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final accountsAsync = ref.watch(accountsProvider);
    final catsAsync = ref.watch(categoriesProvider(_type));
    final fmt = DateFormat('dd/MM/yyyy', 'pt_BR');

    return Container(
      margin: EdgeInsets.only(bottom: inset),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: context.appBorder,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text(_isEdit ? 'Editar recorrente' : 'Novo recorrente',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),

              // Type toggle
              Row(
                children: [
                  _ToggleBtn(
                    label: 'Despesa',
                    selected: _type == 'expense',
                    color: AppTheme.red,
                    onTap: () => setState(() {
                      _type = 'expense';
                      _categoryId = null;
                    }),
                  ),
                  const SizedBox(width: 10),
                  _ToggleBtn(
                    label: 'Receita',
                    selected: _type == 'income',
                    color: AppTheme.green,
                    onTap: () => setState(() {
                      _type = 'income';
                      _categoryId = null;
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: 'Descrição'),
                textCapitalization: TextCapitalization.sentences,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Informe a descrição' : null,
              ),
              const SizedBox(height: 12),

              // Frequency toggle
              const Text('Frequência',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _ToggleBtn(
                    label: 'Mensal',
                    selected: _frequency == 'monthly',
                    color: context.appPrimary,
                    onTap: () =>
                        setState(() => _frequency = 'monthly'),
                  ),
                  const SizedBox(width: 10),
                  _ToggleBtn(
                    label: 'Anual',
                    selected: _frequency == 'yearly',
                    color: context.appPrimary,
                    onTap: () =>
                        setState(() => _frequency = 'yearly'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Due day / month
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _dueDayCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Dia vencimento'),
                      validator: (v) {
                        final d = int.tryParse(v?.trim() ?? '');
                        if (d == null || d < 1 || d > 31) return '1–31';
                        return null;
                      },
                    ),
                  ),
                  if (_isYearly) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _dueMonthCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Mês vencimento'),
                        validator: (v) {
                          if (!_isYearly) return null;
                          final d = int.tryParse(v?.trim() ?? '');
                          if (d == null || d < 1 || d > 12) return '1–12';
                          return null;
                        },
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),

              // Fixed amount
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Valor fixo',
                    style: TextStyle(fontSize: 14)),
                value: _isFixed,
                onChanged: (v) => setState(() => _isFixed = v),
                activeThumbColor: context.appPrimary,
              ),
              if (_isFixed) ...[
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      const InputDecoration(labelText: 'Valor', prefixText: 'R\$ '),
                  validator: (v) {
                    if (!_isFixed) return null;
                    final raw =
                        v?.trim().replaceAll('.', '').replaceAll(',', '.') ?? '';
                    if (double.tryParse(raw) == null) return 'Valor inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
              ],

              // Account
              accountsAsync.when(
                data: (accounts) => DropdownButtonFormField<int>(
                  key: ValueKey(_accountId),
                  initialValue: _accountId,
                  dropdownColor: context.appBg,
                  decoration: const InputDecoration(labelText: 'Conta'),
                  items: accounts
                      .map((a) => DropdownMenuItem(
                            value: a.id,
                            child: Text(a.name),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _accountId = v),
                  validator: (v) => v == null ? 'Selecione a conta' : null,
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 12),

              // Category (optional)
              catsAsync.when(
                data: (cats) => DropdownButtonFormField<int>(
                  key: ValueKey('cat_$_type'),
                  initialValue: cats.any((c) => c.id == _categoryId)
                      ? _categoryId
                      : null,
                  dropdownColor: context.appBg,
                  decoration: const InputDecoration(labelText: 'Categoria (opcional)'),
                  items: [
                    const DropdownMenuItem<int>(
                        value: null, child: Text('Sem categoria')),
                    ...cats.map((c) =>
                        DropdownMenuItem(value: c.id, child: Text(c.name))),
                  ],
                  onChanged: (v) => setState(() => _categoryId = v),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 12),

              // Start date
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Data início',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                subtitle: Text(fmt.format(_startDate),
                    style: const TextStyle(fontSize: 14)),
                trailing: const Icon(Icons.calendar_today,
                    size: 18, color: AppTheme.textMuted),
                onTap: () => _pickDate(isEnd: false),
              ),

              // End date (optional)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Data fim (opcional)',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                subtitle: Text(
                  _endDate != null ? fmt.format(_endDate!) : 'Sem data fim',
                  style: TextStyle(
                      fontSize: 14,
                      color: _endDate != null
                          ? null
                          : AppTheme.textMuted),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_endDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear,
                            size: 16, color: AppTheme.textMuted),
                        onPressed: () => setState(() => _endDate = null),
                      ),
                    const Icon(Icons.calendar_today,
                        size: 18, color: AppTheme.textMuted),
                  ],
                ),
                onTap: () => _pickDate(isEnd: true),
              ),

              if (_isEdit) ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ativo', style: TextStyle(fontSize: 14)),
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                  activeThumbColor: context.appPrimary,
                ),
              ],

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Text(_isEdit ? 'Salvar alterações' : 'Criar recorrente'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _ToggleBtn(
      {required this.label,
      required this.selected,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? color.withAlpha(30) : context.appBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color : context.appBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: selected ? color : AppTheme.textSecondary)),
          ),
        ),
      ),
    );
  }
}
