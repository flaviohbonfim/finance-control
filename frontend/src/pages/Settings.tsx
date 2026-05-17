import { useState } from "react";
import { useForm } from "react-hook-form";
import { CheckCircle } from "lucide-react";
import { themes, getTheme } from "@/themes";
import { useThemeStore } from "@/store/theme";
import { useAuthStore } from "@/store/auth";
import { useUpdateProfile, useChangePassword } from "@/hooks/useApi";
import Card from "@/components/ui/Card";
import Input from "@/components/ui/Input";
import Button from "@/components/ui/Button";

function ThemeCard({
  theme,
  selected,
  onSelect,
}: {
  theme: import("@/themes").Theme;
  selected: boolean;
  onSelect: () => void;
}) {
  const c = theme.colors;
  return (
    <button
      onClick={onSelect}
      className={`w-full text-left rounded-xl border-2 overflow-hidden transition-all ${
        selected ? "border-primary-600 ring-2 ring-primary-200 ring-offset-1" : "border-gray-200 hover:border-gray-300"
      }`}
    >
      {/* Preview */}
      <div className="h-20 p-2 flex gap-1.5" style={{ backgroundColor: c.bg }}>
        {/* Sidebar mini */}
        <div className="w-10 h-full rounded flex flex-col gap-1 p-1" style={{ backgroundColor: c.sidebar }}>
          {[...Array(4)].map((_, i) => (
            <div key={i} className="h-1.5 rounded-full" style={{ backgroundColor: i === 0 ? c.accent : c.border }} />
          ))}
        </div>
        {/* Content mini */}
        <div className="flex-1 flex flex-col gap-1">
          <div className="grid grid-cols-2 gap-1 flex-1">
            {[c.income, c.expense, c.accent, c.surface2].map((color, i) => (
              <div key={i} className="rounded p-1 flex items-end" style={{ backgroundColor: c.surface }}>
                <div className="w-full h-2 rounded-full" style={{ backgroundColor: color, opacity: 0.8 }} />
              </div>
            ))}
          </div>
        </div>
      </div>
      {/* Label */}
      <div className="px-3 py-2 bg-white border-t border-gray-100 flex items-center justify-between">
        <span className="text-xs font-medium text-gray-900">
          {theme.emoji} {theme.name}
        </span>
        {selected && (
          <span className="text-xs text-primary-600 font-semibold">Ativo</span>
        )}
      </div>
    </button>
  );
}

interface ProfileForm {
  name: string;
  email: string;
}

interface PasswordForm {
  current_password: string;
  new_password: string;
  confirm_password: string;
}

function ProfileSection() {
  const { user, updateUser } = useAuthStore();
  const updateProfile = useUpdateProfile();
  const [success, setSuccess] = useState(false);

  const { register, handleSubmit, formState: { errors } } = useForm<ProfileForm>({
    defaultValues: { name: user?.name ?? "", email: user?.email ?? "" },
  });

  const onSubmit = async (data: ProfileForm) => {
    const updated = await updateProfile.mutateAsync(data);
    updateUser(updated);
    setSuccess(true);
    setTimeout(() => setSuccess(false), 3000);
  };

  return (
    <Card>
      <h2 className="text-sm font-semibold text-gray-900 mb-4">Dados pessoais</h2>
      <form onSubmit={handleSubmit(onSubmit)} className="space-y-4 max-w-sm">
        <Input
          label="Nome"
          error={errors.name?.message}
          {...register("name", { required: "Nome obrigatório" })}
        />
        <Input
          label="Email"
          type="email"
          error={errors.email?.message}
          {...register("email", { required: "Email obrigatório" })}
        />
        <div className="flex items-center gap-3">
          <Button type="submit" size="sm" loading={updateProfile.isPending}>
            Salvar alterações
          </Button>
          {success && (
            <span className="flex items-center gap-1.5 text-sm text-green-600">
              <CheckCircle size={15} /> Salvo com sucesso
            </span>
          )}
        </div>
        {updateProfile.isError && (
          <p className="text-sm text-red-600">
            {(updateProfile.error as { response?: { data?: { detail?: string } } })?.response?.data?.detail ?? "Erro ao salvar"}
          </p>
        )}
      </form>
    </Card>
  );
}

