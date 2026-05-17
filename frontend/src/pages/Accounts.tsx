import { useState } from "react";
import { useForm } from "react-hook-form";
import { Plus, Pencil, Trash2, Wallet } from "lucide-react";
import {
  useAccounts,
  useCreateAccount,
  useUpdateAccount,
  useDeleteAccount,
} from "@/hooks/useApi";
import type { Account, AccountType } from "@/types";
import Card from "@/components/ui/Card";
import Button from "@/components/ui/Button";
import Modal from "@/components/ui/Modal";
import Input from "@/components/ui/Input";
import Select from "@/components/ui/Select";

const fmt = (v: number) =>
  new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" }).format(v);

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
}

export default function Accounts() {
  const { data: accounts = [] } = useAccounts();
  const create = useCreateAccount();
  const update = useUpdateAccount();
  const remove = useDeleteAccount();

  const [modalOpen, setModalOpen] = useState(false);
  const [editing, setEditing] = useState<Account | null>(null);

  const { register, handleSubmit, reset, formState: { errors } } = useForm<FormData>({
    defaultValues: { color: "#6366f1", balance: 0 },
  });

  const openCreate = () => {
    setEditing(null);
    reset({ color: "#6366f1", balance: 0 });
    setModalOpen(true);
  };

  const openEdit = (acc: Account) => {
    setEditing(acc);
    reset({ name: acc.name, type: acc.type, color: acc.color, balance: acc.balance });
    setModalOpen(true);
  };

  const onSubmit = async (data: FormData) => {
    if (editing) {
      await update.mutateAsync({ id: editing.id, ...data });
    } else {
      await create.mutateAsync(data);
    }
    setModalOpen(false);
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
                  <Wallet size={20} style={{ color: acc.color }} />
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
          <Select label="Tipo" error={errors.type?.message} {...register("type", { required: true })}>
            <option value="">Selecione...</option>
            {Object.entries(accountTypeLabels).map(([v, l]) => (
              <option key={v} value={v}>{l}</option>
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
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Cor</label>
            <input type="color" {...register("color")} className="h-9 w-full rounded-lg border border-gray-300 cursor-pointer" />
          </div>
          <div className="flex gap-3 pt-2">
            <Button type="button" variant="secondary" className="flex-1" onClick={() => setModalOpen(false)}>
              Cancelar
            </Button>
            <Button type="submit" className="flex-1" loading={create.isPending || update.isPending}>
              {editing ? "Salvar" : "Criar"}
            </Button>
          </div>
        </form>
      </Modal>
    </div>
  );
}
