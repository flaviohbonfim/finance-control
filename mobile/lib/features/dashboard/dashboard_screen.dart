import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api/models.dart';
import '../../core/api/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_skeleton.dart';
import '../../shared/widgets/currency_text.dart';
import '../recurring/launch_modal.dart';

enum DashView { month, general }

final _dashViewProvider = StateProvider<DashView>((ref) => DashView.month);

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String get _monthLabel {
    final now = DateTime.now();
    return DateFormat("MMMM 'de' yyyy", 'pt_BR').format(now);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(_dashViewProvider);
    final dashAsync = ref.watch(dashboardProvider);
    final billsAsync = ref.watch(creditCardBillsProvider);

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(context, view, ref)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverToBoxAdapter(
              child: dashAsync.when(
                data: (data) => view == DashView.month
                    ? _MonthView(data: data, billsAsync: billsAsync, ref: ref)
                    : _GeneralView(data: data),
                loading: () => const _DashboardSkeleton(),
                error: (e, _) => Center(child: Text('Erro: $e')),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, DashView view, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Dashboard',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                Text(_monthLabel,
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          _ViewToggle(current: view, ref: ref),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 22),
            color: AppTheme.textMuted,
            tooltip: 'Configurações',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
    );
  }
}

// ── View toggle ───────────────────────────────────────────────────────────────

class _ViewToggle extends StatelessWidget {
  final DashView current;
  final WidgetRef ref;

  const _ViewToggle({required this.current, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.appBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _tab(context, DashView.month, 'Mês Atual'),
          _tab(context, DashView.general, 'Geral'),
        ],
      ),
    );
  }

  Widget _tab(BuildContext context, DashView value, String label) {
    final active = current == value;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => ref.read(_dashViewProvider.notifier).state = value,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? context.appPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }
}

// ── Mês Atual view ────────────────────────────────────────────────────────────

class _MonthView extends StatelessWidget {
  final DashboardSummary data;
  final AsyncValue<List<CreditCardBill>> billsAsync;
  final WidgetRef ref;

  const _MonthView({required this.data, required this.billsAsync, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stat cards
        Row(children: [
          Expanded(
            child: _StatCard(
              label: 'Receitas',
              value: data.monthlyIncome,
              icon: Icons.trending_up,
              color: AppTheme.green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              label: 'Despesas',
              value: data.monthlyExpense,
              icon: Icons.trending_down,
              color: AppTheme.red,
            ),
          ),
        ]),
        const SizedBox(height: 12),
        _StatCard(
          label: 'Saldo do Mês',
          value: data.monthlyBalance,
          icon: data.monthlyBalance >= 0 ? Icons.trending_up : Icons.trending_down,
          color: data.monthlyBalance >= 0 ? AppTheme.green : AppTheme.red,
          wide: true,
        ),
        const SizedBox(height: 20),

        // Credit card bills
        _CreditCardSection(billsAsync: billsAsync),
        const SizedBox(height: 20),

        // Expense by category
        if (data.expenseByCategory.isNotEmpty) ...[
          _CategoryPieCard(categories: data.expenseByCategory),
          const SizedBox(height: 20),
        ],

        // Recurring
        if (data.recurringThisMonth.isNotEmpty) ...[
          _RecurringCard(items: data.recurringThisMonth, ref: ref),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

// ── Geral view ────────────────────────────────────────────────────────────────

class _GeneralView extends StatelessWidget {
  final DashboardSummary data;

  const _GeneralView({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 4 stat cards
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _StatCard(
                label: 'Saldo Total',
                value: data.totalBalance,
                icon: Icons.account_balance_wallet,
                color: context.appPrimary),
            _StatCard(
                label: 'Receitas',
                value: data.monthlyIncome,
                icon: Icons.trending_up,
                color: AppTheme.green),
            _StatCard(
                label: 'Despesas',
                value: data.monthlyExpense,
                icon: Icons.trending_down,
                color: AppTheme.red),
            _StatCard(
                label: 'Saldo do Mês',
                value: data.monthlyBalance,
                icon: data.monthlyBalance >= 0 ? Icons.trending_up : Icons.trending_down,
                color: data.monthlyBalance >= 0 ? AppTheme.green : AppTheme.red),
          ],
        ),
        const SizedBox(height: 20),

        // Bar chart
        _BarChartCard(monthlyChart: data.monthlyChart),
        const SizedBox(height: 20),

        // Category pie
        if (data.expenseByCategory.isNotEmpty) ...[
          _CategoryPieCard(categories: data.expenseByCategory),
          const SizedBox(height: 20),
        ],

        // Recent transactions
        _RecentTransactionsCard(transactions: data.recentTransactions),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ── Stat card (local) ─────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final double value;
  final IconData icon;
  final Color color;
  final bool wide;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 6),
                CurrencyText(value, fontSize: wide ? 20 : 16, color: color),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
        ],
      ),
    );
  }
}

