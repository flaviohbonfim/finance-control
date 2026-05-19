import { Tag } from "lucide-react";
import { themes, getTheme } from "@/themes";
import { useThemeStore } from "@/store/theme";
import Card from "@/components/ui/Card";

const APP_VERSION = import.meta.env.VITE_APP_VERSION ?? "0.14.1";

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

const CHANGELOG: { version: string; date: string; changes: string[] }[] = [
  {
    version: "0.14.1",
    date: "2026-05-19",
    changes: [
      "Assistente financeiro com IA: criar e deletar transações por chat",
      "Lançamento de recorrentes via assistente",
      "Invalidação automática de cache após operações de escrita",
      "Novos ícones de categoria: pets, saúde, lazer, combustível e mais",
      "Página de perfil separada acessível pela sidebar",
      "Versão e changelog visíveis nas configurações",
    ],
  },
];

function VersionSection() {
  return (
    <Card>
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-sm font-semibold text-gray-900">Versão do app</h2>
        <span className="inline-flex items-center gap-1.5 text-xs font-mono bg-primary-50 text-primary-700 px-2.5 py-1 rounded-full border border-primary-200">
          <Tag size={11} />
          v{APP_VERSION}
        </span>
      </div>

      <div className="space-y-5">
        {CHANGELOG.map((release) => (
          <div key={release.version}>
            <div className="flex items-center gap-2 mb-2">
              <span className="text-xs font-semibold text-gray-700">v{release.version}</span>
              <span className="text-xs text-gray-400">{release.date}</span>
            </div>
            <ul className="space-y-1">
              {release.changes.map((change, i) => (
                <li key={i} className="flex items-start gap-2 text-xs text-gray-600">
                  <span className="mt-1.5 w-1 h-1 rounded-full bg-primary-400 flex-shrink-0" />
                  {change}
                </li>
              ))}
            </ul>
          </div>
        ))}
      </div>
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
