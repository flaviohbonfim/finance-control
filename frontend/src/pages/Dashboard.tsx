import { format } from "date-fns";
import { ptBR } from "date-fns/locale";
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  PieChart,
  Pie,
  Cell,
} from "recharts";
import {
  TrendingUp,
  TrendingDown,
  Wallet,
  ArrowUpRight,
  ArrowDownRight,
  RefreshCcw,
  CheckCircle,
  Play,
  CreditCard,
  type LucideIcon,
} from "lucide-react";
import { useDashboard, useLaunchRecurring, useCreditCardBills } from "@/hooks/useApi";
import Card from "@/components/ui/Card";
import Button from "@/components/ui/Button";
import Modal from "@/components/ui/Modal";
import Input from "@/components/ui/Input";
import { useForm } from "react-hook-form";
import { useState } from "react";
import type { Transaction, RecurringTransaction, CreditCardBill } from "@/types";

const fmt = (v: number) =>
  new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" }).format(v);

type DashView = "month" | "general";

function StatCard({
  label,
  value,
  icon: Icon,
  color,
  trend,
}: {
  label: string;
  value: number;
  icon: LucideIcon;
  color: string;
  trend?: "up" | "down";
}) {
  const bgStyle = {
    backgroundColor:
      color === "text-primary-600"
        ? "#eef2ff"
        : color === "text-green-600"
        ? "#dcfce7"
        : "#fee2e2",
  };
  return (
    <Card className="overflow-hidden">
      <div className="flex items-start justify-between gap-2">
        <div className="min-w-0 flex-1">
          <p className="text-xs sm:text-sm text-gray-500 truncate">{label}</p>
          <p className={`text-base sm:text-2xl font-bold mt-1 leading-tight ${color}`}>
            {fmt(value)}
          </p>
        </div>
        <div className="p-2 rounded-lg flex-shrink-0" style={bgStyle}>
          <Icon size={18} className={color} />
        </div>
      </div>
      {trend && (
        <div className="mt-2 flex items-center gap-1 text-xs text-gray-500">
          {trend === "up" ? (
            <ArrowUpRight size={13} className="text-green-500" />
          ) : (
            <ArrowDownRight size={13} className="text-red-500" />
          )}
          <span>Este mês</span>
        </div>
      )}
    </Card>
  );
}

function TransactionItem({ tx }: { tx: Transaction }) {
  const isIncome = tx.type === "income";
  return (
    <div className="flex items-center gap-3 py-3 border-b border-gray-100 dark:border-gray-700 last:border-0">
      <div
        className="w-9 h-9 rounded-full flex items-center justify-center flex-shrink-0"
        style={{
          backgroundColor: `${tx.category?.color || "#6366f1"}20`,
          color: tx.category?.color || "#6366f1",
        }}
      >
        {isIncome ? <TrendingUp size={16} /> : <TrendingDown size={16} />}
      </div>
      <div className="flex-1 min-w-0">
        <p className="text-sm font-medium text-gray-900 truncate">{tx.description}</p>
        <p className="text-xs text-gray-500">
          {tx.category?.name || "Sem categoria"} •{" "}
          {format(new Date(tx.transaction_date + "T12:00:00"), "dd/MM", { locale: ptBR })}
        </p>
      </div>
      <span className={`text-sm font-semibold ${isIncome ? "text-green-600" : "text-red-500"}`}>
        {isIncome ? "+" : "-"}
        {fmt(Number(tx.amount))}
      </span>
    </div>
  );
}

const monthLabel = (m: string) => {
  const [, month] = m.split("-");
  return ["Jan", "Fev", "Mar", "Abr", "Mai", "Jun", "Jul", "Ago", "Set", "Out", "Nov", "Dez"][
    parseInt(month) - 1
  ];
};

