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
import { TrendingUp, TrendingDown, Wallet, ArrowUpRight, ArrowDownRight } from "lucide-react";
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
  icon: React.ComponentType<{ size?: number; className?: string }>;
  color: string;
  trend?: "up" | "down";
}) {
  return (
    <Card>
      <div className="flex items-start justify-between">
        <div>
          <p className="text-sm text-gray-500">{label}</p>
          <p className={`text-2xl font-bold mt-1 ${color}`}>{fmt(value)}</p>
        </div>
        <div className={`p-2 rounded-lg ${color.replace("text-", "bg-").replace("600", "100")}`}>
          <Icon size={20} className={color} />
        </div>
      </div>
      {trend && (
        <div className="mt-3 flex items-center gap-1 text-xs text-gray-500">
          {trend === "up" ? (
            <ArrowUpRight size={14} className="text-green-500" />
          ) : (
            <ArrowDownRight size={14} className="text-red-500" />
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
            <div className="flex items-center justify-center h-[200px] text-sm text-gray-400">
              Nenhuma despesa este mês
            </div>
          ) : (
            <ResponsiveContainer width="100%" height={200}>
              <PieChart>
                <Pie
                  data={data.expense_by_category}
                  dataKey="total"
                  nameKey="category_name"
                  cx="50%"
                  cy="50%"
                  innerRadius={50}
                  outerRadius={80}
                >
                  {data.expense_by_category.map((entry, i) => (
                    <Cell key={i} fill={entry.category_color} />
                  ))}
                </Pie>
                <Tooltip formatter={(v: number) => fmt(v)} />
              </PieChart>
            </ResponsiveContainer>
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
