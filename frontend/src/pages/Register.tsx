import { useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { useForm } from "react-hook-form";
import { TrendingUp } from "lucide-react";
import { GoogleLogin } from "@react-oauth/google";
import { useRegister, useGoogleAuth } from "@/hooks/useApi";
import { useAuthStore } from "@/store/auth";
import Button from "@/components/ui/Button";
import Input from "@/components/ui/Input";

interface FormData {
  name: string;
  email: string;
  password: string;
}

const GOOGLE_CLIENT_ID = import.meta.env.VITE_GOOGLE_CLIENT_ID as string | undefined;

export default function Register() {
  const navigate = useNavigate();
  const { setAuth } = useAuthStore();
  const register_ = useRegister();
  const googleAuth = useGoogleAuth();
  const [error, setError] = useState("");
  const { register, handleSubmit, formState: { errors } } = useForm<FormData>();

  const onSubmit = async (data: FormData) => {
    setError("");
    try {
      const res = await register_.mutateAsync(data);
      setAuth(res.access_token, res.user);
      navigate("/verify-email");
    } catch (e: unknown) {
      const msg = (e as { response?: { data?: { detail?: string } } })?.response?.data?.detail;
      setError(msg || "Erro ao criar conta");
    }
  };

  const handleGoogleSuccess = async (credentialResponse: { credential?: string }) => {
    if (!credentialResponse.credential) return;
    setError("");
    try {
      const res = await googleAuth.mutateAsync({ id_token: credentialResponse.credential });
      setAuth(res.access_token, res.user);
      navigate("/");
    } catch {
      setError("Erro ao entrar com Google. Tente novamente.");
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center p-4" style={{ background: "linear-gradient(135deg, var(--theme-accent-light) 0%, var(--theme-bg) 100%)" }}>
      <div className="w-full max-w-md">
        <div className="rounded-2xl shadow-xl p-8" style={{ backgroundColor: "var(--theme-surface)" }}>
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

          {GOOGLE_CLIENT_ID && (
            <>
              <div className="relative my-5">
                <div className="absolute inset-0 flex items-center">
                  <div className="w-full border-t border-gray-200" />
                </div>
                <div className="relative flex justify-center text-xs">
                  <span className="px-2 text-gray-400" style={{ backgroundColor: "var(--theme-surface)" }}>
                    ou continue com
                  </span>
                </div>
              </div>
              <div className="flex justify-center">
                <GoogleLogin
                  onSuccess={handleGoogleSuccess}
                  onError={() => setError("Erro ao entrar com Google")}
                  useOneTap={false}
                  text="signup_with"
                  shape="rectangular"
                  size="large"
                  width="368"
                />
              </div>
            </>
          )}

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
