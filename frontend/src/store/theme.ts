import { create } from "zustand";
import { persist } from "zustand/middleware";
import { getTheme, type Theme } from "@/themes";

interface ThemeState {
  themeId: string;
  customAccent: string | null;
  setTheme: (id: string) => void;
  setCustomAccent: (color: string | null) => void;
  applyTheme: (theme?: Theme, customAccent?: string | null) => void;
}

function applyVars(theme: Theme, customAccent?: string | null) {
  const c = theme.colors;
  const accent = customAccent || c.accent;
  const root = document.documentElement;
  root.setAttribute("data-theme", theme.id);

  const vars: Record<string, string> = {
    "--theme-bg": c.bg,
    "--theme-surface": c.surface,
    "--theme-surface2": c.surface2,
    "--theme-border": c.border,
    "--theme-text1": c.text1,
    "--theme-text2": c.text2,
    "--theme-text3": c.text3,
    "--theme-accent": accent,
    "--theme-accent-hover": c.accentHover,
    "--theme-accent-light": c.accentLight,
    "--theme-accent-fg": c.accentFg,
    "--theme-income": c.income,
    "--theme-income-light": c.incomeLight,
    "--theme-expense": c.expense,
    "--theme-expense-light": c.expenseLight,
    "--theme-sidebar": c.sidebar,
    "--theme-input-bg": c.inputBg,
  };
  Object.entries(vars).forEach(([k, v]) => root.style.setProperty(k, v));
}

export const useThemeStore = create<ThemeState>()(
  persist(
    (set, get) => ({
      themeId: "light",
      customAccent: null,
      setTheme: (id) => {
        const theme = getTheme(id);
        applyVars(theme, get().customAccent);
        set({ themeId: id });
      },
      setCustomAccent: (color) => {
        applyVars(getTheme(get().themeId), color);
        set({ customAccent: color });
      },
      applyTheme: (theme, customAccent) => {
        const t = theme ?? getTheme(get().themeId);
        const ca = customAccent !== undefined ? customAccent : get().customAccent;
        applyVars(t, ca);
      },
    }),
    { name: "finance-theme" }
  )
);
