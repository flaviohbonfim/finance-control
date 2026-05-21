import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/api/models.dart';
import '../../core/api/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/currency_text.dart';

// ── Period filter ─────────────────────────────────────────────────────────────

enum TxPeriod { thisMonth, upcoming, past, all }

final _periodProvider = StateProvider<TxPeriod>((ref) => TxPeriod.thisMonth);

TransactionParams _paramsFor(TxPeriod period) {
  final now = DateTime.now();
  final fmt = DateFormat('yyyy-MM-dd');
  switch (period) {
    case TxPeriod.thisMonth:
      return TransactionParams(
        dateFrom: fmt.format(DateTime(now.year, now.month, 1)),
        dateTo: fmt.format(DateTime(now.year, now.month + 1, 0)),
        pageSize: 100,
      );
    case TxPeriod.upcoming:
      return TransactionParams(
        dateFrom: fmt.format(DateTime(now.year, now.month, now.day + 1)),
        pageSize: 100,
      );
    case TxPeriod.past:
      return TransactionParams(
        dateTo: fmt.format(DateTime(now.year, now.month, 0)),
        pageSize: 100,
      );
    case TxPeriod.all:
      return const TransactionParams(pageSize: 100);
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  // IDs removidos otimisticamente antes da confirmação da API
  final _dismissedIds = <int>{};

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(_periodProvider);
    final params = _paramsFor(period);
    final txAsync = ref.watch(transactionsProvider(params));

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, period, params),
          Expanded(
            child: txAsync.when(
              data: (data) {
                final visible =
                    data.items.where((tx) => !_dismissedIds.contains(tx.id)).toList();
                return RefreshIndicator(
                  onRefresh: () => ref.refresh(transactionsProvider(params).future),
                  child: _buildList(visible, params),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erro: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, TxPeriod period, TransactionParams params) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Transações',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _openForm(null, params),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: context.appPrimary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _PeriodToggle(selected: period, ref: ref),
        ],
      ),
    );
  }

  Widget _buildList(List<Transaction> items, TransactionParams params) {
    if (items.isEmpty) {
      return const CustomScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 52, color: AppTheme.textMuted),
                  SizedBox(height: 12),
                  Text('Nenhuma transação encontrada',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 15)),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final grouped = <String, List<Transaction>>{};
    for (final tx in items) {
      grouped.putIfAbsent(tx.transactionDate.substring(0, 10), () => []).add(tx);
    }
    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      itemCount: sortedDates.length,
      itemBuilder: (_, i) {
        final date = sortedDates[i];
        return _DateGroup(
          date: date,
          transactions: grouped[date]!,
          onEdit: (tx) => _openForm(tx, params),
          onDelete: _dismiss,
        );
      },
    );
  }

  void _openForm(Transaction? tx, TransactionParams params) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TransactionForm(
        existing: tx,
        onSaved: () {
          ref.invalidate(transactionsProvider);
          ref.invalidate(dashboardProvider);
        },
      ),
    );
  }

  // Chamado pelo onDismissed do Dismissible — deve ser síncrono
  void _dismiss(Transaction tx) {
    setState(() => _dismissedIds.add(tx.id)); // remove da lista imediatamente
    _deleteApi(tx);
  }

  Future<void> _deleteApi(Transaction tx) async {
    try {
      await api.delete('/transactions/${tx.id}');
      ref.invalidate(transactionsProvider);
      ref.invalidate(dashboardProvider);
    } catch (e) {
      if (mounted) {
        setState(() => _dismissedIds.remove(tx.id)); // restaura se falhou
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir: $e')),
        );
      }
    }
  }
}

// ── Period toggle ─────────────────────────────────────────────────────────────

class _PeriodToggle extends StatelessWidget {
  final TxPeriod selected;
  final WidgetRef ref;

  const _PeriodToggle({required this.selected, required this.ref});

