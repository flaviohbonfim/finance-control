import { useState } from "react";
import { useForm } from "react-hook-form";
import { Plus, Pencil, Trash2, RefreshCcw, CheckCircle, Play } from "lucide-react";
import {
  useRecurringTransactions,
  useCreateRecurring,
  useUpdateRecurring,
  useDeleteRecurring,
  useLaunchRecurring,
  useAccounts,
  useCategories,
} from "@/hooks/useApi";
import type { RecurringTransaction, TransactionType, RecurringFrequency } from "@/types";
import Card from "@/components/ui/Card";
import Button from "@/components/ui/Button";
import Modal from "@/components/ui/Modal";
import Input from "@/components/ui/Input";
import Select from "@/components/ui/Select";
import Badge from "@/components/ui/Badge";

const fmt = (v: number) =>
  new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" }).format(v);

const frequencyLabel: Record<RecurringFrequency, string> = {
  monthly: "Mensal",
  yearly: "Anual",
};

const MONTH_NAMES = [
  "Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
  "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro",
];

interface FormData {
  account_id: number;
  category_id: number | null;
  type: TransactionType;
  description: string;
  amount: number | null;
  is_fixed: boolean;
  frequency: RecurringFrequency;
  due_day: number;
  due_month: number | null;
  start_date: string;
  end_date: string | null;
  active: boolean;
}

interface LaunchFormData {
  amount: number;
}

