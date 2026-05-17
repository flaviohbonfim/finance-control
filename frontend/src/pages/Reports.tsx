import { useState } from "react";
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  LineChart,
  Line,
  Legend,
} from "recharts";
import { useMonthlyReport } from "@/hooks/useApi";
import Card from "@/components/ui/Card";
import Select from "@/components/ui/Select";

const fmt = (v: number) =>
  new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" }).format(v);

const MONTH_NAMES = ["Jan","Fev","Mar","Abr","Mai","Jun","Jul","Ago","Set","Out","Nov","Dez"];

export default function Reports() {
  const currentYear = new Date().getFullYear();
  const [year, setYear] = useState(currentYear);
  const { data, isLoading } = useMonthlyReport(year);

  const years = Array.from({ length: 5 }, (_, i) => currentYear - i);

  const chartData = (data || []).map((m) => ({
    name: MONTH_NAMES[parseInt(m.month.split("-")[1]) - 1],
    Receitas: Number(m.income),
    Despesas: Number(m.expense),
    Saldo: Number(m.balance),
  }));

  const annualIncome = (data || []).reduce((s, m) => s + Number(m.income), 0);
  const annualExpense = (data || []).reduce((s, m) => s + Number(m.expense), 0);
  const annualBalance = annualIncome - annualExpense;

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-gray-900">Relatórios</h1>
        <div className="w-32">
          <Select value={year} onChange={(e) => setYear(Number(e.target.value))}>
            {years.map((y) => <option key={y} value={y}>{y}</option>)}
          </Select>
        </div>
      </div>

      {/* Annual summary */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <Card>
          <p className="text-sm text-gray-500">Receita Anual</p>
          <p className="text-2xl font-bold text-green-600 mt-1">{fmt(annualIncome)}</p>
        </Card>
        <Card>
          <p className="text-sm text-gray-500">Despesa Anual</p>
          <p className="text-2xl font-bold text-red-500 mt-1">{fmt(annualExpense)}</p>
        </Card>
        <Card>
          <p className="text-sm text-gray-500">Saldo Anual</p>
          <p className={`text-2xl font-bold mt-1 ${annualBalance >= 0 ? "text-green-600" : "text-red-500"}`}>
            {fmt(annualBalance)}
          </p>
        </Card>
      </div>

      {isLoading ? (
        <div className="flex items-center justify-center h-40">
          <div className="animate-spin w-6 h-6 border-4 border-primary-200 border-t-primary-600 rounded-full" />
        </div>
      ) : (
        <>
          <Card>
            <h2 className="text-sm font-semibold text-gray-900 mb-4">Receitas x Despesas {year}</h2>
            <ResponsiveContainer width="100%" height={280}>
              <BarChart data={chartData} barGap={4}>
                <CartesianGrid strokeDasharray="3 3" stroke="#f3f4f6" />
                <XAxis dataKey="name" tick={{ fontSize: 12 }} />
                <YAxis tick={{ fontSize: 11 }} tickFormatter={(v) => `R$${(v / 1000).toFixed(0)}k`} />
                <Tooltip formatter={(v: number) => fmt(v)} />
                <Legend />
                <Bar dataKey="Receitas" fill="#22c55e" radius={[4, 4, 0, 0]} barSize={14} />
                <Bar dataKey="Despesas" fill="#ef4444" radius={[4, 4, 0, 0]} barSize={14} />
              </BarChart>
            </ResponsiveContainer>
          </Card>

          <Card>
            <h2 className="text-sm font-semibold text-gray-900 mb-4">Evolução do Saldo {year}</h2>
            <ResponsiveContainer width="100%" height={250}>
              <LineChart data={chartData}>
                <CartesianGrid strokeDasharray="3 3" stroke="#f3f4f6" />
                <XAxis dataKey="name" tick={{ fontSize: 12 }} />
                <YAxis tick={{ fontSize: 11 }} tickFormatter={(v) => `R$${(v / 1000).toFixed(0)}k`} />
                <Tooltip formatter={(v: number) => fmt(v)} />
                <Line
                  type="monotone"
                  dataKey="Saldo"
                  stroke="#6366f1"
                  strokeWidth={2}
                  dot={{ fill: "#6366f1", r: 4 }}
                />
              </LineChart>
            </ResponsiveContainer>
          </Card>

          {/* Monthly table */}
          <Card padding={false}>
            <div className="px-5 py-4 border-b border-gray-100">
              <h2 className="text-sm font-semibold text-gray-900">Resumo Mensal {year}</h2>
            </div>
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="text-xs text-gray-500 uppercase tracking-wide border-b border-gray-100">
                    <th className="px-5 py-3 text-left font-medium">Mês</th>
                    <th className="px-5 py-3 text-right font-medium text-green-600">Receitas</th>
                    <th className="px-5 py-3 text-right font-medium text-red-500">Despesas</th>
                    <th className="px-5 py-3 text-right font-medium">Saldo</th>
                  </tr>
                </thead>
                <tbody>
                  {(data || []).map((m, i) => {
                    const balance = Number(m.income) - Number(m.expense);
                    return (
                      <tr key={m.month} className="border-b border-gray-50 last:border-0 hover:bg-gray-50/50">
                        <td className="px-5 py-3 font-medium text-gray-900">{MONTH_NAMES[i]}</td>
                        <td className="px-5 py-3 text-right text-green-600">{fmt(Number(m.income))}</td>
                        <td className="px-5 py-3 text-right text-red-500">{fmt(Number(m.expense))}</td>
                        <td className={`px-5 py-3 text-right font-semibold ${balance >= 0 ? "text-green-600" : "text-red-500"}`}>
                          {fmt(balance)}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          </Card>
        </>
      )}
    </div>
  );
}
