import { useEffect, useState } from "react";
import { Tag, Loader2 } from "lucide-react";
import ReactMarkdown from "react-markdown";
import { themes, getTheme } from "@/themes";
import { useThemeStore } from "@/store/theme";
import Card from "@/components/ui/Card";

const APP_VERSION = import.meta.env.VITE_APP_VERSION ?? "0.14.1";
const GITHUB_REPO = import.meta.env.VITE_GITHUB_REPO ?? "";

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

function VersionSection() {
  const [notes, setNotes] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!GITHUB_REPO || APP_VERSION === "dev") return;
    setLoading(true);
    fetch(`https://api.github.com/repos/${GITHUB_REPO}/releases/tags/v${APP_VERSION}`)
      .then((r) => (r.ok ? r.json() : null))
      .then((data) => setNotes(data?.body ?? null))
      .catch(() => {})
      .finally(() => setLoading(false));
  }, []);

  return (
    <Card>
      <div className="flex items-center justify-between mb-3">
        <h2 className="text-sm font-semibold text-gray-900">Versão do app</h2>
        <span className="inline-flex items-center gap-1.5 text-xs font-mono bg-primary-50 text-primary-700 px-2.5 py-1 rounded-full border border-primary-200">
          <Tag size={11} />
          v{APP_VERSION}
        </span>
      </div>

      {loading && (
        <div className="flex items-center gap-2 text-xs text-gray-400 mt-1">
          <Loader2 size={12} className="animate-spin" />
          Carregando notas da versão...
        </div>
      )}

      {notes && (
        <div className="mt-1 text-xs text-gray-600 prose-xs prose-ul:my-1 prose-li:my-0">
          <ReactMarkdown
            components={{
              h2: ({ children }) => (
                <p className="font-semibold text-gray-800 mb-2">{children}</p>
              ),
              ul: ({ children }) => (
                <ul className="space-y-1 list-none p-0">{children}</ul>
              ),
              li: ({ children }) => (
                <li className="flex items-start gap-2">
                  <span className="mt-1.5 w-1 h-1 rounded-full bg-primary-400 flex-shrink-0" />
                  <span>{children}</span>
                </li>
              ),
              a: ({ href, children }) => (
                <a href={href} target="_blank" rel="noreferrer" className="text-primary-600 hover:underline font-mono">
                  {children}
                </a>
              ),
            }}
          >
            {notes}
          </ReactMarkdown>
        </div>
      )}
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
        <p className="text-sm text-gray-500 mt-0.5">Personalize a aparência do app</p>
      </div>

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

      <VersionSection />
    </div>
  );
}
