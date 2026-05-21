import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';
import 'models.dart';

// ── Accounts ──────────────────────────────────────────────────────────────────

final accountsProvider = FutureProvider<List<Account>>((ref) async {
  final res = await api.get('/accounts');
  return (res.data as List).map((e) => Account.fromJson(e)).toList();
});

// ── Categories ────────────────────────────────────────────────────────────────

final categoriesProvider = FutureProvider.family<List<Category>, String?>((ref, type) async {
  final res = await api.get('/categories', params: type != null ? {'type': type} : null);
  return (res.data as List).map((e) => Category.fromJson(e)).toList();
});

// ── Transactions ──────────────────────────────────────────────────────────────

class TransactionParams {
  final int? accountId;
  final int? categoryId;
  final String? type;
  final String? dateFrom;
  final String? dateTo;
  final int page;
  final int pageSize;

  const TransactionParams({
    this.accountId,
    this.categoryId,
    this.type,
    this.dateFrom,
    this.dateTo,
    this.page = 1,
    this.pageSize = 30,
  });

  Map<String, dynamic> toQueryParams() => {
        if (accountId != null) 'account_id': accountId,
        if (categoryId != null) 'category_id': categoryId,
        if (type != null) 'type': type,
        if (dateFrom != null) 'date_from': dateFrom,
        if (dateTo != null) 'date_to': dateTo,
        'page': page,
        'page_size': pageSize,
      };

  @override
  bool operator ==(Object other) =>
      other is TransactionParams &&
      accountId == other.accountId &&
      categoryId == other.categoryId &&
      type == other.type &&
      dateFrom == other.dateFrom &&
      dateTo == other.dateTo &&
      page == other.page &&
      pageSize == other.pageSize;

  @override
  int get hashCode =>
      Object.hash(accountId, categoryId, type, dateFrom, dateTo, page, pageSize);
}

final transactionsProvider =
    FutureProvider.family<PaginatedTransactions, TransactionParams>((ref, params) async {
  final res = await api.get('/transactions', params: params.toQueryParams());
  return PaginatedTransactions.fromJson(res.data);
});

// ── Recurring ─────────────────────────────────────────────────────────────────

final recurringProvider = FutureProvider<List<RecurringTransaction>>((ref) async {
  final res = await api.get('/recurring-transactions');
  return (res.data as List).map((e) => RecurringTransaction.fromJson(e)).toList();
});

// ── Dashboard ─────────────────────────────────────────────────────────────────

final dashboardProvider = FutureProvider<DashboardSummary>((ref) async {
  final res = await api.get('/reports/dashboard');
  return DashboardSummary.fromJson(res.data);
});

final creditCardBillsProvider = FutureProvider<List<CreditCardBill>>((ref) async {
  final res = await api.get('/reports/credit-card-bills');
  return (res.data as List).map((e) => CreditCardBill.fromJson(e)).toList();
});

// ── Reports ───────────────────────────────────────────────────────────────────

final monthlyReportProvider = FutureProvider.family<List<MonthlySummary>, int?>((ref, year) async {
  final res = await api.get('/reports/monthly', params: year != null ? {'year': year} : null);
  return (res.data as List).map((e) => MonthlySummary.fromJson(e)).toList();
});

final monthlyDetailProvider =
    FutureProvider.family<MonthlyDetail, (int, int)>((ref, params) async {
  final res = await api.get('/reports/monthly-detail',
      params: {'year': params.$1, 'month': params.$2});
  return MonthlyDetail.fromJson(res.data);
});

final invoiceProvider = FutureProvider.family<InvoiceData, int>((ref, accountId) async {
  final res = await api.get('/accounts/$accountId/invoice');
  return InvoiceData.fromJson(res.data);
});
