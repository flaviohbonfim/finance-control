import { useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { useForm } from "react-hook-form";
import { TrendingUp } from "lucide-react";
import { useRegister } from "@/hooks/useApi";
import { useAuthStore } from "@/store/auth";
import Button from "@/components/ui/Button";
import Input from "@/components/ui/Input";

interface FormData {
  name: string;
  email: string;
  password: string;
}

export default function Register() {
  const navigate = useNavigate();
  const { setAuth } = useAuthStore();
  const register_ = useRegister();
  const [error, setError] = useState("");
  const { register, handleSubmit, formState: { errors } } = useForm<FormData>();

  const onSubmit = async (data: FormData) => {
    setError("");
    try {
      const res = await register_.mutateAsync(data);
      setAuth(res.access_token, res.user);
      navigate("/");
    } catch (e: unknown) {
      const msg = (e as { response?: { data?: { detail?: string } } })?.response?.data?.detail;
      setError(msg || "Erro ao criar conta");
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-primary-50 to-indigo-100 flex items-center justify-center p-4">
      <div className="w-full max-w-md">
        <div className="bg-white rounded-2xl shadow-xl p-8">
          <div className="flex flex-col items-center mb-8">
            <div className="w-12 h-12 bg-primary-600 rounded-xl flex items-center justify-center mb-3">
              <TrendingUp size={24} className="text-white" />
            </div>
            <h1 className="text-2xl font-bold text-gray-900">Criar conta</h1>
            <p className="text-sm text-gray-500 mt-1">Comece a controlar suas finanças</p>
          </div>

          <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
            <Input
              label="Nome"
              placeholder="Seu nome"
              error={errors.name?.message}
              {...register("name", { required: "Nome obrigatório" })}
            />
            <Input
              label="Email"
              type="email"
              placeholder="seu@email.com"
              error={errors.email?.message}
              {...register("email", { required: "Email obrigatório" })}
            />
            <Input
              label="Senha"
              type="password"
              placeholder="Mínimo 6 caracteres"
              error={errors.password?.message}
              {...register("password", {
                required: "Senha obrigatória",
                minLength: { value: 6, message: "Mínimo 6 caracteres" },
              })}
            />

            {error && (
              <p className="text-sm text-red-600 bg-red-50 px-3 py-2 rounded-lg">{error}</p>
            )}

            <Button type="submit" className="w-full" size="lg" loading={register_.isPending}>
              Criar conta
            </Button>
          </form>

          <p className="mt-6 text-center text-sm text-gray-600">
            Já tem conta?{" "}
            <Link to="/login" className="text-primary-600 font-medium hover:underline">
              Entrar
            </Link>
          </p>
        </div>
      </div>
    </div>
  );
}
