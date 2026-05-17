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
  created_at: string;
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

export interface DashboardSummary {
  total_balance: number;
  monthly_income: number;
  monthly_expense: number;
  monthly_balance: number;
  recent_transactions: Transaction[];
  monthly_chart: MonthlySummary[];
  expense_by_category: CategorySummary[];
}
