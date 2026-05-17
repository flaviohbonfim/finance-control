import { useState } from "react";
import { useForm } from "react-hook-form";
import { Plus, Pencil, Trash2, Tag } from "lucide-react";
import {
  useCategories,
  useCreateCategory,
  useUpdateCategory,
  useDeleteCategory,
} from "@/hooks/useApi";
import type { Category, CategoryType } from "@/types";
import Card from "@/components/ui/Card";
import Button from "@/components/ui/Button";
import Modal from "@/components/ui/Modal";
import Input from "@/components/ui/Input";
import Select from "@/components/ui/Select";
import Badge from "@/components/ui/Badge";

const ICONS = ["tag", "home", "car", "utensils", "heart", "book", "music", "shopping-cart", "briefcase", "gift", "plane", "dumbbell"];

interface FormData {
  name: string;
  type: CategoryType;
  icon: string;
  color: string;
}

function CategoryCard({
  cat,
  onEdit,
  onDelete,
}: {
  cat: Category;
  onEdit: (c: Category) => void;
  onDelete: (id: number) => void;
}) {
  return (
    <div className="flex items-center gap-3 p-3 rounded-xl border border-gray-100 hover:border-gray-200 bg-white transition-colors">
      <div
        className="w-9 h-9 rounded-xl flex items-center justify-center flex-shrink-0"
        style={{ backgroundColor: `${cat.color}20`, color: cat.color }}
      >
        <Tag size={16} />
      </div>
      <div className="flex-1 min-w-0">
        <p className="font-medium text-gray-900 truncate">{cat.name}</p>
      </div>
      <Badge color={cat.type === "income" ? "#22c55e" : "#ef4444"}>
        {cat.type === "income" ? "Receita" : "Despesa"}
      </Badge>
      <div className="flex gap-1 ml-1">
        <button
          onClick={() => onEdit(cat)}
          className="p-1.5 rounded-lg text-gray-400 hover:text-gray-700 hover:bg-gray-100 transition-colors"
        >
          <Pencil size={14} />
        </button>
        <button
          onClick={() => onDelete(cat.id)}
          className="p-1.5 rounded-lg text-gray-400 hover:text-red-600 hover:bg-red-50 transition-colors"
        >
          <Trash2 size={14} />
        </button>
      </div>
    </div>
  );
}

export default function Categories() {
  const { data: categories = [] } = useCategories();
  const create = useCreateCategory();
  const update = useUpdateCategory();
  const remove = useDeleteCategory();

  const [modalOpen, setModalOpen] = useState(false);
  const [editing, setEditing] = useState<Category | null>(null);

  const { register, handleSubmit, reset, formState: { errors } } = useForm<FormData>({
    defaultValues: { icon: "tag", color: "#6366f1" },
  });

  const openCreate = () => {
    setEditing(null);
    reset({ icon: "tag", color: "#6366f1" });
    setModalOpen(true);
  };

  const openEdit = (cat: Category) => {
    setEditing(cat);
    reset({ name: cat.name, type: cat.type, icon: cat.icon, color: cat.color });
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

  const income = categories.filter((c) => c.type === "income");
  const expense = categories.filter((c) => c.type === "expense");

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-gray-900">Categorias</h1>
        <Button onClick={openCreate} size="sm">
          <Plus size={16} /> Nova Categoria
        </Button>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Income */}
        <Card>
          <h2 className="text-sm font-semibold text-green-700 bg-green-50 px-3 py-1.5 rounded-lg inline-block mb-4">
            Receitas ({income.length})
          </h2>
          <div className="space-y-2">
            {income.map((cat) => (
              <CategoryCard
                key={cat.id}
                cat={cat}
                onEdit={openEdit}
                onDelete={(id) => remove.mutate(id)}
              />
            ))}
            {income.length === 0 && (
              <p className="text-sm text-gray-400 text-center py-6">Nenhuma categoria de receita</p>
            )}
          </div>
        </Card>

        {/* Expense */}
        <Card>
          <h2 className="text-sm font-semibold text-red-700 bg-red-50 px-3 py-1.5 rounded-lg inline-block mb-4">
            Despesas ({expense.length})
          </h2>
          <div className="space-y-2">
            {expense.map((cat) => (
              <CategoryCard
                key={cat.id}
                cat={cat}
                onEdit={openEdit}
                onDelete={(id) => remove.mutate(id)}
              />
            ))}
            {expense.length === 0 && (
              <p className="text-sm text-gray-400 text-center py-6">Nenhuma categoria de despesa</p>
            )}
          </div>
        </Card>
      </div>

      <Modal
        open={modalOpen}
        onClose={() => setModalOpen(false)}
        title={editing ? "Editar Categoria" : "Nova Categoria"}
      >
        <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
          <Input
            label="Nome"
            placeholder="Ex: Alimentação, Salário..."
            error={errors.name?.message}
            {...register("name", { required: "Nome obrigatório" })}
          />
          <Select label="Tipo" error={errors.type?.message} {...register("type", { required: true })}>
            <option value="">Selecione...</option>
            <option value="income">Receita</option>
            <option value="expense">Despesa</option>
          </Select>
          <Select label="Ícone" {...register("icon")}>
            {ICONS.map((i) => (
              <option key={i} value={i}>{i}</option>
            ))}
          </Select>
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