function RecurringWidget({ items }: { items: RecurringTransaction[] }) {
  const launch = useLaunchRecurring();
  const [launchModalOpen, setLaunchModalOpen] = useState(false);
  const [launching, setLaunching] = useState<RecurringTransaction | null>(null);
  const [launchError, setLaunchError] = useState("");
  const [launchSuccess, setLaunchSuccess] = useState(false);

  const { register, handleSubmit, reset, formState: { errors } } = useForm<{ amount: number }>();

  const openLaunch = (rt: RecurringTransaction) => {
    setLaunching(rt);
    reset({ amount: rt.amount ? Number(rt.amount) : undefined });
    setLaunchError("");
    setLaunchSuccess(false);
    setLaunchModalOpen(true);
  };

  const onLaunch = async (data: { amount: number }) => {
    if (!launching) return;
    try {
      await launch.mutateAsync({
        id: launching.id,
        amount: launching.is_fixed
          ? launching.amount
            ? Number(launching.amount)
            : undefined
          : Number(data.amount),
      });
      setLaunchSuccess(true);
      setTimeout(() => {
        setLaunchModalOpen(false);
        setLaunchSuccess(false);
      }, 1500);
    } catch (e: unknown) {
      const msg = (e as { response?: { data?: { detail?: string } } })?.response?.data?.detail;
      setLaunchError(msg || "Erro ao lançar");
    }
  };

  if (items.length === 0) return null;

  return (
    <>
      <Card>
        <h2 className="text-sm font-semibold text-gray-900 mb-4">Recorrentes do Mês</h2>
        <div className="space-y-2">
          {items.map((rt) => (
            <div
              key={rt.id}
              className="flex items-center gap-3 py-2 border-b border-gray-100 dark:border-gray-700 last:border-0"
            >
              <div
                className="w-8 h-8 rounded-full flex items-center justify-center flex-shrink-0"
                style={{
                  backgroundColor: rt.category_color ? `${rt.category_color}20` : "#6366f120",
                  color: rt.category_color || "#6366f1",
                }}
              >
                <RefreshCcw size={14} />
              </div>
              <div className="flex-1 min-w-0">
                <p className="text-sm font-medium text-gray-900 truncate">{rt.description}</p>
                <p className="text-xs text-gray-500">
                  {rt.account_name} · dia {rt.due_day}
                </p>
              </div>
              <div className="flex items-center gap-2 flex-shrink-0">
                {rt.amount !== null && (
                  <span
                    className={`text-sm font-semibold ${
                      rt.type === "income" ? "text-green-600" : "text-red-500"
                    }`}
                  >
                    {rt.type === "income" ? "+" : "-"}
                    {fmt(Number(rt.amount))}
                  </span>
                )}
                {rt.launched_this_month ? (
                  <span className="inline-flex items-center gap-1 text-xs font-medium text-green-700 bg-green-50 px-2 py-0.5 rounded-full">
                    <CheckCircle size={11} /> Lançado
                  </span>
                ) : (
                  <button
                    onClick={() => openLaunch(rt)}
                    className="p-1.5 rounded-lg text-gray-400 hover:text-primary-600 hover:bg-primary-50 transition-colors"
                    title="Lançar"
                  >
                    <Play size={13} />
                  </button>
                )}
              </div>
            </div>
          ))}
        </div>
      </Card>

      <Modal
        open={launchModalOpen}
        onClose={() => setLaunchModalOpen(false)}
        title="Lançar Recorrente"
      >
        {launchSuccess ? (
          <div className="flex flex-col items-center gap-3 py-6">
            <CheckCircle size={40} className="text-green-500" />
            <p className="text-sm font-medium text-gray-700">Lançado com sucesso!</p>
          </div>
        ) : (
          <form onSubmit={handleSubmit(onLaunch)} className="space-y-4">
            {launching && (
              <div className="bg-gray-50 rounded-lg px-4 py-3 text-sm text-gray-700">
                <p className="font-medium">{launching.description}</p>
                <p className="text-gray-500 mt-0.5">
                  {launching.type === "income" ? "Receita" : "Despesa"} · {launching.account_name}
                </p>
              </div>
            )}
            {launching && !launching.is_fixed && (
              <Input
                label="Valor (R$)"
                type="number"
                step="0.01"
                min="0.01"
                placeholder="0,00"
                error={errors.amount?.message}
                {...register("amount", { required: "Valor obrigatório", min: 0.01 })}
              />
            )}
            {launching && launching.is_fixed && launching.amount && (
              <p className="text-sm text-gray-600">
                Valor: <span className="font-semibold">{fmt(Number(launching.amount))}</span>
              </p>
            )}
            {launchError && <p className="text-sm text-red-500">{launchError}</p>}
            <div className="flex gap-3 pt-2">
              <Button
                type="button"
                variant="secondary"
                className="flex-1"
                onClick={() => setLaunchModalOpen(false)}
              >
                Cancelar
              </Button>
              <Button type="submit" className="flex-1" loading={launch.isPending}>
                Confirmar
              </Button>
            </div>
          </form>
        )}
      </Modal>
    </>
  );
}

