import { useState } from "react";
import { useForm } from "react-hook-form";
import { Plus, Pencil, Trash2, Wallet, CreditCard, Receipt, ChevronDown, ChevronUp } from "lucide-react";
import {
  useAccounts,
  useCreateAccount,
  useUpdateAccount,
  useDeleteAccount,
  useAccountInvoice,
  usePayInvoice,
} from "@/hooks/useApi";
import type { Account, AccountType } from "@/types";
import Card from "@/components/ui/Card";
import Button from "@/components/ui/Button";
import Modal from "@/components/ui/Modal";
import Input from "@/components/ui/Input";
import Select from "@/components/ui/Select";

const fmt = (v: number) =>
  new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" }).format(v);

const fmtDate = (s: string) => {
  const [y, m, d] = s.split("-");
  return `${d}/${m}/${y}`;
};

const accountTypeLabels: Record<AccountType, string> = {
  checking: "Conta Corrente",
  savings: "Poupança",
  cash: "Dinheiro",
  credit_card: "Cartão de Crédito",
  investment: "Investimentos",
};

interface FormData {
  name: string;
  type: AccountType;
  balance: number;
  color: string;
  closing_day: number | null;
  due_day: number | null;
  credit_limit: number | null;
}

interface PayFormData {
  source_account_id: number;
  amount: number;
}

function TransactionList({ transactions }: { transactions: { id: number; description: string; amount: number; transaction_date: string }[] }) {
  if (transactions.length === 0)
    return <p className="text-xs text-gray-400 py-1">Nenhuma transação neste período.</p>;
  return (
    <div className="mt-2 space-y-1 max-h-48 overflow-y-auto pr-1">
      {transactions.map((t) => (
        <div key={t.id} className="flex items-center justify-between text-xs py-0.5">
          <span className="text-gray-600 truncate max-w-[60%]">{t.description}</span>
          <span className="text-red-500 font-medium whitespace-nowrap ml-2">{fmt(Number(t.amount))}</span>
        </div>
      ))}
    </div>
  );
}

function InvoiceCard({ account }: { account: Account }) {
  const { data: invoice, isLoading } = useAccountInvoice(
    account.type === "credit_card" && account.closing_day ? account.id : null
  );
  const payInvoice = usePayInvoice();
  const { data: accounts = [] } = useAccounts();
  const [payModalOpen, setPayModalOpen] = useState(false);
  const [showCurrentTxs, setShowCurrentTxs] = useState(false);
  const [showNextTxs, setShowNextTxs] = useState(false);
  const [error, setError] = useState("");

  const { register, handleSubmit, reset, formState: { errors } } = useForm<PayFormData>();

  const openPay = () => {
    reset({ amount: invoice ? Number(invoice.current_total) : 0 });
    setError("");
    setPayModalOpen(true);
  };

  const onPay = async (data: PayFormData) => {
    try {
      await payInvoice.mutateAsync({
        accountId: account.id,
        source_account_id: Number(data.source_account_id),
        amount: Number(data.amount),
      });
      setPayModalOpen(false);
    } catch (e: unknown) {
      const msg = (e as { response?: { data?: { detail?: string } } })?.response?.data?.detail;
      setError(msg || "Erro ao pagar fatura");
    }
  };

  if (!account.closing_day) return null;
  if (isLoading) return <p className="text-xs text-gray-400 mt-2">Carregando fatura...</p>;
  if (!invoice) return null;

  const debitAccounts = accounts.filter((a) => a.id !== account.id && a.type !== "credit_card");

  return (
    <>
      <div className="mt-3 pt-3 border-t border-gray-100 dark:border-gray-700 space-y-2">
        <div className="flex items-center justify-between text-xs">
          <span className="text-gray-500">Fatura atual</span>
          <span className="text-xs text-gray-400">
            {fmtDate(invoice.current_start)} – {fmtDate(invoice.current_end)}
          </span>
        </div>
        <div className="flex items-center justify-between">
          <p className="text-lg font-bold text-red-500">{fmt(Number(invoice.current_total))}</p>
          {invoice.current_transactions.length > 0 && (
            <button
              onClick={() => setShowCurrentTxs((v) => !v)}
              className="flex items-center gap-1 text-xs text-gray-400 hover:text-gray-600 transition-colors"
            >
              {invoice.current_transactions.length} lançamentos
              {showCurrentTxs ? <ChevronUp size={12} /> : <ChevronDown size={12} />}
            </button>
          )}
        </div>
        {showCurrentTxs && <TransactionList transactions={invoice.current_transactions} />}

        <div className="flex items-center justify-between text-xs mt-1">
          <span className="text-gray-500">Próxima fatura</span>
          <span className="text-xs text-gray-400">
            {fmtDate(invoice.next_start)} – {fmtDate(invoice.next_end)}
          </span>
        </div>
        <div className="flex items-center justify-between">
          <p className="text-sm font-semibold text-gray-600">{fmt(Number(invoice.next_total))}</p>
          {invoice.next_transactions.length > 0 && (
            <button
              onClick={() => setShowNextTxs((v) => !v)}
              className="flex items-center gap-1 text-xs text-gray-400 hover:text-gray-600 transition-colors"
            >
              {invoice.next_transactions.length} lançamentos
              {showNextTxs ? <ChevronUp size={12} /> : <ChevronDown size={12} />}
            </button>
          )}
        </div>
        {showNextTxs && <TransactionList transactions={invoice.next_transactions} />}

        <p className="text-xs text-gray-400">Vencimento dia {invoice.due_day}</p>

        <Button size="sm" variant="secondary" onClick={openPay} className="w-full mt-1">
          <Receipt size={14} /> Pagar Fatura
        </Button>
      </div>

      <Modal open={payModalOpen} onClose={() => setPayModalOpen(false)} title="Pagar Fatura">
        <form onSubmit={handleSubmit(onPay)} className="space-y-4">
          <Select
            label="Conta de débito"
            error={errors.source_account_id?.message}
            {...register("source_account_id", { required: "Selecione uma conta" })}
          >
            <option value="">Selecione...</option>
            {debitAccounts.map((a) => (
              <option key={a.id} value={a.id}>
                {a.name}
              </option>
            ))}
          </Select>
          <Input
            label="Valor (R$)"
            type="number"
            step="0.01"
            min="0.01"
            error={errors.amount?.message}
            {...register("amount", { required: "Valor obrigatório", min: 0.01 })}
          />
          {error && <p className="text-sm text-red-500">{error}</p>}
          <div className="flex gap-3 pt-2">
            <Button
              type="button"
              variant="secondary"
              className="flex-1"
              onClick={() => setPayModalOpen(false)}
            >
              Cancelar
            </Button>
            <Button type="submit" className="flex-1" loading={payInvoice.isPending}>
              Confirmar Pagamento
            </Button>
          </div>
        </form>
      </Modal>
    </>
  );
}

