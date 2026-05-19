export interface User {
  id: number;
  name: string;
  email: string;
  is_active: boolean;
  created_at: string;
}

export interface AuthResponse {
  access_token: string;
  token_type: string;
  user: User;
}

export type AccountType = "checking" | "savings" | "cash" | "credit_card" | "investment";

export interface Account {
  id: number;
  name: string;
  type: AccountType;
  balance: number;
  color: string;
  closing_day: number | null;
  due_day: number | null;
  credit_limit: number | null;
  created_at: string;
}

export interface InvoiceData {
  current_total: number;
  current_start: string;
  current_end: string;
  current_transactions: Transaction[];
  next_total: number;
  next_start: string;
  next_end: string;
  next_transactions: Transaction[];
  due_day: number;
}

export type CategoryType = "income" | "expense";

export interface Category {
  id: number;
  name: string;
  type: CategoryType;
  icon: string;
  color: string;
  created_at: string;
}

export type TransactionType = "income" | "expense";

export interface Transaction {
  id: number;
  account_id: number;
  category_id: number | null;
  type: TransactionType;
  amount: number;
  description: string;
  notes: string | null;
  transaction_date: string;
  created_at: string;
  category: Category | null;
}

export interface PaginatedTransactions {
  items: Transaction[];
  total: number;
  page: number;
  page_size: number;
  pages: number;
}

export interface MonthlySummary {
  month: string;
  income: number;
  expense: number;
  balance: number;
}

export interface CategorySummary {
  category_id: number | null;
  category_name: string;
  category_color: string;
  total: number;
  percentage: number;
}

export interface MonthlyDetail {
  month: string;
  income: number;
  expense: number;
  balance: number;
  expense_by_category: CategorySummary[];
  top_transactions: Transaction[];
}

export interface DashboardSummary {
  total_balance: number;
  monthly_income: number;
  monthly_expense: number;
  monthly_balance: number;
  recent_transactions: Transaction[];
  monthly_chart: MonthlySummary[];
  expense_by_category: CategorySummary[];
  recurring_this_month: RecurringTransaction[];
}

export interface BillPeriod {
  period: string;
  total: number;
}

export interface CreditCardBill {
  id: number;
  name: string;
  closing_day: number;
  due_day: number | null;
  current_bill: BillPeriod;
  next_bill: BillPeriod;
}

export type RecurringFrequency = "monthly" | "yearly";

export interface RecurringTransaction {
  id: number;
  account_id: number;
  category_id: number | null;
  type: TransactionType;
  description: string;
  amount: number | null;
  is_fixed: boolean;
  frequency: RecurringFrequency;
  due_day: number;
  due_month: number | null;
  start_date: string;
  end_date: string | null;
  active: boolean;
  last_launched_date: string | null;
  launched_this_month: boolean;
  account_name?: string;
  category_name?: string;
  category_color?: string;
  created_at: string;
}
