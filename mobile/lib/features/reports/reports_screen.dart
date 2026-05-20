import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/models.dart';
import '../../core/api/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/currency_text.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

Color _hexColor(String hex) {
  try {
    return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
  } catch (_) {
    return AppTheme.primaryColor;
  }
}

const _monthAbbr = [
  'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
  'jul', 'ago', 'set', 'out', 'nov', 'dez',
];

// ── State providers ───────────────────────────────────────────────────────────

final _reportYearProvider = StateProvider<int>((ref) => DateTime.now().year);
final _reportMonthProvider = StateProvider<int?>((ref) => null);

// ── Screen ────────────────────────────────────────────────────────────────────

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = ref.watch(_reportYearProvider);
    final selectedMonth = ref.watch(_reportMonthProvider);
    final reportAsync = ref.watch(monthlyReportProvider(year));

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Header + year nav
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
              child: Row(
                children: [
                  const Text('Relatórios',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () =>
                        ref.read(_reportYearProvider.notifier).state = year - 1,
                  ),
                  Text('$year',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: year < DateTime.now().year
                        ? () =>
                            ref.read(_reportYearProvider.notifier).state =
                                year + 1
                        : null,
                  ),
                ],
              ),
            ),
          ),

          // Bar chart
          SliverToBoxAdapter(
            child: reportAsync.when(
              data: (data) => _BarChart(
                data: data,
                selectedMonth: selectedMonth,
                onTap: (m) {
                  final cur = ref.read(_reportMonthProvider);
                  ref.read(_reportMonthProvider.notifier).state =
                      cur == m ? null : m;
                },
              ),
              loading: () => const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => SizedBox(
                height: 220,
                child: Center(child: Text('Erro: $e')),
              ),
            ),
          ),

          // Month detail
          if (selectedMonth != null)
            SliverToBoxAdapter(
              child: _MonthDetail(year: year, month: selectedMonth),
            )
          else
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 24, 16, 0),
                child: Text(
                  'Toque em um mês para ver o detalhamento.',
                  style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 48)),
        ],
      ),
    );
  }
}

// ── Bar chart ─────────────────────────────────────────────────────────────────

class _BarChart extends StatelessWidget {
  final List<MonthlySummary> data;
  final int? selectedMonth;
  final ValueChanged<int> onTap;

  const _BarChart(
      {required this.data,
      required this.selectedMonth,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final maxY = data.fold(0.0, (m, s) => max(m, max(s.income, s.expense)));
    final chartMax = maxY > 0 ? maxY * 1.2 : 1000.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 16, 8),
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: chartMax,
                barGroups: List.generate(12, (i) {
                  final s = data.length > i ? data[i] : null;
                  final isSelected = selectedMonth == i + 1;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: s?.income ?? 0,
                        color: isSelected
                            ? AppTheme.green
                            : AppTheme.green.withAlpha(130),
                        width: 5,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      BarChartRodData(
                        toY: s?.expense ?? 0,
                        color: isSelected
                            ? AppTheme.red
                            : AppTheme.red.withAlpha(130),
                        width: 5,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ],
                  );
                }),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: context.appBorder, strokeWidth: 0.5),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        final isSelected = selectedMonth == i + 1;
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _monthAbbr[i],
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                              color: isSelected
                                  ? context.appPrimary
                                  : AppTheme.textMuted,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchCallback: (event, response) {
                    if (event is FlTapUpEvent &&
                        response?.spot != null) {
                      onTap(response!.spot!.touchedBarGroupIndex + 1);
                    }
                  },
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => context.appBg,
                    tooltipBorder: BorderSide(color: context.appBorder),
                    getTooltipItem: (group, _, rod, rodIndex) {
                      final s = data.length > group.x ? data[group.x] : null;
                      if (s == null) return null;
                      final isIncome = rodIndex == 0;
                      return BarTooltipItem(
                        isIncome
                            ? 'R ${fmtBrl(s.income)}'
                            : 'D ${fmtBrl(s.expense)}',
                        TextStyle(
                          fontSize: 10,
                          color: isIncome ? AppTheme.green : AppTheme.red,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _legend(AppTheme.green, 'Receitas'),
            const SizedBox(width: 20),
            _legend(AppTheme.red, 'Despesas'),
          ]),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label) => Row(children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label,
            style:
                const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ]);
}