function PasswordSection() {
  const changePassword = useChangePassword();
  const [success, setSuccess] = useState(false);

  const { register, handleSubmit, reset, watch, formState: { errors } } = useForm<PasswordForm>();
  const newPwd = watch("new_password");

  const onSubmit = async (data: PasswordForm) => {
    await changePassword.mutateAsync({
      current_password: data.current_password,
      new_password: data.new_password,
    });
    reset();
    setSuccess(true);
    setTimeout(() => setSuccess(false), 3000);
  };

  return (
    <Card>
      <h2 className="text-sm font-semibold text-gray-900 mb-4">Alterar senha</h2>
      <form onSubmit={handleSubmit(onSubmit)} className="space-y-4 max-w-sm">
        <Input
          label="Senha atual"
          type="password"
          placeholder="••••••••"
          error={errors.current_password?.message}
          {...register("current_password", { required: "Informe a senha atual" })}
        />
        <Input
          label="Nova senha"
          type="password"
          placeholder="Mínimo 6 caracteres"
          error={errors.new_password?.message}
          {...register("new_password", {
            required: "Informe a nova senha",
            minLength: { value: 6, message: "Mínimo 6 caracteres" },
          })}
        />
        <Input
          label="Confirmar nova senha"
          type="password"
          placeholder="Repita a nova senha"
          error={errors.confirm_password?.message}
          {...register("confirm_password", {
            required: "Confirme a nova senha",
            validate: (v) => v === newPwd || "As senhas não coincidem",
          })}
        />
        <div className="flex items-center gap-3">
          <Button type="submit" size="sm" loading={changePassword.isPending}>
            Alterar senha
          </Button>
          {success && (
            <span className="flex items-center gap-1.5 text-sm text-green-600">
              <CheckCircle size={15} /> Senha alterada
            </span>
          )}
        </div>
        {changePassword.isError && (
          <p className="text-sm text-red-600">
            {(changePassword.error as { response?: { data?: { detail?: string } } })?.response?.data?.detail ?? "Erro ao alterar senha"}
          </p>
        )}
      </form>
    </Card>
  );
}

export default function Settings() {
  const { themeId, customAccent, setTheme, setCustomAccent } = useThemeStore();
  const currentTheme = getTheme(themeId);

  return (
    <div className="space-y-6 max-w-3xl">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Configurações</h1>
        <p className="text-sm text-gray-500 mt-0.5">Gerencie seu perfil e personalize a aparência do app</p>
      </div>

      <ProfileSection />
      <PasswordSection />

      <Card>
        <h2 className="text-sm font-semibold text-gray-900 mb-4">Temas</h2>
        <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
          {themes.map((theme) => (
            <ThemeCard
              key={theme.id}
              theme={theme}
              selected={themeId === theme.id}
              onSelect={() => setTheme(theme.id)}
            />
          ))}
        </div>
      </Card>

      <Card>
        <h2 className="text-sm font-semibold text-gray-900 mb-1">Cor de destaque personalizada</h2>
        <p className="text-xs text-gray-500 mb-4">
          Sobrescreve a cor de destaque do tema atual. Clique em "Resetar" para voltar à cor padrão do tema.
        </p>
        <div className="flex items-center gap-4">
          <div className="flex items-center gap-3">
            <input
              type="color"
              value={customAccent ?? currentTheme.colors.accent}
              onChange={(e) => setCustomAccent(e.target.value)}
              className="h-10 w-20 rounded-lg border border-gray-300 cursor-pointer"
            />
            <div>
              <p className="text-sm font-medium text-gray-900">
                {customAccent ? customAccent.toUpperCase() : currentTheme.colors.accent.toUpperCase()}
              </p>
              <p className="text-xs text-gray-500">
                {customAccent ? "Cor personalizada" : "Padrão do tema"}
              </p>
            </div>
          </div>
          {customAccent && (
            <button
              onClick={() => setCustomAccent(null)}
              className="text-xs text-gray-500 hover:text-red-500 underline transition-colors"
            >
              Resetar
            </button>
          )}
        </div>

        {/* Accent preview */}
        <div className="mt-4 flex flex-wrap gap-2">
          {["#6366f1","#8b5cf6","#ec4899","#f43f5e","#ef4444","#f97316","#eab308","#22c55e","#14b8a6","#06b6d4","#3b82f6","#0ea5e9"].map((color) => (
            <button
              key={color}
              onClick={() => setCustomAccent(color)}
              title={color}
              className="w-7 h-7 rounded-full border-2 transition-transform hover:scale-110"
              style={{
                backgroundColor: color,
                borderColor: customAccent === color ? color : "transparent",
                outline: customAccent === color ? `2px solid ${color}` : "none",
                outlineOffset: "2px",
              }}
            />
          ))}
        </div>
      </Card>

      <Card>
        <h2 className="text-sm font-semibold text-gray-900 mb-3">Tema atual</h2>
        <div className="flex items-center gap-3">
          <div
            className="w-10 h-10 rounded-xl flex items-center justify-center text-lg"
            style={{ backgroundColor: currentTheme.colors.accentLight }}
          >
            {currentTheme.emoji}
          </div>
          <div>
            <p className="font-medium text-gray-900">{currentTheme.name}</p>
            <p className="text-xs text-gray-500">{currentTheme.isDark ? "Tema escuro" : "Tema claro"}</p>
          </div>
        </div>
      </Card>
    </div>
  );
}
