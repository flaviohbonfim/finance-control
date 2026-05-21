// FastAPI serializa Decimal como String — helpers que aceitam ambos os formatos.
double _d(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

double? _dNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

class User {
  final int id;
  final String name;
  final String email;
  final bool isActive;

  User({required this.id, required this.name, required this.email, required this.isActive});

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: j['id'],
        name: j['name'],
        email: j['email'],
        isActive: j['is_active'] ?? true,
      );
}

class Account {
  final int id;
  final String name;
  final String type;
  final double balance;
  final String color;
  final int? closingDay;
  final int? dueDay;
  final double? creditLimit;

  Account({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    required this.color,
    this.closingDay,
    this.dueDay,
    this.creditLimit,
  });

  bool get isCreditCard => type == 'credit_card';

  factory Account.fromJson(Map<String, dynamic> j) => Account(
        id: j['id'],
        name: j['name'],
        type: j['type'],
        balance: _d(j['balance']),
        color: j['color'] ?? '#6366f1',
        closingDay: j['closing_day'],
        dueDay: j['due_day'],
        creditLimit: _dNull(j['credit_limit']),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type,
        'balance': balance,
        'color': color,
        'closing_day': closingDay,
        'due_day': dueDay,
        'credit_limit': creditLimit,
      };
}

class Category {
  final int id;
  final String name;
  final String type;
  final String icon;
  final String color;

  Category({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
  });

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: j['id'],
        name: j['name'],
        type: j['type'],
        icon: j['icon'] ?? '',
        color: j['color'] ?? '#6366f1',
      );

  Map<String, dynamic> toJson() => {'name': name, 'type': type, 'icon': icon, 'color': color};
}

class Transaction {
  final int id;
  final int accountId;
  final int? categoryId;
  final String type;
  final double amount;
  final String description;
  final String? notes;
  final String transactionDate;
  final Category? category;

  Transaction({
    required this.id,
    required this.accountId,
    this.categoryId,
    required this.type,
    required this.amount,
    required this.description,
    this.notes,
    required this.transactionDate,
    this.category,
  });

  bool get isIncome => type == 'income';

  factory Transaction.fromJson(Map<String, dynamic> j) => Transaction(
        id: j['id'],
        accountId: j['account_id'],
        categoryId: j['category_id'],
        type: j['type'],
        amount: _d(j['amount']),
        description: j['description'],
        notes: j['notes'],
        transactionDate: j['transaction_date'],
        category: j['category'] != null ? Category.fromJson(j['category']) : null,
      );
}

class PaginatedTransactions {
  final List<Transaction> items;
  final int total;
  final int page;
  final int pageSize;
  final int pages;

  PaginatedTransactions({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.pages,
  });

  factory PaginatedTransactions.fromJson(Map<String, dynamic> j) => PaginatedTransactions(
        items: (j['items'] as List).map((e) => Transaction.fromJson(e)).toList(),
        total: j['total'],
        page: j['page'],
        pageSize: j['page_size'],
        pages: j['pages'],
      );
}

class CategorySummary {
  final int? categoryId;
  final String categoryName;
  final String categoryColor;
  final double total;
  final double percentage;

  CategorySummary({
    this.categoryId,
    required this.categoryName,
    required this.categoryColor,
    required this.total,
    required this.percentage,
  });

  factory CategorySummary.fromJson(Map<String, dynamic> j) => CategorySummary(
        categoryId: j['category_id'],
        categoryName: j['category_name'] ?? 'Sem categoria',
        categoryColor: j['category_color'] ?? '#9ca3af',
        total: _d(j['total']),
        percentage: _d(j['percentage']),
      );
}

class MonthlySummary {
  final String month;
  final double income;
  final double expense;
  final double balance;

  MonthlySummary({
    required this.month,
    required this.income,
    required this.expense,
    required this.balance,
  });

  factory MonthlySummary.fromJson(Map<String, dynamic> j) => MonthlySummary(
        month: j['month'],
        income: _d(j['income']),
        expense: _d(j['expense']),
        balance: _d(j['balance']),
      );
}

class RecurringTransaction {
  final int id;
  final int accountId;
  final int? categoryId;
  final String type;
  final String description;
  final double? amount;
  final bool isFixed;
  final String frequency;
  final int dueDay;
  final int? dueMonth;
  final bool active;
  final bool launchedThisMonth;
  final String? accountName;
  final String? categoryName;
  final String? categoryColor;

  RecurringTransaction({
    required this.id,
    required this.accountId,
    this.categoryId,
    required this.type,
    required this.description,
    this.amount,
    required this.isFixed,
    required this.frequency,
    required this.dueDay,
    this.dueMonth,
    required this.active,
    required this.launchedThisMonth,
    this.accountName,
    this.categoryName,
    this.categoryColor,
  });

  bool get isIncome => type == 'income';