// ── Month detail ──────────────────────────────────────────────────────────────

class _MonthDetail extends ConsumerWidget {
  final int year;
  final int month;

  const _MonthDetail({required this.year, required this.month});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(monthlyDetailProvider((year, month)));

    return detailAsync.when(
      data: (detail) => _buildContent(context, detail),
      loading: () => const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) =>
          Padding(padding: const EdgeInsets.all(16), child: Text('Erro: $e')),
    );
  }

  Widget _buildContent(BuildContext context, MonthlyDetail detail) {
    final dateFmt = DateFormat('MMMM y', 'pt_BR');
    final monthDate = DateTime(year, month);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month title
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(
              dateFmt.format(monthDate),
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary),
            ),
          ),

          // Summary row
          Row(
            children: [
              _SummaryCard(label: 'Receitas', value: detail.income, color: AppTheme.green),
              const SizedBox(width: 8),
              _SummaryCard(label: 'Despesas', value: detail.expense, color: AppTheme.red),
              const SizedBox(width: 8),
              _SummaryCard(
                label: 'Saldo',
                value: detail.balance,
                color: detail.balance >= 0 ? AppTheme.green : AppTheme.red,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Expense by category
          if (detail.expenseByCategory.isNotEmpty) ...[
            _sectionTitle('Por categoria'),
            const SizedBox(height: 10),
            ...detail.expenseByCategory.map((c) => _CategoryBar(cat: c)),
            const SizedBox(height: 20),
          ],

          // Top transactions
          if (detail.topTransactions.isNotEmpty) ...[
            _sectionTitle('Maiores despesas'),
            const SizedBox(height: 10),
            ...detail.topTransactions
                .take(10)
                .map((t) => _TopTxTile(tx: t)),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(text,
      style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textMuted));
}

// ── Summary card ──────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _SummaryCard(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 10, color: AppTheme.textMuted)),
            const SizedBox(height: 4),
            CurrencyText(value, fontSize: 13, color: color, fontWeight: FontWeight.w700),
          ],
        ),
      ),
    );
  }
}

// ── Category bar ──────────────────────────────────────────────────────────────

class _CategoryBar extends StatelessWidget {
  final CategorySummary cat;

  const _CategoryBar({required this.cat});

  @override
  Widget build(BuildContext context) {
    final color = _hexColor(cat.categoryColor);
    final pct = (cat.percentage / 100).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(cat.categoryName,
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis),
              ),
              CurrencyText(cat.total, fontSize: 13, color: AppTheme.red),
              const SizedBox(width: 8),
              SizedBox(
                width: 36,
                child: Text(
                  '${cat.percentage.toStringAsFixed(0)}%',
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textMuted),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: context.appBorder,
              color: color,
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Top transaction tile ──────────────────────────────────────────────────────

class _TopTxTile extends StatelessWidget {
  final Transaction tx;

  const _TopTxTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    final color = tx.category != null
        ? _hexColor(tx.category!.color)
        : context.appPrimary;
    final date = DateTime.tryParse(tx.transactionDate);
    final dateStr =
        date != null ? DateFormat('dd/MM', 'pt_BR').format(date) : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: color.withAlpha(30), shape: BoxShape.circle),
              child: Icon(Icons.trending_down, size: 15, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tx.description,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis),
                  if (tx.category != null)
                    Text(tx.category!.name,
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textMuted)),
                ],
              ),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              CurrencyText(tx.amount, fontSize: 13, color: AppTheme.red),
              Text(dateStr,
                  style: const TextStyle(
                      fontSize: 10, color: AppTheme.textMuted)),
            ]),
          ],
        ),
      ),
    );
  }
}
