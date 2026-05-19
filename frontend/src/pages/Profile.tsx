import { useState } from "react";
import { useForm } from "react-hook-form";
import { CheckCircle, UserCircle } from "lucide-react";
import { useAuthStore } from "@/store/auth";
import { useUpdateProfile, useChangePassword } from "@/hooks/useApi";
import Card from "@/components/ui/Card";
import Input from "@/components/ui/Input";
import Button from "@/components/ui/Button";

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

export default function Profile() {
  const { user } = useAuthStore();

  return (
    <div className="space-y-6 max-w-3xl">
      <div className="flex items-center gap-3">
        <div className="w-10 h-10 rounded-full bg-primary-100 flex items-center justify-center">
          <UserCircle size={22} className="text-primary-600" />
        </div>
        <div>
          <h1 className="text-2xl font-bold text-gray-900">{user?.name}</h1>
          <p className="text-sm text-gray-500">{user?.email}</p>
        </div>
      </div>

      <ProfileSection />
      <PasswordSection />
    </div>
  );
}
