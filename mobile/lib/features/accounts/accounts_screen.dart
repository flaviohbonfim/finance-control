import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/api/models.dart';
import '../../core/api/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_skeleton.dart';
import '../../shared/widgets/currency_text.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

Color _hexColor(String hex) {
  try {
    return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
  } catch (_) {
    return AppTheme.primaryColor;
  }
}

String _typeLabel(String type) => switch (type) {
      'checking' => 'Conta Corrente',
      'savings' => 'Poupança',
      'credit_card' => 'Cartão de Crédito',
      'investment' => 'Investimento',
      'cash' => 'Dinheiro',
      _ => type,
    };

const _kTypes = ['checking', 'savings', 'credit_card', 'investment', 'cash'];

// ── Accounts screen ───────────────────────────────────────────────────────────

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 20),
            child: Row(
              children: [
                const Text('Contas',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Nova conta',
                  onPressed: () => _openForm(context, ref, null),
                ),
              ],
            ),
          ),
          Expanded(
            child: accountsAsync.when(
              data: (accounts) => RefreshIndicator(
                onRefresh: () => ref.refresh(accountsProvider.future),
                child: _buildList(context, ref, accounts),
              ),
              loading: () => const _AccountsSkeleton(),
              error: (e, _) => Center(child: Text('Erro: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, WidgetRef ref, List<Account> accounts) {
    if (accounts.isEmpty) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.account_balance_wallet_outlined,
                      size: 52, color: AppTheme.textMuted),
                  const SizedBox(height: 12),
                  const Text('Nenhuma conta cadastrada',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 15)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Criar conta'),
                    onPressed: () => _openForm(context, ref, null),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final regular = accounts.where((a) => !a.isCreditCard).toList();
    final cards = accounts.where((a) => a.isCreditCard).toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        if (regular.isNotEmpty) ...[
          _sectionHeader('Contas'),
          ...regular.map((a) => _AccountCard(
                account: a,
                onTap: () => _openForm(context, ref, a),
                onEdit: () => _openForm(context, ref, a),
                onDelete: () => _confirmDelete(context, ref, a),
              )),
          const SizedBox(height: 8),
        ],
        if (cards.isNotEmpty) ...[
          _sectionHeader('Cartões de Crédito'),
          ...cards.map((a) => _AccountCard(
                account: a,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => _InvoiceScreen(account: a, allAccounts: accounts),
                )),
                onEdit: () => _openForm(context, ref, a),
                onDelete: () => _confirmDelete(context, ref, a),
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

  void _openForm(BuildContext context, WidgetRef ref, Account? account) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AccountFormSheet(
        account: account,
        onSaved: () {
          ref.invalidate(accountsProvider);
          ref.invalidate(dashboardProvider);
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Account account) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.appSurface,
        title: const Text('Excluir conta'),
        content: Text('Deseja excluir "${account.name}"? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await api.delete('/accounts/${account.id}');
                ref.invalidate(accountsProvider);
                ref.invalidate(dashboardProvider);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Erro ao excluir: $e')));
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

// ── Account card ──────────────────────────────────────────────────────────────

class _AccountCard extends StatelessWidget {
  final Account account;
  final VoidCallback? onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AccountCard({
    required this.account,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = _hexColor(account.color);
    final isCredit = account.isCreditCard;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Row(
            children: [
              Container(width: 4, height: isCredit ? 110 : 72, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                  child: isCredit ? _creditContent(color, context) : _regularContent(color),
                ),
              ),
              // The PopupMenuButton absorbs its own tap so the card's onTap is not triggered
              PopupMenuButton<String>(
                color: context.appSurface,
                icon: const Icon(Icons.more_vert, size: 20, color: AppTheme.textMuted),
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Editar')),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Excluir', style: TextStyle(color: AppTheme.red)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _regularContent(Color color) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(account.name,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              _TypeBadge(label: _typeLabel(account.type), color: color),
            ],
          ),
        ),
        CurrencyText(
          account.balance,
          fontSize: 16,
          color: account.balance >= 0 ? AppTheme.green : AppTheme.red,
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _creditContent(Color color, BuildContext context) {
    final limit = account.creditLimit ?? 0;
    final used = account.balance.abs();
    final pct = limit > 0 ? (used / limit).clamp(0.0, 1.0) : 0.0;
    final barColor = pct > 0.8 ? AppTheme.red : pct > 0.5 ? Colors.orange : AppTheme.green;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(account.name,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  _TypeBadge(label: _typeLabel(account.type), color: color),
                ],
              ),
            ),
            if (account.dueDay != null)
              Text('Vence dia ${account.dueDay}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            const SizedBox(width: 4),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Fatura atual',
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            if (limit > 0)
              Text('Limite: ${(pct * 100).toStringAsFixed(0)}% usado',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            CurrencyText(used, fontSize: 15, color: used > 0 ? AppTheme.red : Colors.white),
            if (limit > 0) ...[
              const Spacer(),
              Text('de ${fmtBrl(limit)}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            ],
          ],
        ),
        if (limit > 0) ...[
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: context.appBorder,
              color: barColor,
              minHeight: 4,
            ),
          ),
        ],
      ],
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _TypeBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

// ── Account form sheet (create / edit) ────────────────────────────────────────

class _AccountFormSheet extends ConsumerStatefulWidget {
  final Account? account;
  final VoidCallback onSaved;

  const _AccountFormSheet({required this.account, required this.onSaved});

  @override
  ConsumerState<_AccountFormSheet> createState() => _AccountFormSheetState();
}

class _AccountFormSheetState extends ConsumerState<_AccountFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late final _nameCtrl = TextEditingController(text: widget.account?.name ?? '');
  late final _colorCtrl =
      TextEditingController(text: widget.account?.color ?? '#6366f1');
  late final _balanceCtrl = TextEditingController(
      text: widget.account == null ? '0,00' : '');
  late final _limitCtrl = TextEditingController(
      text: widget.account?.creditLimit?.toStringAsFixed(2).replaceAll('.', ',') ?? '');
  late final _closingCtrl =
      TextEditingController(text: widget.account?.closingDay?.toString() ?? '');
  late final _dueCtrl =
      TextEditingController(text: widget.account?.dueDay?.toString() ?? '');

  late String _type = widget.account?.type ?? 'checking';
  bool _saving = false;

  bool get _isCredit => _type == 'credit_card';
  bool get _isEdit => widget.account != null;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _colorCtrl.dispose();
    _balanceCtrl.dispose();
    _limitCtrl.dispose();
    _closingCtrl.dispose();
    _dueCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final color = _colorCtrl.text.trim();
    final limitRaw = _limitCtrl.text.trim().replaceAll('.', '').replaceAll(',', '.');
    final limit = limitRaw.isNotEmpty ? double.tryParse(limitRaw) : null;
    final closing = int.tryParse(_closingCtrl.text.trim());
    final due = int.tryParse(_dueCtrl.text.trim());

    try {
      if (_isEdit) {
        await api.put('/accounts/${widget.account!.id}', data: {
          'name': _nameCtrl.text.trim(),
          'type': _type,
          'color': color,
          if (_isCredit && limit != null) 'credit_limit': limit,
          if (_isCredit && closing != null) 'closing_day': closing,
          if (_isCredit && due != null) 'due_day': due,
        });
      } else {
        final balRaw =
            _balanceCtrl.text.trim().replaceAll('.', '').replaceAll(',', '.');
        final balance = double.tryParse(balRaw) ?? 0.0;
        await api.post('/accounts', data: {
          'name': _nameCtrl.text.trim(),
          'type': _type,
          'color': color,
          'balance': balance,
          if (_isCredit && limit != null) 'credit_limit': limit,
          if (_isCredit && closing != null) 'closing_day': closing,
          if (_isCredit && due != null) 'due_day': due,
        });
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
              Text(_isEdit ? 'Editar conta' : 'Nova conta',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Nome'),
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _type,
                dropdownColor: context.appBg,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: _kTypes
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(_typeLabel(t)),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _type = v);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _colorCtrl,
                decoration: const InputDecoration(labelText: 'Cor (hex)', hintText: '#6366f1'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Informe a cor';
                  final hex = v.trim().replaceAll('#', '');
                  if (hex.length != 6) return 'Use formato #RRGGBB';
                  return null;
                },
              ),
              if (!_isEdit) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _balanceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      const InputDecoration(labelText: 'Saldo inicial', prefixText: 'R\$ '),
                ),
              ],
              if (_isCredit) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _limitCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      const InputDecoration(labelText: 'Limite de crédito', prefixText: 'R\$ '),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _closingCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Dia fechamento'),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final d = int.tryParse(v.trim());
                          if (d == null || d < 1 || d > 31) return '1–31';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _dueCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Dia vencimento'),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final d = int.tryParse(v.trim());
                          if (d == null || d < 1 || d > 31) return '1–31';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child:
                              CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(_isEdit ? 'Salvar alterações' : 'Criar conta'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Invoice screen ────────────────────────────────────────────────────────────

class _InvoiceScreen extends ConsumerWidget {
  final Account account;
  final List<Account> allAccounts;

  const _InvoiceScreen({required this.account, required this.allAccounts});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoiceAsync = ref.watch(invoiceProvider(account.id));

    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        title: Text(account.name),
        actions: [
          invoiceAsync.valueOrNull != null
              ? _payButton(context, ref, invoiceAsync.value!)
              : const SizedBox.shrink(),
        ],
      ),
      body: invoiceAsync.when(
        data: (inv) => _buildBody(context, ref, inv),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
      ),
    );
  }

  Widget _payButton(BuildContext context, WidgetRef ref, InvoiceData inv) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: TextButton.icon(
        onPressed: () => _openPaySheet(context, ref, inv),
        icon: const Icon(Icons.payment, size: 18),
        label: const Text('Pagar'),
        style: TextButton.styleFrom(foregroundColor: AppTheme.green),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, InvoiceData inv) {
    final fmt = DateFormat('dd/MM', 'pt_BR');
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        AppCard(
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Ciclo atual',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                const SizedBox(height: 2),
                Text(
                  '${fmt.format(DateTime.parse(inv.currentStart))} – ${fmt.format(DateTime.parse(inv.currentEnd))}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 6),
                CurrencyText(inv.currentTotal, fontSize: 20, color: AppTheme.red),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Text('Próximo ciclo',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              const SizedBox(height: 2),
              Text(
                '${fmt.format(DateTime.parse(inv.nextStart))} – ${fmt.format(DateTime.parse(inv.nextEnd))}',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 6),
              CurrencyText(inv.nextTotal, fontSize: 18, color: AppTheme.textSecondary),
            ]),
          ]),
        ),
        const SizedBox(height: 20),
        _sectionTitle('Ciclo atual · ${inv.currentTransactions.length} lançamento(s)'),
        if (inv.currentTransactions.isEmpty)
          _emptyHint('Nenhum lançamento neste ciclo')
        else
          ...inv.currentTransactions.map((tx) => _InvoiceTxTile(tx: tx)),
        const SizedBox(height: 20),
        _sectionTitle('Próximo ciclo · ${inv.nextTransactions.length} lançamento(s)'),
        if (inv.nextTransactions.isEmpty)
          _emptyHint('Nenhum lançamento no próximo ciclo')
        else
          ...inv.nextTransactions.map((tx) => _InvoiceTxTile(tx: tx)),
      ],
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
      );

  Widget _emptyHint(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(text,
            style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
      );

  void _openPaySheet(BuildContext context, WidgetRef ref, InvoiceData inv) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PayInvoiceSheet(
        account: account,
        invoiceTotal: inv.currentTotal,
        nonCardAccounts: allAccounts.where((a) => !a.isCreditCard).toList(),
        onPaid: () {
          ref.invalidate(invoiceProvider(account.id));
          ref.invalidate(accountsProvider);
          ref.invalidate(dashboardProvider);
        },
      ),
    );
  }
}

// ── Invoice transaction tile ──────────────────────────────────────────────────

class _InvoiceTxTile extends StatelessWidget {
  final Transaction tx;

  const _InvoiceTxTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    final color = tx.category != null
        ? _hexColor(tx.category!.color)
        : context.appPrimary;
    final date = DateTime.tryParse(tx.transactionDate);
    final dateStr = date != null ? DateFormat('dd/MM', 'pt_BR').format(date) : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration:
                BoxDecoration(color: color.withAlpha(30), shape: BoxShape.circle),
            child: Icon(Icons.trending_down, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tx.description,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(tx.category?.name ?? 'Sem categoria',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            CurrencyText(tx.amount, fontSize: 14, color: AppTheme.red),
            const SizedBox(height: 2),
            Text(dateStr, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          ]),
        ]),
      ),
    );
  }
}