  static const _labels = {
    TxPeriod.thisMonth: 'Este Mês',
    TxPeriod.upcoming: 'Próximos',
    TxPeriod.past: 'Anteriores',
    TxPeriod.all: 'Tudo',
  };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: TxPeriod.values.map((v) => _tab(v, context)).toList(),
      ),
    );
  }

  Widget _tab(TxPeriod value, BuildContext context) {
    final active = selected == value;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => ref.read(_periodProvider.notifier).state = value,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? context.appPrimary : context.appSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? context.appPrimary : context.appBorder),
        ),
        child: Text(
          _labels[value]!,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ── Date group ────────────────────────────────────────────────────────────────

class _DateGroup extends StatelessWidget {
  final String date;
  final List<Transaction> transactions;
  final void Function(Transaction) onEdit;
  final void Function(Transaction) onDelete;

  const _DateGroup({
    required this.date,
    required this.transactions,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final parsed = DateTime.tryParse(date);
    final label = parsed != null
        ? DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(parsed)
        : date;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textMuted,
              letterSpacing: 0.3,
            ),
          ),
        ),
        ...transactions.map((tx) => _TxItem(
              tx: tx,
              onEdit: () => onEdit(tx),
              onDelete: () => onDelete(tx),
            )),
      ],
    );
  }
}

// ── Transaction item ──────────────────────────────────────────────────────────

class _TxItem extends StatelessWidget {
  final Transaction tx;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TxItem({required this.tx, required this.onEdit, required this.onDelete});

