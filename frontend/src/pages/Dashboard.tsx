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
  Legend,
} from "recharts";
import { TrendingUp, TrendingDown, Wallet, ArrowUpRight, ArrowDownRight, type LucideIcon } from "lucide-react";
import { useDashboard } from "@/hooks/useApi";
import Card from "@/components/ui/Card";
import type { Transaction } from "@/types";

const fmt = (v: number) =>
  new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" }).format(v);

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
    backgroundColor: color === "text-primary-600"
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
    <div className="flex items-center gap-3 py-3 border-b border-gray-50 last:border-0">
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
  return ["Jan","Fev","Mar","Abr","Mai","Jun","Jul","Ago","Set","Out","Nov","Dez"][parseInt(month) - 1];
};

export default function Dashboard() {
  const { data, isLoading } = useDashboard();

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
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Dashboard</h1>
        <p className="text-sm text-gray-500 mt-0.5">
          {format(new Date(), "MMMM 'de' yyyy", { locale: ptBR })}
        </p>
      </div>

      {/* Stats */}
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
          icon={data.monthly_balance >= 0 ? TrendingUp : TrendingDown}
          color={Number(data.monthly_balance) >= 0 ? "text-green-600" : "text-red-500"}
        />
      </div>

      {/* Charts row */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        {/* Bar chart */}
        <Card className="lg:col-span-2">
          <h2 className="text-sm font-semibold text-gray-900 mb-4">Últimos 6 Meses</h2>
          <ResponsiveContainer width="100%" height={200}>
            <BarChart data={chartData} barSize={10} barGap={4}>
              <CartesianGrid strokeDasharray="3 3" stroke="#f3f4f6" />
              <XAxis dataKey="name" tick={{ fontSize: 12 }} />
              <YAxis tick={{ fontSize: 12 }} tickFormatter={(v) => `R$${(v / 1000).toFixed(0)}k`} />
              <Tooltip formatter={(v: number) => fmt(v)} />
              <Legend />
              <Bar dataKey="Receitas" fill="#22c55e" radius={[4, 4, 0, 0]} />
              <Bar dataKey="Despesas" fill="#ef4444" radius={[4, 4, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </Card>

        {/* Pie chart */}
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
    </div>
  );
}