export default function Accounts() {
  const { data: accounts = [] } = useAccounts();
  const create = useCreateAccount();
  const update = useUpdateAccount();
  const remove = useDeleteAccount();

  const [modalOpen, setModalOpen] = useState(false);
  const [editing, setEditing] = useState<Account | null>(null);
  const [submitError, setSubmitError] = useState("");

  const {
    register,
    handleSubmit,
    reset,
    watch,
    formState: { errors },
  } = useForm<FormData>({
    defaultValues: { color: "#6366f1", balance: 0 },
  });

  const watchType = watch("type");

  const openCreate = () => {
    setEditing(null);
    reset({ color: "#6366f1", balance: 0, closing_day: null, due_day: null, credit_limit: null });
    setSubmitError("");
    setModalOpen(true);
  };

  const openEdit = (acc: Account) => {
    setEditing(acc);
    reset({
      name: acc.name,
      type: acc.type,
      color: acc.color,
      balance: acc.balance,
      closing_day: acc.closing_day ?? null,
      due_day: acc.due_day ?? null,
      credit_limit: acc.credit_limit ?? null,
    });
    setSubmitError("");
    setModalOpen(true);
  };

  const onSubmit = async (data: FormData) => {
    try {
      const payload = {
        ...data,
        closing_day: data.closing_day ? Number(data.closing_day) : null,
        due_day: data.due_day ? Number(data.due_day) : null,
        credit_limit: data.credit_limit ? Number(data.credit_limit) : null,
      };
      if (editing) {
        await update.mutateAsync({ id: editing.id, ...payload });
      } else {
        await create.mutateAsync(payload as Parameters<typeof create.mutateAsync>[0]);
      }
      setModalOpen(false);
    } catch (e: unknown) {
      const msg = (e as { response?: { data?: { detail?: string } } })?.response?.data?.detail;
      setSubmitError(msg || "Erro ao salvar conta");
    }
  };

  const totalBalance = accounts.reduce((s, a) => s + Number(a.balance), 0);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Contas</h1>
          <p className="text-sm text-gray-500 mt-0.5">Saldo total: {fmt(totalBalance)}</p>
        </div>
        <Button onClick={openCreate} size="sm">
          <Plus size={16} /> Nova Conta
        </Button>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        {accounts.map((acc) => (
          <Card key={acc.id}>
            <div className="flex items-start justify-between mb-3">
              <div className="flex items-center gap-3">
                <div
                  className="w-10 h-10 rounded-xl flex items-center justify-center"
                  style={{ backgroundColor: `${acc.color}20` }}
                >
                  {acc.type === "credit_card" ? (
                    <CreditCard size={20} style={{ color: acc.color }} />
                  ) : (
                    <Wallet size={20} style={{ color: acc.color }} />
                  )}
                </div>
                <div>
                  <p className="font-semibold text-gray-900">{acc.name}</p>
                  <p className="text-xs text-gray-500">{accountTypeLabels[acc.type]}</p>
                </div>
              </div>
              <div className="flex gap-1">
                <button
                  onClick={() => openEdit(acc)}
                  className="p-1.5 rounded-lg text-gray-400 hover:text-gray-700 hover:bg-gray-100 transition-colors"
                >
                  <Pencil size={14} />
                </button>
                <button
                  onClick={() => remove.mutate(acc.id)}
                  className="p-1.5 rounded-lg text-gray-400 hover:text-red-600 hover:bg-red-50 transition-colors"
                >
                  <Trash2 size={14} />
                </button>
              </div>
            </div>
            <p
              className={`text-2xl font-bold ${
                Number(acc.balance) < 0 ? "text-red-500" : "text-gray-900"
              }`}
            >
              {fmt(Number(acc.balance))}
            </p>
            {acc.type === "credit_card" && <InvoiceCard account={acc} />}
          </Card>
        ))}

        {accounts.length === 0 && (
          <div className="sm:col-span-2 lg:col-span-3 text-center py-16 text-gray-400">
            <Wallet size={40} className="mx-auto mb-3 opacity-30" />
            <p>Nenhuma conta cadastrada</p>
            <Button onClick={openCreate} size="sm" variant="ghost" className="mt-3">
              Adicionar conta
            </Button>
          </div>
        )}
      </div>

      <Modal
        open={modalOpen}
        onClose={() => setModalOpen(false)}
        title={editing ? "Editar Conta" : "Nova Conta"}
      >
        <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
          <Input
            label="Nome"
            placeholder="Ex: Nubank, Bradesco..."
            error={errors.name?.message}
            {...register("name", { required: "Nome obrigatório" })}
          />
          <Select
            label="Tipo"
            error={errors.type?.message}
            {...register("type", { required: true })}
          >
            <option value="">Selecione...</option>
            {Object.entries(accountTypeLabels).map(([v, l]) => (
              <option key={v} value={v}>
                {l}
              </option>
            ))}
          </Select>
          {!editing && (
            <Input
              label="Saldo inicial"
              type="number"
              step="0.01"
              placeholder="0,00"
              {...register("balance", { valueAsNumber: true })}
            />
          )}
          {watchType === "credit_card" && (
            <>
              <Input
                label="Dia de fechamento"
                type="number"
                min="1"
                max="31"
                placeholder="Ex: 10"
                error={errors.closing_day?.message}
                {...register("closing_day", { valueAsNumber: true })}
              />
              <Input
                label="Dia de vencimento"
                type="number"
                min="1"
                max="31"
                placeholder="Ex: 20"
                error={errors.due_day?.message}
                {...register("due_day", { valueAsNumber: true })}
              />
              <Input
                label="Limite de crédito (opcional)"
                type="number"
                step="0.01"
                min="0"
                placeholder="0,00"
                {...register("credit_limit", { valueAsNumber: true })}
              />
            </>
          )}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Cor</label>
            <input
              type="color"
              {...register("color")}
              className="h-9 w-full rounded-lg border border-gray-300 cursor-pointer"
            />
          </div>
          {submitError && <p className="text-sm text-red-500">{submitError}</p>}
          <div className="flex gap-3 pt-2">
            <Button
              type="button"
              variant="secondary"
              className="flex-1"
              onClick={() => setModalOpen(false)}
            >
              Cancelar
            </Button>
            <Button
              type="submit"
              className="flex-1"
              loading={create.isPending || update.isPending}
            >
              {editing ? "Salvar" : "Criar"}
            </Button>
          </div>
        </form>
      </Modal>
    </div>
  );
}