  Color _parseColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return AppTheme.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = tx.category != null ? _parseColor(tx.category!.color) : context.appPrimary;
    final isIncome = tx.isIncome;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey(tx.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: AppTheme.red.withAlpha(30),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.red.withAlpha(60)),
          ),
          child: const Icon(Icons.delete_outline, color: AppTheme.red, size: 22),
        ),
        confirmDismiss: (_) => showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: context.appSurface,
            title: const Text('Excluir transação'),
            content: Text('Excluir "${tx.description}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Excluir',
                    style: TextStyle(color: AppTheme.red, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        onDismissed: (_) => onDelete(),
        child: AppCard(
          onTap: onEdit,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isIncome ? Icons.trending_up : Icons.trending_down,
                  size: 18,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.description,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tx.category?.name ?? 'Sem categoria',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              CurrencyText(
                isIncome ? tx.amount : -tx.amount,
                fontSize: 14,
                color: isIncome ? AppTheme.green : AppTheme.red,
                showSign: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Transaction form (bottom sheet) ──────────────────────────────────────────

class _TransactionForm extends ConsumerStatefulWidget {
  final Transaction? existing;
  final VoidCallback onSaved;

  const _TransactionForm({this.existing, required this.onSaved});

  @override
  ConsumerState<_TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends ConsumerState<_TransactionForm> {
  final _formKey = GlobalKey<FormState>();
  late final _descController = TextEditingController(text: widget.existing?.description);
  late final _amountController = TextEditingController(
    text: widget.existing != null
        ? widget.existing!.amount.toStringAsFixed(2).replaceAll('.', ',')
        : '',
  );

  late String _type = widget.existing?.type ?? 'expense';
  late DateTime _date = widget.existing != null
      ? DateTime.tryParse(widget.existing!.transactionDate) ?? DateTime.now()
      : DateTime.now();
  late int? _accountId = widget.existing?.accountId;
  late int? _categoryId = widget.existing?.categoryId;
  int _installments = 1;
  bool _saving = false;

  @override
  void dispose() {
    _descController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final rawAmount = _amountController.text.trim().replaceAll('.', '').replaceAll(',', '.');
      final data = {
        'description': _descController.text.trim(),
        'amount': double.parse(rawAmount),
        'type': _type,
        'transaction_date': DateFormat('yyyy-MM-dd').format(_date),
        'account_id': _accountId,
        if (_categoryId != null) 'category_id': _categoryId,
        if (widget.existing == null && _installments > 1) 'installments': _installments,
      };
      if (widget.existing != null) {
        await api.put('/transactions/${widget.existing!.id}', data: data);
      } else {
        await api.post('/transactions', data: data);
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final categoriesAsync = ref.watch(categoriesProvider(_type));
    final inset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      margin: EdgeInsets.only(bottom: inset),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.appBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.existing != null ? 'Editar Transação' : 'Nova Transação',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              _TypeToggle(
                current: _type,
                onChanged: (v) => setState(() {
                  _type = v;
                  _categoryId = null;
                }),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Descrição'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Informe a descrição' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Valor',
                  prefixText: 'R\$ ',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Informe o valor';
                  final parsed =
                      double.tryParse(v.trim().replaceAll('.', '').replaceAll(',', '.'));
                  if (parsed == null || parsed <= 0) return 'Valor inválido';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _DatePickerField(
                date: _date,
                onChanged: (d) => setState(() => _date = d),
              ),
              const SizedBox(height: 12),
              accountsAsync.when(
                data: (accounts) {
                  final selectedAccount = accounts.where((a) => a.id == _accountId).firstOrNull;
                  final isCreditCard = selectedAccount?.isCreditCard ?? false;
                  return Column(
                    children: [
                      DropdownButtonFormField<int>(
                        initialValue: _accountId,
                        decoration: const InputDecoration(labelText: 'Conta'),
                        dropdownColor: context.appBg,
                        items: accounts
                            .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
                            .toList(),
                        onChanged: (v) => setState(() {
                          _accountId = v;
                          _installments = 1;
                        }),
                        validator: (v) => v == null ? 'Selecione a conta' : null,
                      ),
                      if (widget.existing == null && _type == 'expense' && isCreditCard) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          initialValue: _installments,
                          decoration: const InputDecoration(labelText: 'Parcelas'),
                          dropdownColor: context.appBg,
                          items: List.generate(
                            48,
                            (i) => DropdownMenuItem(
                              value: i + 1,
                              child: Text(i == 0 ? '1x (à vista)' : '${i + 1}x'),
                            ),
                          ),
                          onChanged: (v) => setState(() => _installments = v ?? 1),
                        ),
                      ],
                    ],
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 12),
              categoriesAsync.when(
                // key: ValueKey(_type) force-resets o dropdown quando o tipo muda
                data: (cats) => DropdownButtonFormField<int?>(
                  key: ValueKey(_type),
                  initialValue: _categoryId,
                  decoration: const InputDecoration(labelText: 'Categoria (opcional)'),
                  dropdownColor: context.appBg,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Sem categoria')),
                    ...cats.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                  ],
                  onChanged: (v) => setState(() => _categoryId = v),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(widget.existing != null ? 'Salvar alterações' : 'Criar transação'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Type toggle ───────────────────────────────────────────────────────────────

class _TypeToggle extends StatelessWidget {
  final String current;
  final void Function(String) onChanged;

  const _TypeToggle({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.appBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appBorder),
      ),
      child: Row(children: [
        _tab('expense', 'Despesa', AppTheme.red),
        _tab('income', 'Receita', AppTheme.green),
      ]),
    );
  }

  Widget _tab(String value, String label, Color color) {
    final active = current == value;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? color.withAlpha(30) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: active ? Border.all(color: color.withAlpha(80)) : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: active ? color : AppTheme.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Date picker field ─────────────────────────────────────────────────────────

class _DatePickerField extends StatelessWidget {
  final DateTime date;
  final void Function(DateTime) onChanged;

  const _DatePickerField({required this.date, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.appBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined, size: 18, color: AppTheme.textMuted),
            const SizedBox(width: 10),
            Text(
              DateFormat("d 'de' MMMM 'de' yyyy", 'pt_BR').format(date),
              style: const TextStyle(fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}
