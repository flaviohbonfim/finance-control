import { useState } from "react";
import { useForm } from "react-hook-form";
import { format } from "date-fns";
import { ptBR } from "date-fns/locale";
import { Plus, Pencil, Trash2, TrendingUp, TrendingDown, ChevronLeft, ChevronRight, SlidersHorizontal } from "lucide-react";
import {
  useTransactions,
  useAccounts,
  useCategories,
  useCreateTransaction,
  useUpdateTransaction,
  useDeleteTransaction,
} from "@/hooks/useApi";
import type { Transaction, TransactionType } from "@/types";
import Card from "@/components/ui/Card";
import Button from "@/components/ui/Button";
import Modal from "@/components/ui/Modal";
import Input from "@/components/ui/Input";
import Select from "@/components/ui/Select";
import Badge from "@/components/ui/Badge";

const fmt = (v: number) =>
  new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" }).format(v);

interface FormData {
  account_id: number;
  category_id: number | null;
  type: TransactionType;
  amount: number;
  description: string;
  notes: string;
  transaction_date: string;
  installments: number;
}

export default function Transactions() {
  const [page, setPage] = useState(1);
  const [filterType, setFilterType] = useState<string>("");
  const [filterAccount, setFilterAccount] = useState<string>("");
  const [filterCategory, setFilterCategory] = useState<string>("");
  const [showFilters, setShowFilters] = useState(false);
  const [modalOpen, setModalOpen] = useState(false);
  const [editing, setEditing] = useState<Transaction | null>(null);

  const { data: accounts = [] } = useAccounts();
  const { data: categories = [] } = useCategories();
  const { data, isLoading } = useTransactions({
    page,
    page_size: 15,
    type: filterType || undefined,
    account_id: filterAccount ? Number(filterAccount) : undefined,
    category_id: filterCategory ? Number(filterCategory) : undefined,
  });

  const create = useCreateTransaction();
  const update = useUpdateTransaction();
  const remove = useDeleteTransaction();

  const { register, handleSubmit, reset, watch, formState: { errors } } = useForm<FormData>({
    defaultValues: { transaction_date: new Date().toISOString().slice(0, 10), installments: 1 },
  });

  const txType = watch("type");
  const watchAccountId = watch("account_id");
  const selectedAccount = accounts.find((a) => a.id === Number(watchAccountId));
  const showInstallments = !editing && txType === "expense" && selectedAccount?.type === "credit_card";

  const openCreate = () => {
    setEditing(null);
    reset({ transaction_date: new Date().toISOString().slice(0, 10), category_id: null, installments: 1 });
    setModalOpen(true);
  };

  const openEdit = (tx: Transaction) => {
    setEditing(tx);
    reset({
      account_id: tx.account_id,
      category_id: tx.category_id,
      type: tx.type,
      amount: Number(tx.amount),
      description: tx.description,
      notes: tx.notes || "",
      transaction_date: tx.transaction_date,
    });
    setModalOpen(true);
  };

  const onSubmit = async (data: FormData) => {
    const { installments, ...rest } = data;
    const base = {
      ...rest,
      amount: Number(data.amount),
      category_id: data.category_id ? Number(data.category_id) : null,
      account_id: Number(data.account_id),
    };
    if (editing) {
      await update.mutateAsync({ id: editing.id, ...base });
    } else {
      await create.mutateAsync({ ...base, installments: installments || 1 });
    }
    setModalOpen(false);
  };

  const filteredCategories = categories.filter((c) => !txType || c.type === txType);

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-gray-900">Transações</h1>
        <div className="flex gap-2">
          <Button
            variant={showFilters ? "primary" : "secondary"}
            size="sm"
            onClick={() => setShowFilters(!showFilters)}
          >
            <SlidersHorizontal size={16} />
            <span className="hidden sm:inline">Filtros</span>
          </Button>
          <Button size="sm" onClick={openCreate}>
            <Plus size={16} />
            <span className="hidden sm:inline">Nova</span>
          </Button>
        </div>
      </div>

      {/* Filters */}
      {showFilters && (
        <Card>
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
            <Select label="Tipo" value={filterType} onChange={(e) => { setFilterType(e.target.value); setPage(1); }}>
              <option value="">Todos</option>
              <option value="income">Receitas</option>
              <option value="expense">Despesas</option>
            </Select>
            <Select label="Conta" value={filterAccount} onChange={(e) => { setFilterAccount(e.target.value); setPage(1); }}>
              <option value="">Todas</option>
              {accounts.map((a) => <option key={a.id} value={a.id}>{a.name}</option>)}
            </Select>
            <Select label="Categoria" value={filterCategory} onChange={(e) => { setFilterCategory(e.target.value); setPage(1); }}>
              <option value="">Todas</option>
              {categories.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
            </Select>
          </div>
        </Card>
      )}

      <Card padding={false}>
        {isLoading ? (
          <div className="flex items-center justify-center h-40">
            <div className="animate-spin w-6 h-6 border-4 border-primary-200 border-t-primary-600 rounded-full" />
          </div>
        ) : (
          <>
            {/* Table header - desktop */}
            <div className="hidden sm:grid grid-cols-12 gap-2 px-4 py-3 border-b border-gray-100 text-xs font-medium text-gray-500 uppercase tracking-wide">
              <div className="col-span-1">Tipo</div>
              <div className="col-span-4">Descrição</div>
              <div className="col-span-2">Categoria</div>
              <div className="col-span-2">Data</div>
              <div className="col-span-2 text-right">Valor</div>
              <div className="col-span-1"></div>
            </div>

            {/* Rows */}
            {(data?.items || []).length === 0 ? (
              <div className="text-center py-16 text-gray-400">
                <p>Nenhuma transação encontrada</p>
                <Button onClick={openCreate} variant="ghost" size="sm" className="mt-3">
                  Adicionar transação
                </Button>
              </div>
            ) : (
              (data?.items || []).map((tx) => {
                const iconStyle = {
                  backgroundColor: `${tx.category?.color || "#6366f1"}15`,
                  color: tx.category?.color || "#6366f1",
                };
                const amountClass = tx.type === "income" ? "text-green-600" : "text-red-500";
                const amountStr = `${tx.type === "income" ? "+" : "-"}${fmt(Number(tx.amount))}`;

                return (
                  <div key={tx.id} className="border-b border-gray-100 last:border-0 hover:bg-gray-50/50 transition-colors">
                    {/* Mobile layout */}
                    <div className="flex sm:hidden items-center gap-3 px-4 py-3">
                      <div className="w-9 h-9 rounded-full flex items-center justify-center flex-shrink-0" style={iconStyle}>
                        {tx.type === "income" ? <TrendingUp size={15} /> : <TrendingDown size={15} />}
                      </div>
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center justify-between gap-2">
                          <p className="text-sm font-medium text-gray-900 truncate">{tx.description}</p>
                          <span className={`text-sm font-semibold flex-shrink-0 ${amountClass}`}>{amountStr}</span>
                        </div>
                        <div className="flex items-center justify-between mt-0.5">
                          <p className="text-xs text-gray-400">
                            {tx.category?.name || "Sem categoria"} · {format(new Date(tx.transaction_date + "T12:00:00"), "dd/MM", { locale: ptBR })}
                          </p>
                          <div className="flex gap-1 ml-2">
                            <button onClick={() => openEdit(tx)} className="p-1 rounded text-gray-400 hover:text-gray-700 hover:bg-gray-100">
                              <Pencil size={13} />
                            </button>
                            <button onClick={() => remove.mutate(tx.id)} className="p-1 rounded text-gray-400 hover:text-red-600 hover:bg-red-50">
                              <Trash2 size={13} />
                            </button>
                          </div>
                        </div>
                      </div>
                    </div>

                    {/* Desktop layout */}
                    <div className="hidden sm:grid grid-cols-12 gap-2 px-4 py-3 items-center">
                      <div className="col-span-1 flex items-center">
                        <div className="w-8 h-8 rounded-full flex items-center justify-center" style={iconStyle}>
                          {tx.type === "income" ? <TrendingUp size={14} /> : <TrendingDown size={14} />}
                        </div>
                      </div>
                      <div className="col-span-4 min-w-0">
                        <p className="text-sm font-medium text-gray-900 truncate">{tx.description}</p>
                        {tx.notes && <p className="text-xs text-gray-400 truncate">{tx.notes}</p>}
                      </div>
                      <div className="col-span-2">
                        {tx.category && <Badge color={tx.category.color}>{tx.category.name}</Badge>}
                      </div>
                      <div className="col-span-2 text-sm text-gray-500">
                        {format(new Date(tx.transaction_date + "T12:00:00"), "dd/MM/yyyy", { locale: ptBR })}
                      </div>
                      <div className="col-span-2 text-right">
                        <span className={`text-sm font-semibold ${amountClass}`}>{amountStr}</span>
                      </div>
                      <div className="col-span-1 flex justify-end gap-1">
                        <button onClick={() => openEdit(tx)} className="p-1.5 rounded-lg text-gray-400 hover:text-gray-700 hover:bg-gray-100 transition-colors">
                          <Pencil size={13} />
                        </button>
                        <button onClick={() => remove.mutate(tx.id)} className="p-1.5 rounded-lg text-gray-400 hover:text-red-600 hover:bg-red-50 transition-colors">
                          <Trash2 size={13} />
                        </button>
                      </div>
                    </div>
                  </div>
                );
              })
            )}

            {/* Pagination */}
            {data && data.pages > 1 && (
              <div className="flex items-center justify-between px-4 py-3 border-t border-gray-100">
                <p className="text-xs text-gray-500">
                  {data.total} transações · Pág. {data.page}/{data.pages}
                </p>
                <div className="flex gap-2">
                  <Button
                    variant="secondary"
                    size="sm"
                    onClick={() => setPage(page - 1)}
                    disabled={page === 1}
                  >
                    <ChevronLeft size={16} />
                  </Button>
                  <Button
                    variant="secondary"
                    size="sm"
                    onClick={() => setPage(page + 1)}
                    disabled={page === data.pages}
                  >
                    <ChevronRight size={16} />
                  </Button>
                </div>
              </div>
            )}
          </>
        )}
      </Card>

      <Modal
        open={modalOpen}
        onClose={() => setModalOpen(false)}
        title={editing ? "Editar Transação" : "Nova Transação"}
      >
        <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
          <Select label="Tipo" error={errors.type?.message} {...register("type", { required: true })}>
            <option value="">Selecione...</option>
            <option value="income">Receita</option>
            <option value="expense">Despesa</option>
          </Select>
          <Select label="Conta" error={errors.account_id?.message} {...register("account_id", { required: true })}>
            <option value="">Selecione...</option>
            {accounts.map((a) => <option key={a.id} value={a.id}>{a.name}</option>)}
          </Select>
          <Select label="Categoria" {...register("category_id")}>
            <option value="">Sem categoria</option>
            {filteredCategories.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
          </Select>
          <Input
            label="Descrição"
            placeholder="Ex: Almoço, Salário..."
            error={errors.description?.message}
            {...register("description", { required: "Descrição obrigatória" })}
          />
          <Input
            label="Valor (R$)"
            type="number"
            step="0.01"
            min="0.01"
            placeholder="0,00"
            error={errors.amount?.message}
            {...register("amount", { required: "Valor obrigatório", min: 0.01 })}
          />
          {showInstallments && (
            <Input
              label="Parcelas"
              type="number"
              min="1"
              max="48"
              placeholder="1"
              {...register("installments", { valueAsNumber: true, min: 1, max: 48 })}
            />
          )}
          <Input
            label="Data"
            type="date"
            error={errors.transaction_date?.message}
            {...register("transaction_date", { required: "Data obrigatória" })}
          />
          <Input
            label="Observações (opcional)"
            placeholder="Anotações adicionais..."
            {...register("notes")}
          />
          <div className="flex gap-3 pt-2">
            <Button type="button" variant="secondary" className="flex-1" onClick={() => setModalOpen(false)}>
              Cancelar
            </Button>
            <Button type="submit" className="flex-1" loading={create.isPending || update.isPending}>
              {editing ? "Salvar" : "Adicionar"}
            </Button>
          </div>
        </form>
      </Modal>
    </div>
  );
}
