import { useState } from "react";
import { useSearchParams } from "react-router-dom";
import { useForm } from "react-hook-form";
import { TrendingUp, ShieldCheck } from "lucide-react";
import axios from "axios";
import { useAuthStore } from "@/store/auth";
import Button from "@/components/ui/Button";
import Input from "@/components/ui/Input";

interface LoginForm {
  email: string;
  password: string;
}

export default function OAuthConsent() {
  const [searchParams] = useSearchParams();
  const { token, user, setAuth } = useAuthStore();
  const [loginError, setLoginError] = useState("");
  const [loading, setLoading] = useState(false);
  const { register, handleSubmit, formState: { errors } } = useForm<LoginForm>();

  const clientId = searchParams.get("client_id") || "";
  const redirectUri = searchParams.get("redirect_uri") || "";
  const state = searchParams.get("state") || "";
  const codeChallenge = searchParams.get("code_challenge") || "";
  const codeChallengeMethod = searchParams.get("code_challenge_method") || "";

  const paramsValid = clientId && redirectUri && state && codeChallenge && codeChallengeMethod;

  const handleLogin = async (data: LoginForm) => {
    setLoginError("");
    setLoading(true);
    try {
      const res = await axios.post("/api/v1/auth/login", data);
      setAuth(res.data.access_token, res.data.user);
    } catch {
      setLoginError("Email ou senha inválidos");
    } finally {
      setLoading(false);
    }
  };

  const handleAuthorize = async () => {
    setLoading(true);
    try {
      const res = await axios.post(
        "/api/v1/oauth/confirm",
        { client_id: clientId, redirect_uri: redirectUri, state, code_challenge: codeChallenge, code_challenge_method: codeChallengeMethod },
        { headers: { Authorization: `Bearer ${token}` } }
      );
      window.location.href = res.data.redirect_url;
    } catch {
      setLoginError("Erro ao autorizar. Tente novamente.");
      setLoading(false);
    }
  };

  const handleDeny = () => {
    window.location.href = `${redirectUri}?error=access_denied&state=${encodeURIComponent(state)}`;
  };

  if (!paramsValid) {
    return (
      <div className="min-h-screen flex items-center justify-center p-4" style={{ background: "var(--theme-bg)" }}>
        <div className="rounded-2xl shadow-xl p-8 max-w-md w-full text-center" style={{ backgroundColor: "var(--theme-surface)" }}>
          <p style={{ color: "var(--theme-text-secondary)" }}>Link de autorização inválido ou incompleto.</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen flex items-center justify-center p-4" style={{ background: "linear-gradient(135deg, var(--theme-accent-light) 0%, var(--theme-bg) 100%)" }}>
      <div className="w-full max-w-md">
        <div className="rounded-2xl shadow-xl p-8" style={{ backgroundColor: "var(--theme-surface)" }}>
          {/* Header */}
          <div className="text-center mb-6">
            <div className="inline-flex items-center justify-center w-14 h-14 rounded-2xl mb-4" style={{ backgroundColor: "var(--theme-accent-light)" }}>
              <TrendingUp size={28} style={{ color: "var(--theme-accent)" }} />
            </div>
            <h1 className="text-xl font-bold mb-1" style={{ color: "var(--theme-text)" }}>
              Finance Control
            </h1>
            <p className="text-sm" style={{ color: "var(--theme-text-secondary)" }}>
              Autorização de acesso
            </p>
          </div>

          {!token || !user ? (
            <>
              {/* Login form */}
              <div className="mb-6 p-4 rounded-xl" style={{ backgroundColor: "var(--theme-bg)", border: "1px solid var(--theme-border)" }}>
                <div className="flex items-center gap-2 mb-2">
                  <ShieldCheck size={16} style={{ color: "var(--theme-accent)" }} />
                  <span className="text-sm font-medium" style={{ color: "var(--theme-text)" }}>
                    Entre para continuar
                  </span>
                </div>
                <p className="text-xs" style={{ color: "var(--theme-text-secondary)" }}>
                  Um cliente externo quer acessar seus dados financeiros. Faça login para revisar e autorizar.
                </p>
              </div>

              <form onSubmit={handleSubmit(handleLogin)} className="space-y-4">
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
                  placeholder="••••••••"
                  error={errors.password?.message}
                  {...register("password", { required: "Senha obrigatória" })}
                />
                {loginError && (
                  <p className="text-sm text-red-500">{loginError}</p>
                )}
                <Button type="submit" className="w-full" disabled={loading}>
                  {loading ? "Entrando..." : "Entrar"}
                </Button>
              </form>
            </>
          ) : (
            <>
              {/* Consent screen */}
              <div className="mb-6 p-4 rounded-xl" style={{ backgroundColor: "var(--theme-bg)", border: "1px solid var(--theme-border)" }}>
                <div className="flex items-center gap-2 mb-3">
                  <ShieldCheck size={16} style={{ color: "var(--theme-accent)" }} />
                  <span className="text-sm font-medium" style={{ color: "var(--theme-text)" }}>
                    Olá, {user.name}
                  </span>
                </div>
                <p className="text-sm mb-3" style={{ color: "var(--theme-text)" }}>
                  Um cliente externo quer acessar sua conta com as seguintes permissões:
                </p>
                <ul className="text-sm space-y-1" style={{ color: "var(--theme-text-secondary)" }}>
                  <li>• Ver saldo e contas</li>
                  <li>• Listar transações</li>
                  <li>• Acessar relatórios e resumos mensais</li>
                  <li>• Ver categorias e recorrentes</li>
                </ul>
                <p className="text-xs mt-3" style={{ color: "var(--theme-text-secondary)" }}>
                  O acesso é somente leitura. Nenhuma transação será criada ou modificada.
                </p>
              </div>

              {loginError && (
                <p className="text-sm text-red-500 mb-4">{loginError}</p>
              )}

              <div className="flex gap-3">
                <Button
                  type="button"
                  variant="secondary"
                  className="flex-1"
                  onClick={handleDeny}
                  disabled={loading}
                >
                  Negar
                </Button>
                <Button
                  type="button"
                  className="flex-1"
                  onClick={handleAuthorize}
                  disabled={loading}
                >
                  {loading ? "Autorizando..." : "Autorizar"}
                </Button>
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
}
