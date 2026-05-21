import { useRef, useState } from "react";
import { Link, useNavigate, useSearchParams } from "react-router-dom";
import { useForm } from "react-hook-form";
import { TrendingUp } from "lucide-react";
import { useResetPassword } from "@/hooks/useApi";
import Button from "@/components/ui/Button";
import Input from "@/components/ui/Input";

interface FormData {
  new_password: string;
  confirm_password: string;
}

export default function ResetPassword() {
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const email = searchParams.get("email") ?? "";
  const resetPassword = useResetPassword();

  const [digits, setDigits] = useState<string[]>(Array(6).fill(""));
  const [codeError, setCodeError] = useState("");
  const [error, setError] = useState("");
  const [success, setSuccess] = useState(false);
  const inputRefs = useRef<(HTMLInputElement | null)[]>([]);

  const { register, handleSubmit, watch, formState: { errors } } = useForm<FormData>();

  const handleDigitChange = (index: number, value: string) => {
    if (!/^\d?$/.test(value)) return;
    const next = [...digits];
    next[index] = value.slice(-1);
    setDigits(next);
    setCodeError("");
    if (value && index < 5) inputRefs.current[index + 1]?.focus();
  };

  const handleKeyDown = (index: number, e: React.KeyboardEvent) => {
    if (e.key === "Backspace" && !digits[index] && index > 0) {
      inputRefs.current[index - 1]?.focus();
    }
  };

  const handlePaste = (e: React.ClipboardEvent) => {
    const pasted = e.clipboardData.getData("text").replace(/\D/g, "").slice(0, 6);
    if (!pasted) return;
    e.preventDefault();
    const next = pasted.split("").concat(Array(6).fill("")).slice(0, 6);
    setDigits(next);
    inputRefs.current[Math.min(pasted.length, 5)]?.focus();
  };

  const code = digits.join("");

  const onSubmit = async (data: FormData) => {
    if (code.length < 6) { setCodeError("Digite os 6 dígitos do código"); return; }
    setError("");
    try {
      await resetPassword.mutateAsync({ email, code, new_password: data.new_password });
      setSuccess(true);
    } catch (e: unknown) {
      const detail = (e as { response?: { data?: { detail?: string } } })?.response?.data?.detail;
      if (detail === "Código inválido ou expirado") {
        setCodeError(detail);
        setDigits(Array(6).fill(""));
        inputRefs.current[0]?.focus();
      } else {
        setError(detail || "Erro ao redefinir senha");
      }
    }
  };

  if (success) {
    return (
      <div className="min-h-screen flex items-center justify-center p-4" style={{ background: "linear-gradient(135deg, var(--theme-accent-light) 0%, var(--theme-bg) 100%)" }}>
        <div className="w-full max-w-md">
          <div className="rounded-2xl shadow-xl p-8 text-center" style={{ backgroundColor: "var(--theme-surface)" }}>
            <div className="w-12 h-12 bg-green-100 rounded-xl flex items-center justify-center mx-auto mb-4">
              <span className="text-2xl">✅</span>
            </div>
            <h2 className="text-xl font-bold text-gray-900 mb-2">Senha redefinida!</h2>
            <p className="text-sm text-gray-500 mb-6">Sua senha foi alterada com sucesso.</p>
            <Button className="w-full" size="lg" onClick={() => navigate("/login")}>
              Ir para o login
            </Button>
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
            <h1 className="text-2xl font-bold text-gray-900">Nova senha</h1>
            <p className="text-sm text-gray-500 mt-1 text-center">
              Digite o código enviado para<br />
              <span className="font-medium text-gray-700">{email}</span>
            </p>
          </div>

          <form onSubmit={handleSubmit(onSubmit)} className="space-y-5">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">Código de verificação</label>
              <div className="flex gap-2 justify-center" onPaste={handlePaste}>
                {digits.map((d, i) => (
                  <input
                    key={i}
                    ref={(el) => { inputRefs.current[i] = el; }}
                    type="text"
                    inputMode="numeric"
                    maxLength={1}
                    value={d}
                    onChange={(e) => handleDigitChange(i, e.target.value)}
                    onKeyDown={(e) => handleKeyDown(i, e)}
                    className="w-11 h-14 text-center text-xl font-bold rounded-lg border-2 focus:outline-none focus:border-primary-500 transition-colors"
                    style={{
                      borderColor: codeError ? "rgb(220 38 38)" : d ? "var(--theme-accent)" : "var(--theme-border)",
                      backgroundColor: "var(--theme-bg)",
                      color: "var(--theme-text)",
                    }}
                  />
                ))}
              </div>
              {codeError && (
                <p className="mt-1 text-xs text-red-600">{codeError}</p>
              )}
            </div>

            <Input
              label="Nova senha"
              type="password"
              placeholder="Mínimo 6 caracteres"
              error={errors.new_password?.message}
              {...register("new_password", {
                required: "Nova senha obrigatória",
                minLength: { value: 6, message: "Mínimo 6 caracteres" },
              })}
            />
            <Input
              label="Confirmar nova senha"
              type="password"
              placeholder="Repita a senha"
              error={errors.confirm_password?.message}
              {...register("confirm_password", {
                required: "Confirmação obrigatória",
                validate: (v) => v === watch("new_password") || "As senhas não coincidem",
              })}
            />

            {error && (
              <p className="text-sm text-red-600 bg-red-50 px-3 py-2 rounded-lg">{error}</p>
            )}

            <Button type="submit" className="w-full" size="lg" loading={resetPassword.isPending}>
              Redefinir senha
            </Button>
          </form>

          <p className="mt-6 text-center text-sm text-gray-600">
            <Link to="/forgot-password" className="text-primary-600 font-medium hover:underline">
              Solicitar novo código
            </Link>
          </p>
        </div>
      </div>
    </div>
  );
}