// ── Credit card bills section ─────────────────────────────────────────────────

class _CreditCardSection extends StatelessWidget {
  final AsyncValue<List<CreditCardBill>> billsAsync;

  const _CreditCardSection({required this.billsAsync});

  @override
  Widget build(BuildContext context) {
    return billsAsync.when(
      data: (bills) {
        if (bills.isEmpty) return const SizedBox.shrink();
        final totalCurrent = bills.fold(0.0, (s, b) => s + b.currentBill.total);
        final totalNext = bills.fold(0.0, (s, b) => s + b.nextBill.total);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Faturas dos Cartões',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            AppCard(
              color: context.appBg,
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Ciclo atual (total)',
                        style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    const SizedBox(height: 2),
                    CurrencyText(totalCurrent, fontSize: 15, color: Colors.white),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  const Text('Próximo ciclo (total)',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  const SizedBox(height: 2),
                  CurrencyText(totalNext, fontSize: 15, color: AppTheme.red),
                ]),
              ]),
            ),
            const SizedBox(height: 12),
            ...bills.map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _BillCard(bill: b),
                )),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _BillCard extends StatelessWidget {
  final CreditCardBill bill;

  const _BillCard({required this.bill});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: context.appPrimary.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.credit_card, size: 16, color: context.appPrimary),
            ),
            const SizedBox(width: 10),
            Text(bill.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          ]),
          const SizedBox(height: 12),
          Text('Ciclo atual · ${bill.currentBill.period}',
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          const SizedBox(height: 2),
          CurrencyText(bill.currentBill.total, fontSize: 16, color: Colors.white),
          Divider(height: 16, color: context.appBorder),
          Text('Próximo ciclo · ${bill.nextBill.period}',
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          const SizedBox(height: 2),
          CurrencyText(bill.nextBill.total, fontSize: 16, color: AppTheme.red),
          if (bill.dueDay != null) ...[
            const SizedBox(height: 8),
            Text('Vencimento dia ${bill.dueDay}',
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          ],
        ],
      ),
    );
  }
}

// ── Category pie ──────────────────────────────────────────────────────────────

class _CategoryPieCard extends StatelessWidget {
  final List<CategorySummary> categories;

  const _CategoryPieCard({required this.categories});

  Color _parseColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return AppTheme.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Despesas por Categoria',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: Row(children: [
              SizedBox(
                width: 140,
                child: PieChart(PieChartData(
                  sections: categories.map((c) {
                    return PieChartSectionData(
                      value: c.total,
                      color: _parseColor(c.categoryColor),
                      radius: 45,
                      showTitle: false,
                    );
                  }).toList(),
                  centerSpaceRadius: 30,
                  sectionsSpace: 2,
                )),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: categories.map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _parseColor(c.categoryColor),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(c.categoryName,
                              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                              overflow: TextOverflow.ellipsis),
                        ),
                        Text('${c.percentage.toStringAsFixed(0)}%',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      ]),
                    )).toList(),
                  ),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

// ── Bar chart ─────────────────────────────────────────────────────────────────

class _BarChartCard extends StatelessWidget {
  final List<MonthlySummary> monthlyChart;

  const _BarChartCard({required this.monthlyChart});

  static const _months = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
                           'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];

  String _label(String month) {
    final m = int.tryParse(month.split('-').last) ?? 1;
    return _months[m - 1];
  }

