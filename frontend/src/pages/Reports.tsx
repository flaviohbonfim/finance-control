import { useState } from "react";
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip,
  ResponsiveContainer, LineChart, Line, Legend,
  PieChart, Pie, Cell,
} from "recharts";
import { useMonthlyReport, useMonthlyDetail } from "@/hooks/useApi";
import Card from "@/components/ui/Card";
import Select from "@/components/ui/Select";

const fmt = (v: number) =>
  new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" }).format(v);

const MONTH_NAMES = ["Jan","Fev","Mar","Abr","Mai","Jun","Jul","Ago","Set","Out","Nov","Dez"];
const MONTH_NAMES_FULL = ["Janeiro","Fevereiro","Março","Abril","Maio","Junho","Julho","Agosto","Setembro","Outubro","Novembro","Dezembro"];

type Tab = "annual" | "monthly";

export default function Reports() {
  const today = new Date();
  const currentYear = today.getFullYear();
  const currentMonth = today.getMonth() + 1;

  const [tab, setTab] = useState<Tab>("annual");
  const [year, setYear] = useState(currentYear);
  const [detailYear, setDetailYear] = useState(currentYear);
  const [detailMonth, setDetailMonth] = useState(currentMonth);

  const { data, isLoading } = useMonthlyReport(year);
  const { data: detail, isLoading: detailLoading } = useMonthlyDetail(detailYear, detailMonth);

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
      <div className="flex items-center justify-between flex-wrap gap-3">
        <h1 className="text-2xl font-bold text-gray-900">Relatórios</h1>

        {/* Tabs */}
        <div className="flex gap-1 bg-gray-100 dark:bg-gray-800 rounded-xl p-1">
          {(["annual", "monthly"] as Tab[]).map((t) => (
            <button
              key={t}
              onClick={() => setTab(t)}
              className={`px-4 py-1.5 rounded-lg text-sm font-medium transition-colors ${
                tab === t
                  ? "bg-white dark:bg-gray-700 text-gray-900 dark:text-white shadow-sm"
                  : "text-gray-500 hover:text-gray-700 dark:hover:text-gray-300"
              }`}
            >
              {t === "annual" ? "Anual" : "Mensal"}
            </button>
          ))}
        </div>
      </div>

      {/* ── ANUAL ─────────────────────────────────────────── */}
      {tab === "annual" && (
        <>
          <div className="flex items-center justify-between">
            <p className="text-sm text-gray-500">Visão anual de receitas e despesas</p>
            <div className="w-28">
              <Select value={year} onChange={(e) => setYear(Number(e.target.value))}>
                {years.map((y) => <option key={y} value={y}>{y}</option>)}
              </Select>
            </div>
          </div>

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
                    <Line type="monotone" dataKey="Saldo" stroke="#6366f1" strokeWidth={2} dot={{ fill: "#6366f1", r: 4 }} />
                  </LineChart>
                </ResponsiveContainer>
              </Card>

              <Card padding={false}>
                <div className="px-5 py-4 border-b border-gray-100 dark:border-gray-700">
                  <h2 className="text-sm font-semibold text-gray-900">Resumo Mensal {year}</h2>
                </div>
                <div className="overflow-x-auto">
                  <table className="w-full text-sm">
                    <thead>
                      <tr className="text-xs text-gray-500 uppercase tracking-wide border-b border-gray-100 dark:border-gray-700">
                        <th className="px-5 py-3 text-left font-medium">Mês</th>
                        <th className="px-5 py-3 text-right font-medium text-green-600">Receitas</th>
                        <th className="px-5 py-3 text-right font-medium text-red-500">Despesas</th>
                        <th className="px-5 py-3 text-right font-medium">Saldo</th>
                        <th className="px-5 py-3 text-right font-medium text-xs text-gray-400">Detalhar</th>
                      </tr>
                    </thead>
                    <tbody>
                      {(data || []).map((m, i) => {
                        const balance = Number(m.income) - Number(m.expense);
                        const [y, mo] = m.month.split("-").map(Number);
                        return (
                          <tr key={m.month} className="border-b border-gray-100 last:border-0 hover:bg-gray-50/50 dark:hover:bg-gray-800/50">
                            <td className="px-5 py-3 font-medium text-gray-900">{MONTH_NAMES[i]}</td>
                            <td className="px-5 py-3 text-right text-green-600">{fmt(Number(m.income))}</td>
                            <td className="px-5 py-3 text-right text-red-500">{fmt(Number(m.expense))}</td>
                            <td className={`px-5 py-3 text-right font-semibold ${balance >= 0 ? "text-green-600" : "text-red-500"}`}>
                              {fmt(balance)}
                            </td>
                            <td className="px-5 py-3 text-right">
                              <button
                                onClick={() => { setDetailYear(y); setDetailMonth(mo); setTab("monthly"); }}
                                className="text-xs text-indigo-500 hover:text-indigo-700 font-medium"
                              >
                                Ver →
                              </button>
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
        </>
      )}

      {/* ── MENSAL ─────────────────────────────────────────── */}
      {tab === "monthly" && (
        <>
          <div className="flex items-center gap-3 flex-wrap">
            <p className="text-sm text-gray-500 flex-1">Detalhamento por mês</p>
            <div className="w-28">
              <Select value={detailYear} onChange={(e) => setDetailYear(Number(e.target.value))}>
                {years.map((y) => <option key={y} value={y}>{y}</option>)}
              </Select>
            </div>
            <div className="w-36">
              <Select value={detailMonth} onChange={(e) => setDetailMonth(Number(e.target.value))}>
                {MONTH_NAMES_FULL.map((name, i) => (
                  <option key={i + 1} value={i + 1}>{name}</option>
                ))}
              </Select>
            </div>
          </div>

          {detailLoading ? (
            <div className="flex items-center justify-center h-40">
              <div className="animate-spin w-6 h-6 border-4 border-primary-200 border-t-primary-600 rounded-full" />
            </div>
          ) : detail && (
            <>
              {/* Summary cards */}
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                <Card>
                  <p className="text-sm text-gray-500">Receitas</p>
                  <p className="text-2xl font-bold text-green-600 mt-1">{fmt(Number(detail.income))}</p>
                </Card>
                <Card>
                  <p className="text-sm text-gray-500">Despesas</p>
                  <p className="text-2xl font-bold text-red-500 mt-1">{fmt(Number(detail.expense))}</p>
                </Card>
                <Card>
                  <p className="text-sm text-gray-500">Saldo</p>
                  <p className={`text-2xl font-bold mt-1 ${Number(detail.balance) >= 0 ? "text-green-600" : "text-red-500"}`}>
                    {fmt(Number(detail.balance))}
                  </p>
                </Card>
              </div>

              {detail.expense_by_category.length > 0 && (
                <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                  {/* Pie chart */}
                  <Card>
                    <h2 className="text-sm font-semibold text-gray-900 mb-4">
                      Despesas por Categoria — {MONTH_NAMES_FULL[detailMonth - 1]} {detailYear}
                    </h2>
                    <ResponsiveContainer width="100%" height={220}>
                      <PieChart>
                        <Pie
                          data={detail.expense_by_category.map((c) => ({ ...c, total: Number(c.total) }))}
                          dataKey="total"
                          nameKey="category_name"
                          cx="50%"
                          cy="50%"
                          innerRadius={55}
                          outerRadius={90}
                          paddingAngle={2}
                        >
                          {detail.expense_by_category.map((c, i) => (
                            <Cell key={i} fill={c.category_color} />
                          ))}
                        </Pie>
                        <Tooltip formatter={(v: number) => fmt(v)} />
                      </PieChart>
                    </ResponsiveContainer>
                  </Card>

                  {/* Category breakdown */}
                  <Card>
                    <h2 className="text-sm font-semibold text-gray-900 mb-4">Distribuição</h2>
                    <div className="space-y-3">
                      {detail.expense_by_category.map((c, i) => (
                        <div key={i}>
                          <div className="flex items-center justify-between text-sm mb-1">
                            <div className="flex items-center gap-2">
                              <span className="w-2.5 h-2.5 rounded-full flex-shrink-0" style={{ backgroundColor: c.category_color }} />
                              <span className="text-gray-700 truncate max-w-[150px]">{c.category_name}</span>
                            </div>
                            <div className="flex items-center gap-3 text-xs">
                              <span className="text-gray-400">{c.percentage.toFixed(1)}%</span>
                              <span className="font-medium text-gray-900">{fmt(Number(c.total))}</span>
                            </div>
                          </div>
                          <div className="h-1.5 bg-gray-100 dark:bg-gray-700 rounded-full overflow-hidden">
                            <div
                              className="h-full rounded-full transition-all"
                              style={{ width: `${c.percentage}%`, backgroundColor: c.category_color }}
                            />
                          </div>
                        </div>
                      ))}
                    </div>
                  </Card>
                </div>
              )}

              {/* Top transactions */}
              {detail.top_transactions.length > 0 && (
                <Card padding={false}>
                  <div className="px-5 py-4 border-b border-gray-100 dark:border-gray-700">
                    <h2 className="text-sm font-semibold text-gray-900">
                      Maiores Despesas — {MONTH_NAMES_FULL[detailMonth - 1]} {detailYear}
                    </h2>
                  </div>
                  <div>
                    {detail.top_transactions.map((tx, i) => (
                      <div key={tx.id} className="flex items-center justify-between px-5 py-3 border-b border-gray-100 dark:border-gray-700 last:border-0">
                        <div className="flex items-center gap-3">
                          <span className="text-xs text-gray-400 w-5 text-right">{i + 1}.</span>
                          <div>
                            <p className="text-sm font-medium text-gray-900">{tx.description}</p>
                            <p className="text-xs text-gray-400">
                              {tx.category?.name || "Sem categoria"} · {tx.transaction_date.split("-").reverse().join("/")}
                            </p>
                          </div>
                        </div>
                        <span className="text-sm font-semibold text-red-500 ml-3">{fmt(Number(tx.amount))}</span>
                      </div>
                    ))}
                  </div>
                </Card>
              )}

              {detail.expense_by_category.length === 0 && (
                <div className="text-center py-16 text-gray-400">
                  <p>Nenhuma despesa em {MONTH_NAMES_FULL[detailMonth - 1]} {detailYear}</p>
                </div>
              )}
            </>
          )}
        </>
      )}
    </div>
  );
}