export default function Recorrentes() {
  const { data: recurring = [], isLoading } = useRecurringTransactions();
  const { data: accounts = [] } = useAccounts();
  const { data: categories = [] } = useCategories();
  const create = useCreateRecurring();
  const update = useUpdateRecurring();
  const remove = useDeleteRecurring();
  const launch = useLaunchRecurring();

  const [modalOpen, setModalOpen] = useState(false);
  const [editing, setEditing] = useState<RecurringTransaction | null>(null);
  const [submitError, setSubmitError] = useState("");

  const [launchModalOpen, setLaunchModalOpen] = useState(false);
  const [launching, setLaunching] = useState<RecurringTransaction | null>(null);
  const [launchError, setLaunchError] = useState("");
  const [launchSuccess, setLaunchSuccess] = useState(false);

  const {
    register,
    handleSubmit,
    reset,
    watch,
    formState: { errors },
  } = useForm<FormData>({
    defaultValues: {
      is_fixed: true,
      active: true,
      start_date: new Date().toISOString().slice(0, 10),
    },
  });

  const {
    register: registerLaunch,
    handleSubmit: handleLaunchSubmit,
    reset: resetLaunch,
    formState: { errors: launchErrors },
  } = useForm<LaunchFormData>();

  const watchFrequency = watch("frequency");
  const watchIsFixed = watch("is_fixed");
  const watchType = watch("type");

  const openCreate = () => {
    setEditing(null);
    reset({
      is_fixed: true,
      active: true,
      start_date: new Date().toISOString().slice(0, 10),
      amount: null,
      category_id: null,
      end_date: null,
      due_month: null,
    });
    setSubmitError("");
    setModalOpen(true);
  };

  const openEdit = (rt: RecurringTransaction) => {
    setEditing(rt);
    reset({
      account_id: rt.account_id,
      category_id: rt.category_id,
      type: rt.type,
      description: rt.description,
      amount: rt.amount ?? null,
      is_fixed: rt.is_fixed,
      frequency: rt.frequency,
      due_day: rt.due_day,
      due_month: rt.due_month ?? null,
      start_date: rt.start_date,
      end_date: rt.end_date ?? null,
      active: rt.active,
    });
    setSubmitError("");
    setModalOpen(true);
  };

  const onSubmit = async (data: FormData) => {
    try {
      const payload = {
        ...data,
        account_id: Number(data.account_id),
        category_id: data.category_id ? Number(data.category_id) : null,
        amount: data.amount ? Number(data.amount) : null,
        due_day: Number(data.due_day),
        due_month: data.due_month ? Number(data.due_month) : null,
        end_date: data.end_date || null,
        last_launched_date: null,
      };
      if (editing) {
        await update.mutateAsync({ id: editing.id, ...payload });
      } else {
        await create.mutateAsync(payload as Parameters<typeof create.mutateAsync>[0]);
      }
      setModalOpen(false);
    } catch (e: unknown) {
      const msg = (e as { response?: { data?: { detail?: string } } })?.response?.data?.detail;
      setSubmitError(msg || "Erro ao salvar recorrente");
    }
  };

  const openLaunch = (rt: RecurringTransaction) => {
    setLaunching(rt);
    resetLaunch({ amount: rt.amount ? Number(rt.amount) : undefined });
    setLaunchError("");
    setLaunchSuccess(false);
    setLaunchModalOpen(true);
  };

  const onLaunch = async (data: LaunchFormData) => {
    if (!launching) return;
    try {
      await launch.mutateAsync({
        id: launching.id,
        amount: launching.is_fixed ? (launching.amount ? Number(launching.amount) : undefined) : Number(data.amount),
      });
      setLaunchSuccess(true);
      setTimeout(() => {
        setLaunchModalOpen(false);
        setLaunchSuccess(false);
      }, 1500);
    } catch (e: unknown) {
      const msg = (e as { response?: { data?: { detail?: string } } })?.response?.data?.detail;
      setLaunchError(msg || "Erro ao lançar recorrente");
    }
  };

  const income = recurring.filter((r) => r.type === "income");
  const expense = recurring.filter((r) => r.type === "expense");

  const filteredCategories = categories.filter((c) => !watchType || c.type === watchType);

  function RecurringItem({ rt }: { rt: RecurringTransaction }) {
    return (
      <div className="flex items-center gap-3 p-3 rounded-xl border border-gray-100 hover:border-gray-200 bg-white transition-colors">
        <div
          className="w-9 h-9 rounded-xl flex items-center justify-center flex-shrink-0"
          style={{
            backgroundColor: rt.category_color ? `${rt.category_color}20` : "#6366f120",
            color: rt.category_color || "#6366f1",
          }}
        >
          <RefreshCcw size={15} />
        </div>
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2 flex-wrap">
            <p className="font-medium text-gray-900 truncate">{rt.description}</p>
            {rt.launched_this_month && (
              <span className="inline-flex items-center gap-1 text-xs font-medium text-green-700 bg-green-50 px-2 py-0.5 rounded-full">
                <CheckCircle size={11} /> Lançado
              </span>
            )}
          </div>
          <div className="flex items-center gap-2 mt-0.5 flex-wrap">
            <span className="text-xs text-gray-500">{rt.account_name}</span>
            {rt.category_name && (
              <Badge color={rt.category_color || "#6366f1"}>{rt.category_name}</Badge>
            )}
            <span className="text-xs text-gray-400">
              {frequencyLabel[rt.frequency]} · dia {rt.due_day}
              {rt.frequency === "yearly" && rt.due_month
                ? ` de ${MONTH_NAMES[rt.due_month - 1]}`
                : ""}
            </span>
          </div>
        </div>
        <div className="flex-shrink-0 text-right">
          {rt.amount !== null ? (
            <p
              className={`text-sm font-semibold ${
                rt.type === "income" ? "text-green-600" : "text-red-500"
              }`}
            >
              {rt.type === "income" ? "+" : "-"}
              {fmt(Number(rt.amount))}
            </p>
          ) : (
            <p className="text-xs text-gray-400">Variável</p>
          )}
        </div>
        <div className="flex gap-1 ml-1 flex-shrink-0">
          {!rt.launched_this_month && rt.active && (
            <button
              onClick={() => openLaunch(rt)}
              className="p-1.5 rounded-lg text-gray-400 hover:text-primary-600 hover:bg-primary-50 transition-colors"
              title="Lançar"
            >
              <Play size={13} />
            </button>
          )}
          <button
            onClick={() => openEdit(rt)}
            className="p-1.5 rounded-lg text-gray-400 hover:text-gray-700 hover:bg-gray-100 transition-colors"
          >
            <Pencil size={13} />
          </button>
          <button
            onClick={() => remove.mutate(rt.id)}
            className="p-1.5 rounded-lg text-gray-400 hover:text-red-600 hover:bg-red-50 transition-colors"
          >
            <Trash2 size={13} />
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Recorrentes</h1>
          <p className="text-sm text-gray-500 mt-0.5">Receitas e despesas recorrentes</p>
        </div>
        <Button onClick={openCreate} size="sm">
          <Plus size={16} /> Novo Recorrente
        </Button>
      </div>

      {isLoading ? (
        <div className="flex items-center justify-center h-40">
          <div className="animate-spin w-6 h-6 border-4 border-primary-200 border-t-primary-600 rounded-full" />
        </div>
      ) : (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <Card>
            <h2 className="text-sm font-semibold text-green-700 bg-green-50 px-3 py-1.5 rounded-lg inline-block mb-4">
              Receitas ({income.length})
            </h2>
            <div className="space-y-2">
              {income.map((rt) => (
                <RecurringItem key={rt.id} rt={rt} />
              ))}
              {income.length === 0 && (
                <p className="text-sm text-gray-400 text-center py-6">
                  Nenhuma receita recorrente
                </p>
              )}
            </div>
          </Card>

          <Card>
            <h2 className="text-sm font-semibold text-red-700 bg-red-50 px-3 py-1.5 rounded-lg inline-block mb-4">
              Despesas ({expense.length})
            </h2>
            <div className="space-y-2">
              {expense.map((rt) => (
                <RecurringItem key={rt.id} rt={rt} />
              ))}
              {expense.length === 0 && (
                <p className="text-sm text-gray-400 text-center py-6">
                  Nenhuma despesa recorrente
                </p>
              )}
            </div>
          </Card>
        </div>
      )}

      {/* Create / Edit Modal */}
      <Modal
        open={modalOpen}
        onClose={() => setModalOpen(false)}
        title={editing ? "Editar Recorrente" : "Novo Recorrente"}
      >
        <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
          <Select
            label="Tipo"
            error={errors.type?.message}
            {...register("type", { required: true })}
          >
            <option value="">Selecione...</option>
            <option value="income">Receita</option>
            <option value="expense">Despesa</option>
          </Select>
          <Select
            label="Conta"
            error={errors.account_id?.message}
            {...register("account_id", { required: true })}
          >
            <option value="">Selecione...</option>
            {accounts.map((a) => (
              <option key={a.id} value={a.id}>
                {a.name}
              </option>
            ))}
          </Select>
          <Select label="Categoria" {...register("category_id")}>
            <option value="">Sem categoria</option>
            {filteredCategories.map((c) => (
              <option key={c.id} value={c.id}>
                {c.name}
              </option>
            ))}
          </Select>
          <Input
            label="Descrição"
            placeholder="Ex: Aluguel, Salário..."
            error={errors.description?.message}
            {...register("description", { required: "Descrição obrigatória" })}
          />
          <Select
            label="Frequência"
            error={errors.frequency?.message}
            {...register("frequency", { required: true })}
          >
            <option value="">Selecione...</option>
            <option value="monthly">Mensal</option>
            <option value="yearly">Anual</option>
          </Select>
          <Input
            label="Dia de vencimento"
            type="number"
            min="1"
            max="31"
            placeholder="1-31"
            error={errors.due_day?.message}
            {...register("due_day", { required: "Dia obrigatório", min: 1, max: 31 })}
          />
          {watchFrequency === "yearly" && (
            <Select label="Mês de vencimento" {...register("due_month")}>
              <option value="">Selecione...</option>
              {MONTH_NAMES.map((m, i) => (
                <option key={i + 1} value={i + 1}>
                  {m}
                </option>
              ))}
            </Select>
          )}
          <div className="flex items-center gap-2">
            <input type="checkbox" id="is_fixed" {...register("is_fixed")} className="rounded" />
            <label htmlFor="is_fixed" className="text-sm font-medium text-gray-700">
              Valor fixo
            </label>
          </div>
          {watchIsFixed && (
            <Input
              label="Valor (R$)"
              type="number"
              step="0.01"
              min="0.01"
              placeholder="0,00"
              {...register("amount", { valueAsNumber: true })}
            />
          )}
          <Input
            label="Data de início"
            type="date"
            error={errors.start_date?.message}
            {...register("start_date", { required: "Data de início obrigatória" })}
          />
          <Input
            label="Data de término (opcional)"
            type="date"
            {...register("end_date")}
          />
          <div className="flex items-center gap-2">
            <input type="checkbox" id="active" {...register("active")} className="rounded" />
            <label htmlFor="active" className="text-sm font-medium text-gray-700">
              Ativo
            </label>
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

      {/* Launch Modal */}
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
          <form onSubmit={handleLaunchSubmit(onLaunch)} className="space-y-4">
            {launching && (
              <div className="bg-gray-50 rounded-lg px-4 py-3 text-sm text-gray-700">
                <p className="font-medium">{launching.description}</p>
                <p className="text-gray-500 mt-0.5">
                  {launching.type === "income" ? "Receita" : "Despesa"} ·{" "}
                  {launching.account_name}
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
                error={launchErrors.amount?.message}
                {...registerLaunch("amount", { required: "Valor obrigatório", min: 0.01 })}
              />
            )}
            {launching && launching.is_fixed && launching.amount && (
              <p className="text-sm text-gray-600">
                Valor:{" "}
                <span className="font-semibold">{fmt(Number(launching.amount))}</span>
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
    </div>
  );
}