function CreditCardBillsSection({ bills }: { bills: CreditCardBill[] }) {
  if (bills.length === 0) {
    return (
      <Card>
        <h2 className="text-sm font-semibold text-gray-900 mb-2">Faturas dos Cartões</h2>
        <p className="text-sm text-gray-400 text-center py-6">Nenhum cartão de crédito cadastrado</p>
      </Card>
    );
  }

  const totalNext = bills.reduce((s, b) => s + Number(b.next_bill.total), 0);
  const totalCurrent = bills.reduce((s, b) => s + Number(b.current_bill.total), 0);

  return (
    <div className="space-y-3">
      <div className="flex items-center justify-between">
        <h2 className="text-sm font-semibold text-gray-900">Faturas dos Cartões</h2>
        <div className="text-right">
          <p className="text-xs text-gray-400">Próximo ciclo (total)</p>
          <p className="text-sm font-bold text-red-500">{fmt(totalNext)}</p>
        </div>
      </div>

      {/* Total summary bar */}
      <Card className="bg-gray-50 border-0">
        <div className="flex justify-between text-sm">
          <div>
            <p className="text-xs text-gray-500 mb-0.5">Ciclo atual (total)</p>
            <p className="font-semibold text-gray-700">{fmt(totalCurrent)}</p>
          </div>
          <div className="text-right">
            <p className="text-xs text-gray-500 mb-0.5">Próximo ciclo (total)</p>
            <p className="font-semibold text-red-500">{fmt(totalNext)}</p>
          </div>
        </div>
      </Card>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
        {bills.map((bill) => (
          <Card key={bill.id} className="space-y-3">
            <div className="flex items-center gap-2">
              <div className="w-8 h-8 rounded-full bg-primary-50 flex items-center justify-center flex-shrink-0">
                <CreditCard size={14} className="text-primary-600" />
              </div>
              <p className="text-sm font-semibold text-gray-900 truncate">{bill.name}</p>
            </div>

            <div className="space-y-2">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Ciclo atual · {bill.current_bill.period}</p>
                <p className="text-base font-bold text-gray-700">{fmt(Number(bill.current_bill.total))}</p>
              </div>
              <div className="pt-2 border-t border-gray-100">
                <p className="text-xs text-gray-400 mb-0.5">Próximo ciclo · {bill.next_bill.period}</p>
                <p className="text-base font-bold text-red-500">{fmt(Number(bill.next_bill.total))}</p>
              </div>
            </div>

            {bill.due_day && (
              <p className="text-xs text-gray-400">Vencimento dia {bill.due_day}</p>
            )}
          </Card>
        ))}
      </div>
    </div>
  );
}

