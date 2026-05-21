import { useEffect, useRef, useState } from "react";
import { useNavigate } from "react-router-dom";
import { TrendingUp } from "lucide-react";
import { useVerifyEmail, useResendVerification } from "@/hooks/useApi";
import { useAuthStore } from "@/store/auth";
import Button from "@/components/ui/Button";

const RESEND_COOLDOWN = 60;

export default function VerifyEmail() {
  const navigate = useNavigate();
  const { user, token, updateUser } = useAuthStore();
  const verifyEmail = useVerifyEmail();
  const resendVerification = useResendVerification();

  const [digits, setDigits] = useState<string[]>(Array(6).fill(""));
  const [error, setError] = useState("");
  const [resendCooldown, setResendCooldown] = useState(0);
  const [resendSuccess, setResendSuccess] = useState(false);
  const inputRefs = useRef<(HTMLInputElement | null)[]>([]);

  useEffect(() => {
    if (!token) { navigate("/login"); return; }
    if (user?.is_verified) { navigate("/"); return; }
    inputRefs.current[0]?.focus();
  }, [token, user, navigate]);

  useEffect(() => {
    if (resendCooldown <= 0) return;
    const t = setTimeout(() => setResendCooldown((c) => c - 1), 1000);
    return () => clearTimeout(t);
  }, [resendCooldown]);

  const handleChange = (index: number, value: string) => {
    if (!/^\d?$/.test(value)) return;
    const next = [...digits];
    next[index] = value.slice(-1);
    setDigits(next);
    setError("");
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

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (code.length < 6) { setError("Digite os 6 dígitos do código"); return; }
    setError("");
    try {
      await verifyEmail.mutateAsync({ code });
      if (user) updateUser({ ...user, is_verified: true });
      navigate("/");
    } catch {
      setError("Código inválido ou expirado");
      setDigits(Array(6).fill(""));
      inputRefs.current[0]?.focus();
    }
  };

  const handleResend = async () => {
    if (!user?.email || resendCooldown > 0) return;
    setResendSuccess(false);
    try {
      await resendVerification.mutateAsync({ email: user.email });
      setResendCooldown(RESEND_COOLDOWN);
      setResendSuccess(true);
    } catch {
      // API always returns 204 — only network errors reach here
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
            <h1 className="text-2xl font-bold text-gray-900">Verifique seu email</h1>
            <p className="text-sm text-gray-500 mt-1 text-center">
              Enviamos um código de 6 dígitos para<br />
              <span className="font-medium text-gray-700">{user?.email}</span>
            </p>
          </div>

          <form onSubmit={handleSubmit} className="space-y-6">
            <div className="flex gap-2 justify-center" onPaste={handlePaste}>
              {digits.map((d, i) => (
                <input
                  key={i}
                  ref={(el) => { inputRefs.current[i] = el; }}
                  type="text"
                  inputMode="numeric"
                  maxLength={1}
                  value={d}
                  onChange={(e) => handleChange(i, e.target.value)}
                  onKeyDown={(e) => handleKeyDown(i, e)}
                  className="w-11 h-14 text-center text-xl font-bold rounded-lg border-2 focus:outline-none focus:border-primary-500 transition-colors"
                  style={{
                    borderColor: error ? "rgb(220 38 38)" : d ? "var(--theme-accent)" : "var(--theme-border)",
                    backgroundColor: "var(--theme-bg)",
                    color: "var(--theme-text)",
                  }}
                />
              ))}
            </div>

            {error && (
              <p className="text-sm text-red-600 bg-red-50 px-3 py-2 rounded-lg text-center">{error}</p>
            )}

            {resendSuccess && (
              <p className="text-sm text-green-600 bg-green-50 px-3 py-2 rounded-lg text-center">
                Novo código enviado!
              </p>
            )}

            <Button type="submit" className="w-full" size="lg" loading={verifyEmail.isPending} disabled={code.length < 6}>
              Verificar email
            </Button>
          </form>

          <div className="mt-4 text-center">
            <span className="text-sm text-gray-500">Não recebeu o código? </span>
            {resendCooldown > 0 ? (
              <span className="text-sm text-gray-400">Reenviar em {resendCooldown}s</span>
            ) : (
              <button
                type="button"
                onClick={handleResend}
                disabled={resendVerification.isPending}
                className="text-sm text-primary-600 font-medium hover:underline disabled:opacity-50"
              >
                Reenviar
              </button>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