  factory RecurringTransaction.fromJson(Map<String, dynamic> j) => RecurringTransaction(
        id: j['id'],
        accountId: j['account_id'],
        categoryId: j['category_id'],
        type: j['type'],
        description: j['description'],
        amount: _dNull(j['amount']),
        isFixed: j['is_fixed'] ?? true,
        frequency: j['frequency'] ?? 'monthly',
        dueDay: j['due_day'],
        dueMonth: j['due_month'],
        active: j['active'] ?? true,
        launchedThisMonth: j['launched_this_month'] ?? false,
        accountName: j['account_name'],
        categoryName: j['category_name'],
        categoryColor: j['category_color'],
      );
}

class DashboardSummary {
  final double totalBalance;
  final double monthlyIncome;
  final double monthlyExpense;
  final double monthlyBalance;
  final List<Transaction> recentTransactions;
  final List<MonthlySummary> monthlyChart;
  final List<CategorySummary> expenseByCategory;
  final List<RecurringTransaction> recurringThisMonth;

  DashboardSummary({
    required this.totalBalance,
    required this.monthlyIncome,
    required this.monthlyExpense,
    required this.monthlyBalance,
    required this.recentTransactions,
    required this.monthlyChart,
    required this.expenseByCategory,
    required this.recurringThisMonth,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> j) => DashboardSummary(
        totalBalance: _d(j['total_balance']),
        monthlyIncome: _d(j['monthly_income']),
        monthlyExpense: _d(j['monthly_expense']),
        monthlyBalance: _d(j['monthly_balance']),
        recentTransactions:
            (j['recent_transactions'] as List).map((e) => Transaction.fromJson(e)).toList(),
        monthlyChart:
            (j['monthly_chart'] as List).map((e) => MonthlySummary.fromJson(e)).toList(),
        expenseByCategory:
            (j['expense_by_category'] as List).map((e) => CategorySummary.fromJson(e)).toList(),
        recurringThisMonth: (j['recurring_this_month'] as List)
            .map((e) => RecurringTransaction.fromJson(e))
            .toList(),
      );
}

class BillPeriod {
  final String period;
  final double total;

  BillPeriod({required this.period, required this.total});

  factory BillPeriod.fromJson(Map<String, dynamic> j) => BillPeriod(
        period: j['period'],
        total: _d(j['total']),
      );
}

class CreditCardBill {
  final int id;
  final String name;
  final int closingDay;
  final int? dueDay;
  final BillPeriod currentBill;
  final BillPeriod nextBill;

  CreditCardBill({
    required this.id,
    required this.name,
    required this.closingDay,
    this.dueDay,
    required this.currentBill,
    required this.nextBill,
  });

  factory CreditCardBill.fromJson(Map<String, dynamic> j) => CreditCardBill(
        id: j['id'],
        name: j['name'],
        closingDay: j['closing_day'],
        dueDay: j['due_day'],
        currentBill: BillPeriod.fromJson(j['current_bill']),
        nextBill: BillPeriod.fromJson(j['next_bill']),
      );
}

class InvoiceData {
  final double currentTotal;
  final String currentStart;
  final String currentEnd;
  final List<Transaction> currentTransactions;
  final double nextTotal;
  final String nextStart;
  final String nextEnd;
  final List<Transaction> nextTransactions;
  final int dueDay;

  InvoiceData({
    required this.currentTotal,
    required this.currentStart,
    required this.currentEnd,
    required this.currentTransactions,
    required this.nextTotal,
    required this.nextStart,
    required this.nextEnd,
    required this.nextTransactions,
    required this.dueDay,
  });

  factory InvoiceData.fromJson(Map<String, dynamic> j) => InvoiceData(
        currentTotal: _d(j['current_total']),
        currentStart: j['current_start'],
        currentEnd: j['current_end'],
        currentTransactions:
            (j['current_transactions'] as List).map((e) => Transaction.fromJson(e)).toList(),
        nextTotal: _d(j['next_total']),
        nextStart: j['next_start'],
        nextEnd: j['next_end'],
        nextTransactions:
            (j['next_transactions'] as List).map((e) => Transaction.fromJson(e)).toList(),
        dueDay: j['due_day'],
      );
}

class MonthlyDetail {
  final String month;
  final double income;
  final double expense;
  final double balance;
  final List<CategorySummary> expenseByCategory;
  final List<Transaction> topTransactions;

  MonthlyDetail({
    required this.month,
    required this.income,
    required this.expense,
    required this.balance,
    required this.expenseByCategory,
    required this.topTransactions,
  });

  factory MonthlyDetail.fromJson(Map<String, dynamic> j) => MonthlyDetail(
        month: j['month'],
        income: _d(j['income']),
        expense: _d(j['expense']),
        balance: _d(j['balance']),
        expenseByCategory:
            (j['expense_by_category'] as List).map((e) => CategorySummary.fromJson(e)).toList(),
        topTransactions:
            (j['top_transactions'] as List).map((e) => Transaction.fromJson(e)).toList(),
      );
}