  @override
  Widget build(BuildContext context) {
    final groups = monthlyChart.asMap().entries.map((e) {
      final i = e.key;
      final m = e.value;
      return BarChartGroupData(x: i, barRods: [
        BarChartRodData(
            toY: m.income, color: AppTheme.green, width: 8, borderRadius: BorderRadius.circular(4)),
        BarChartRodData(
            toY: m.expense, color: AppTheme.red, width: 8, borderRadius: BorderRadius.circular(4)),
      ]);
    }).toList();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Últimos 6 Meses',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: BarChart(BarChartData(
              barGroups: groups,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) => Text(
                      _label(monthlyChart[v.toInt()].month),
                      style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                    ),
                  ),
                ),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
            )),
          ),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _legend(AppTheme.green, 'Receitas'),
            const SizedBox(width: 16),
            _legend(AppTheme.red, 'Despesas'),
          ]),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label) => Row(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ]);
}

// ── Recent transactions ───────────────────────────────────────────────────────

class _RecentTransactionsCard extends StatelessWidget {
  final List<Transaction> transactions;

  const _RecentTransactionsCard({required this.transactions});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Transações Recentes',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (transactions.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Nenhuma transação ainda',
                    style: TextStyle(color: AppTheme.textMuted)),
              ),
            )
          else
            ...transactions.map((tx) => _TxTile(tx: tx)),
        ],
      ),
    );
  }
}

class _TxTile extends StatelessWidget {
  final Transaction tx;

  const _TxTile({required this.tx});

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
    final date = DateTime.tryParse(tx.transactionDate);
    final dateStr = date != null ? DateFormat('dd/MM').format(date) : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: color.withAlpha(30), shape: BoxShape.circle),
          child: Icon(isIncome ? Icons.trending_up : Icons.trending_down, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tx.description,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis),
            Text('${tx.category?.name ?? 'Sem categoria'} · $dateStr',
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          ]),
        ),
        CurrencyText(
          isIncome ? tx.amount : -tx.amount,
          fontSize: 13,
          color: isIncome ? AppTheme.green : AppTheme.red,
          showSign: true,
        ),
      ]),
    );
  }
}

// ── Recurring widget ──────────────────────────────────────────────────────────

class _RecurringCard extends StatelessWidget {
  final List<RecurringTransaction> items;
  final WidgetRef ref;

  const _RecurringCard({required this.items, required this.ref});

  Color _parseColor(String? hex) {
    if (hex == null) return AppTheme.primaryColor;
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return AppTheme.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Recorrentes do Mês',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...items.map((rt) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                        color: _parseColor(rt.categoryColor).withAlpha(30),
                        shape: BoxShape.circle),
                    child: Icon(Icons.refresh,
                        size: 15, color: _parseColor(rt.categoryColor)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(rt.description,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis),
                      Text('${rt.accountName ?? ''} · dia ${rt.dueDay}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    ]),
                  ),
                  if (rt.amount != null)
                    CurrencyText(
                      rt.isIncome ? rt.amount! : -rt.amount!,
                      fontSize: 13,
                      color: rt.isIncome ? AppTheme.green : AppTheme.red,
                    ),
                  const SizedBox(width: 8),
                  if (rt.launchedThisMonth)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.green.withAlpha(20),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Lançado',
                          style: TextStyle(fontSize: 10, color: AppTheme.green,
                              fontWeight: FontWeight.w600)),
                    )
                  else
                    GestureDetector(
                      onTap: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => LaunchModal(rt: rt, onDone: () {
                          ref.invalidate(dashboardProvider);
                          ref.invalidate(recurringProvider);
                        }),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: context.appPrimary.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.play_arrow,
                            size: 14, color: context.appPrimary),
                      ),
                    ),
                ]),
              )),
        ],
      ),
    );
  }
}

// ── Dashboard skeleton ────────────────────────────────────────────────────────

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: _skCard(context, height: 80)),
          const SizedBox(width: 12),
          Expanded(child: _skCard(context, height: 80)),
        ]),
        const SizedBox(height: 12),
        _skCard(context, height: 80),
        const SizedBox(height: 20),
        _skCard(context, height: 160),
        const SizedBox(height: 20),
        _skCard(context, height: 200),
      ],
    );
  }

  Widget _skCard(BuildContext context, {required double height}) => Container(
        height: height,
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.appBorder),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AppSkeleton(width: 80, height: 12),
            AppSkeleton(width: 120, height: 20),
          ],
        ),
      );
}