// ── Pay invoice sheet ─────────────────────────────────────────────────────────

class _PayInvoiceSheet extends ConsumerStatefulWidget {
  final Account account;
  final double invoiceTotal;
  final List<Account> nonCardAccounts;
  final VoidCallback onPaid;

  const _PayInvoiceSheet({
    required this.account,
    required this.invoiceTotal,
    required this.nonCardAccounts,
    required this.onPaid,
  });

  @override
  ConsumerState<_PayInvoiceSheet> createState() => _PayInvoiceSheetState();
}

class _PayInvoiceSheetState extends ConsumerState<_PayInvoiceSheet> {
  late final _amountController = TextEditingController(
    text: widget.invoiceTotal.toStringAsFixed(2).replaceAll('.', ','),
  );
  int? _sourceAccountId;
  bool _paying = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    if (_sourceAccountId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Selecione a conta de origem')));
      return;
    }
    final raw =
        _amountController.text.trim().replaceAll('.', '').replaceAll(',', '.');
    final amount = double.tryParse(raw);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Valor inválido')));
      return;
    }
    setState(() => _paying = true);
    try {
      await api.post('/accounts/${widget.account.id}/pay-invoice',
          data: {'source_account_id': _sourceAccountId, 'amount': amount});
      widget.onPaid();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _paying = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao pagar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      margin: EdgeInsets.only(bottom: inset),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: context.appBorder, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text('Pagar fatura · ${widget.account.name}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          TextFormField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Valor', prefixText: 'R\$ '),
          ),
          const SizedBox(height: 12),
          if (widget.nonCardAccounts.isEmpty)
            const Text('Nenhuma conta disponível para pagamento.',
                style: TextStyle(color: AppTheme.textMuted))
          else
            DropdownButtonFormField<int>(
              initialValue: _sourceAccountId,
              decoration: const InputDecoration(labelText: 'Pagar com'),
              dropdownColor: context.appBg,
              items: widget.nonCardAccounts
                  .map((a) => DropdownMenuItem(
                        value: a.id,
                        child: Text('${a.name} (${fmtBrl(a.balance)})'),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _sourceAccountId = v),
            ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _paying ? null : _pay,
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.green),
              child: _paying
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child:
                          CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Confirmar pagamento'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Accounts skeleton ─────────────────────────────────────────────────────────

class _AccountsSkeleton extends StatelessWidget {
  const _AccountsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      itemCount: 4,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            color: context.appSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.appBorder),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            AppSkeleton(width: 4, height: 48, radius: 2),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppSkeleton(width: 120, height: 14),
                  const SizedBox(height: 8),
                  AppSkeleton(width: 60, height: 10),
                ],
              ),
            ),
            AppSkeleton(width: 80, height: 18),
          ]),
        ),
      ),
    );
  }
}
