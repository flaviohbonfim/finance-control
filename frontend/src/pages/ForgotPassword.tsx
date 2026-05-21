import { useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { useForm } from "react-hook-form";
import { TrendingUp } from "lucide-react";
import { useForgotPassword } from "@/hooks/useApi";
import Button from "@/components/ui/Button";
import Input from "@/components/ui/Input";

interface FormData {
  email: string;
}

export default function ForgotPassword() {
  const navigate = useNavigate();
  const forgotPassword = useForgotPassword();
  const [sent, setSent] = useState(false);
  const { register, handleSubmit, getValues, formState: { errors } } = useForm<FormData>();

  const onSubmit = async (data: FormData) => {
    await forgotPassword.mutateAsync(data);
    setSent(true);
  };

  if (sent) {
    return (
      <div className="min-h-screen flex items-center justify-center p-4" style={{ background: "linear-gradient(135deg, var(--theme-accent-light) 0%, var(--theme-bg) 100%)" }}>
        <div className="w-full max-w-md">
          <div className="rounded-2xl shadow-xl p-8 text-center" style={{ backgroundColor: "var(--theme-surface)" }}>
            <div className="w-12 h-12 bg-green-100 rounded-xl flex items-center justify-center mx-auto mb-4">
              <span className="text-2xl">✉️</span>
            </div>
            <h2 className="text-xl font-bold text-gray-900 mb-2">Verifique seu email</h2>
            <p className="text-sm text-gray-500 mb-6">
              Se o email <span className="font-medium text-gray-700">{getValues("email")}</span> estiver cadastrado,
              você receberá um código para redefinir sua senha.
            </p>
            <Button
              className="w-full mb-3"
              size="lg"
              onClick={() => navigate(`/reset-password?email=${encodeURIComponent(getValues("email"))}`)}
            >
              Inserir código
            </Button>
            <Link to="/login" className="text-sm text-primary-600 font-medium hover:underline">
              Voltar ao login
            </Link>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen flex items-center justify-center p-4" style={{ background: "linear-gradient(135deg, var(--theme-accent-light) 0%, var(--theme-bg) 100%)" }}>
      <div className="w-full max-w-md">
        <div className="rounded-2xl shadow-xl p-8" style={{ backgroundColor: "var(--theme-surface)" }}>
          <div className="flex flex-col items-center mb-8">
            <div className="w-12 h-12 bg-primary-600 rounded-xl flex items-center justify-center mb-3">
              <TrendingUp size={24} className="text-white" />
            </div>
            <h1 className="text-2xl font-bold text-gray-900">Esqueci minha senha</h1>
            <p className="text-sm text-gray-500 mt-1 text-center">
              Informe seu email para receber o código de recuperação
            </p>
          </div>

          <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
            <Input
              label="Email"
              type="email"
              placeholder="seu@email.com"
              error={errors.email?.message}
              {...register("email", { required: "Email obrigatório" })}
            />

            <Button type="submit" className="w-full" size="lg" loading={forgotPassword.isPending}>
              Enviar código
            </Button>
          </form>

          <p className="mt-6 text-center text-sm text-gray-600">
            <Link to="/login" className="text-primary-600 font-medium hover:underline">
              Voltar ao login
            </Link>
          </p>
        </div>
      </div>
    </div>
  );
}