export default function Dashboard() {
  const [view, setView] = useState<DashView>("month");
  const { data, isLoading } = useDashboard();
  const { data: bills = [], isLoading: billsLoading } = useCreditCardBills();

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin w-8 h-8 border-4 border-primary-200 border-t-primary-600 rounded-full" />
      </div>
    );
  }

  if (!data) return null;

  const chartData = data.monthly_chart.map((m) => ({
    name: monthLabel(m.month),
    Receitas: Number(m.income),
    Despesas: Number(m.expense),
  }));

  return (
    <div className="space-y-6">
      {/* Header + toggle */}
      <div className="flex items-start justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Dashboard</h1>
          <p className="text-sm text-gray-500 mt-0.5">
            {format(new Date(), "MMMM 'de' yyyy", { locale: ptBR })}
          </p>
        </div>
        <div className="flex rounded-xl border border-gray-200 bg-gray-50 p-1 gap-1 flex-shrink-0">
          <button
            onClick={() => setView("month")}
            className={`px-3 py-1.5 text-sm font-medium rounded-lg transition-colors ${
              view === "month"
                ? "bg-white text-primary-700 shadow-sm"
                : "text-gray-500 hover:text-gray-700"
            }`}
          >
            Mês Atual
          </button>
          <button
            onClick={() => setView("general")}
            className={`px-3 py-1.5 text-sm font-medium rounded-lg transition-colors ${
              view === "general"
                ? "bg-white text-primary-700 shadow-sm"
                : "text-gray-500 hover:text-gray-700"
            }`}
          >
            Geral
          </button>
        </div>
      </div>

      {view === "month" ? (
        /* ── Mês Atual ─────────────────────────────────────────── */
        <>
          {/* Stats: income / expense / balance */}
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <StatCard
              label="Receitas do Mês"
              value={Number(data.monthly_income)}
              icon={TrendingUp}
              color="text-green-600"
              trend="up"
            />
            <StatCard
              label="Despesas do Mês"
              value={Number(data.monthly_expense)}
              icon={TrendingDown}
              color="text-red-500"
              trend="down"
            />
            <StatCard
              label="Saldo do Mês"
              value={Number(data.monthly_balance)}
              icon={Number(data.monthly_balance) >= 0 ? TrendingUp : TrendingDown}
              color={Number(data.monthly_balance) >= 0 ? "text-green-600" : "text-red-500"}
            />
          </div>

          {/* Credit card bills */}
          {billsLoading ? (
            <div className="flex items-center justify-center h-24">
              <div className="animate-spin w-6 h-6 border-4 border-primary-200 border-t-primary-600 rounded-full" />
            </div>
          ) : (
            <CreditCardBillsSection bills={bills} />
          )}

          {/* Expense by category */}
          {data.expense_by_category.length > 0 && (
            <Card>
              <h2 className="text-sm font-semibold text-gray-900 mb-4">Despesas por Categoria</h2>
              <div className="flex flex-col sm:flex-row gap-4 items-center">
                <ResponsiveContainer width="100%" height={160} className="flex-shrink-0 sm:max-w-[200px]">
                  <PieChart>
                    <Pie
                      data={data.expense_by_category.map((e) => ({
                        ...e,
                        total: Number(e.total),
                      }))}
                      dataKey="total"
                      nameKey="category_name"
                      cx="50%"
                      cy="50%"
                      innerRadius={45}
                      outerRadius={70}
                    >
                      {data.expense_by_category.map((entry, i) => (
                        <Cell key={i} fill={entry.category_color} />
                      ))}
                    </Pie>
                    <Tooltip formatter={(v: number) => fmt(v)} />
                  </PieChart>
                </ResponsiveContainer>
                <div className="flex-1 w-full space-y-1.5">
                  {data.expense_by_category.map((e, i) => (
                    <div key={i} className="flex items-center justify-between gap-2 text-xs">
                      <div className="flex items-center gap-2 min-w-0">
                        <span
                          className="w-2.5 h-2.5 rounded-full flex-shrink-0"
                          style={{ backgroundColor: e.category_color }}
                        />
                        <span className="text-gray-600 truncate">{e.category_name}</span>
                      </div>
                      <span className="text-gray-900 font-medium flex-shrink-0">
                        {e.percentage.toFixed(0)}% · {fmt(Number(e.total))}
                      </span>
                    </div>
                  ))}
                </div>
              </div>
            </Card>
          )}

          {/* Recurring this month */}
          <RecurringWidget items={data.recurring_this_month ?? []} />
        </>
      ) : (
        /* ── Geral ─────────────────────────────────────────────── */
        <>
          {/* 4 stat cards */}
          <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
            <StatCard
              label="Saldo Total"
              value={Number(data.total_balance)}
              icon={Wallet}
              color="text-primary-600"
            />
            <StatCard
              label="Receitas do Mês"
              value={Number(data.monthly_income)}
              icon={TrendingUp}
              color="text-green-600"
              trend="up"
            />
            <StatCard
              label="Despesas do Mês"
              value={Number(data.monthly_expense)}
              icon={TrendingDown}
              color="text-red-500"
              trend="down"
            />
            <StatCard
              label="Saldo do Mês"
              value={Number(data.monthly_balance)}
              icon={Number(data.monthly_balance) >= 0 ? TrendingUp : TrendingDown}
              color={Number(data.monthly_balance) >= 0 ? "text-green-600" : "text-red-500"}
            />
          </div>

          {/* Charts row */}
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
            <Card className="lg:col-span-2">
              <h2 className="text-sm font-semibold text-gray-900 mb-4">Últimos 6 Meses</h2>
              <ResponsiveContainer width="100%" height={200}>
                <BarChart data={chartData} barSize={10} barGap={4}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#f3f4f6" />
                  <XAxis dataKey="name" tick={{ fontSize: 12 }} />
                  <YAxis
                    tick={{ fontSize: 12 }}
                    tickFormatter={(v) => `R$${(v / 1000).toFixed(0)}k`}
                  />
                  <Tooltip formatter={(v: number) => fmt(v)} />
                  <Bar dataKey="Receitas" fill="#22c55e" radius={[4, 4, 0, 0]} />
                  <Bar dataKey="Despesas" fill="#ef4444" radius={[4, 4, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            </Card>

            <Card>
              <h2 className="text-sm font-semibold text-gray-900 mb-4">Despesas por Categoria</h2>
              {data.expense_by_category.length === 0 ? (
                <div className="flex items-center justify-center h-[160px] text-sm text-gray-500">
                  Nenhuma despesa este mês
                </div>
              ) : (
                <>
                  <ResponsiveContainer width="100%" height={150}>
                    <PieChart>
                      <Pie
                        data={data.expense_by_category.map((e) => ({
                          ...e,
                          total: Number(e.total),
                        }))}
                        dataKey="total"
                        nameKey="category_name"
                        cx="50%"
                        cy="50%"
                        innerRadius={40}
                        outerRadius={65}
                      >
                        {data.expense_by_category.map((entry, i) => (
                          <Cell key={i} fill={entry.category_color} />
                        ))}
                      </Pie>
                      <Tooltip formatter={(v: number) => fmt(v)} />
                    </PieChart>
                  </ResponsiveContainer>
                  <div className="mt-2 space-y-1.5">
                    {data.expense_by_category.map((e, i) => (
                      <div key={i} className="flex items-center justify-between gap-2 text-xs">
                        <div className="flex items-center gap-2 min-w-0">
                          <span
                            className="w-2.5 h-2.5 rounded-full flex-shrink-0"
                            style={{ backgroundColor: e.category_color }}
                          />
                          <span className="text-gray-600 truncate">{e.category_name}</span>
                        </div>
                        <span className="text-gray-900 font-medium flex-shrink-0">
                          {e.percentage.toFixed(0)}% · {fmt(Number(e.total))}
                        </span>
                      </div>
                    ))}
                  </div>
                </>
              )}
            </Card>
          </div>

          {/* Recent transactions */}
          <Card>
            <h2 className="text-sm font-semibold text-gray-900 mb-4">Transações Recentes</h2>
            {data.recent_transactions.length === 0 ? (
              <p className="text-sm text-gray-400 text-center py-8">Nenhuma transação ainda</p>
            ) : (
              <div>
                {data.recent_transactions.map((tx) => (
                  <TransactionItem key={tx.id} tx={tx} />
                ))}
              </div>
            )}
          </Card>

          {/* Recurring this month */}
          <RecurringWidget items={data.recurring_this_month ?? []} />
        </>
      )}
    </div>
  );
}
