import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import api from "@/services/api";
import type {
  Account,
  AuthResponse,
  Category,
  DashboardSummary,
  InvoiceData,
  MonthlySummary,
  PaginatedTransactions,
  RecurringTransaction,
  Transaction,
} from "@/types";

// Auth
export const useLogin = () =>
  useMutation({
    mutationFn: (data: { email: string; password: string }) =>
      api.post<AuthResponse>("/auth/login", data).then((r) => r.data),
  });

export const useRegister = () =>
  useMutation({
    mutationFn: (data: { name: string; email: string; password: string }) =>
      api.post<AuthResponse>("/auth/register", data).then((r) => r.data),
  });

export const useUpdateProfile = () =>
  useMutation({
    mutationFn: (data: { name: string; email: string }) =>
      api.put<import("@/types").User>("/auth/me", data).then((r) => r.data),
  });

export const useChangePassword = () =>
  useMutation({
    mutationFn: (data: { current_password: string; new_password: string }) =>
      api.put("/auth/me/password", data),
  });

// Accounts
export const useAccounts = () =>
  useQuery({ queryKey: ["accounts"], queryFn: () => api.get<Account[]>("/accounts").then((r) => r.data) });

export const useCreateAccount = () => {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (data: Omit<Account, "id" | "created_at">) =>
      api.post<Account>("/accounts", data).then((r) => r.data),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["accounts"] }),
  });
};

export const useUpdateAccount = () => {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ id, ...data }: Partial<Account> & { id: number }) =>
      api.put<Account>(`/accounts/${id}`, data).then((r) => r.data),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["accounts"] }),
  });
};

export const useDeleteAccount = () => {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: number) => api.delete(`/accounts/${id}`),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["accounts"] }),
  });
};

// Categories
export const useCategories = (type?: "income" | "expense") =>
  useQuery({
    queryKey: ["categories", type],
    queryFn: () =>
      api.get<Category[]>("/categories", { params: type ? { type } : {} }).then((r) => r.data),
  });

export const useCreateCategory = () => {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (data: Omit<Category, "id" | "created_at">) =>
      api.post<Category>("/categories", data).then((r) => r.data),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["categories"] }),
  });
};

export const useUpdateCategory = () => {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ id, ...data }: Partial<Category> & { id: number }) =>
      api.put<Category>(`/categories/${id}`, data).then((r) => r.data),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["categories"] }),
  });
};

export const useDeleteCategory = () => {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: number) => api.delete(`/categories/${id}`),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["categories"] }),
  });
};

// Transactions
export const useTransactions = (params: {
  account_id?: number;
  category_id?: number;
  type?: string;
  date_from?: string;
  date_to?: string;
  page?: number;
  page_size?: number;
}) =>
  useQuery({
    queryKey: ["transactions", params],
    queryFn: () =>
      api.get<PaginatedTransactions>("/transactions", { params }).then((r) => r.data),
  });

export const useCreateTransaction = () => {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (data: Omit<Transaction, "id" | "created_at" | "category"> & { installments?: number }) =>
      api.post<Transaction>("/transactions", data).then((r) => r.data),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["transactions"] });
      qc.invalidateQueries({ queryKey: ["accounts"] });
      qc.invalidateQueries({ queryKey: ["dashboard"] });
    },
  });
};

export const useUpdateTransaction = () => {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ id, ...data }: Partial<Transaction> & { id: number }) =>
      api.put<Transaction>(`/transactions/${id}`, data).then((r) => r.data),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["transactions"] });
      qc.invalidateQueries({ queryKey: ["accounts"] });
      qc.invalidateQueries({ queryKey: ["dashboard"] });
    },
  });
};

export const useDeleteTransaction = () => {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: number) => api.delete(`/transactions/${id}`),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["transactions"] });
      qc.invalidateQueries({ queryKey: ["accounts"] });
      qc.invalidateQueries({ queryKey: ["dashboard"] });
    },
  });
};

// Recurring Transactions
export const useRecurringTransactions = () =>
  useQuery({
    queryKey: ["recurring"],
    queryFn: () =>
      api.get<RecurringTransaction[]>("/recurring-transactions").then((r) => r.data),
  });

export const useCreateRecurring = () => {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (data: Omit<RecurringTransaction, "id" | "created_at" | "launched_this_month" | "account_name" | "category_name" | "category_color">) =>
      api.post<RecurringTransaction>("/recurring-transactions", data).then((r) => r.data),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["recurring"] }),
  });
};

export const useUpdateRecurring = () => {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ id, ...data }: Partial<RecurringTransaction> & { id: number }) =>
      api.put<RecurringTransaction>(`/recurring-transactions/${id}`, data).then((r) => r.data),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["recurring"] }),
  });
};

export const useDeleteRecurring = () => {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: number) => api.delete(`/recurring-transactions/${id}`),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["recurring"] }),
  });
};

export const useLaunchRecurring = () => {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ id, amount }: { id: number; amount?: number }) =>
      api
        .post<RecurringTransaction>(`/recurring-transactions/${id}/launch`, { amount })
        .then((r) => r.data),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["recurring"] });
      qc.invalidateQueries({ queryKey: ["accounts"] });
      qc.invalidateQueries({ queryKey: ["transactions"] });
      qc.invalidateQueries({ queryKey: ["dashboard"] });
    },
  });
};

export const useAccountInvoice = (accountId: number | null) =>
  useQuery({
    queryKey: ["invoice", accountId],
    queryFn: () =>
      api.get<InvoiceData>(`/accounts/${accountId}/invoice`).then((r) => r.data),
    enabled: accountId !== null,
  });

export const usePayInvoice = () => {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({
      accountId,
      source_account_id,
      amount,
    }: {
      accountId: number;
      source_account_id: number;
      amount: number;
    }) =>
      api
        .post(`/accounts/${accountId}/pay-invoice`, { source_account_id, amount })
        .then((r) => r.data),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["accounts"] });
      qc.invalidateQueries({ queryKey: ["invoice"] });
      qc.invalidateQueries({ queryKey: ["transactions"] });
      qc.invalidateQueries({ queryKey: ["dashboard"] });
    },
  });
};

// Reports
export const useDashboard = () =>
  useQuery({
    queryKey: ["dashboard"],
    queryFn: () => api.get<DashboardSummary>("/reports/dashboard").then((r) => r.data),
  });

export const useMonthlyReport = (year?: number) =>
  useQuery({
    queryKey: ["monthly-report", year],
    queryFn: () =>
      api.get<MonthlySummary[]>("/reports/monthly", { params: year ? { year } : {} }).then((r) => r.data),
  });

// AI
export const useAutoCategorize = () => {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: () =>
      api.post<{ categorized: number; total_uncategorized: number; message: string }>(
        "/ai/auto-categorize"
      ).then((r) => r.data),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["transactions"] });
      qc.invalidateQueries({ queryKey: ["dashboard"] });
    },
  });
};
