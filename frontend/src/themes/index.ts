export interface ThemeColors {
  bg: string;
  surface: string;
  surface2: string;
  border: string;
  text1: string;
  text2: string;
  text3: string;
  accent: string;
  accentHover: string;
  accentLight: string;
  accentFg: string;
  income: string;
  incomeLight: string;
  expense: string;
  expenseLight: string;
  sidebar: string;
  inputBg: string;
}

export interface Theme {
  id: string;
  name: string;
  isDark: boolean;
  emoji: string;
  colors: ThemeColors;
}

export const themes: Theme[] = [
  {
    id: "light",
    name: "Claro",
    isDark: false,
    emoji: "☀️",
    colors: {
      bg: "#f9fafb",
      surface: "#ffffff",
      surface2: "#f3f4f6",
      border: "#e5e7eb",
      text1: "#111827",
      text2: "#4b5563",
      text3: "#9ca3af",
      accent: "#6366f1",
      accentHover: "#4f46e5",
      accentLight: "#eef2ff",
      accentFg: "#ffffff",
      income: "#16a34a",
      incomeLight: "#dcfce7",
      expense: "#dc2626",
      expenseLight: "#fee2e2",
      sidebar: "#ffffff",
      inputBg: "#ffffff",
    },
  },
  {
    id: "dark",
    name: "Escuro",
    isDark: true,
    emoji: "🌙",
    colors: {
      bg: "#0f172a",
      surface: "#1e293b",
      surface2: "#334155",
      border: "#334155",
      text1: "#f1f5f9",
      text2: "#94a3b8",
      text3: "#475569",
      accent: "#818cf8",
      accentHover: "#6366f1",
      accentLight: "#1e1b4b",
      accentFg: "#ffffff",
      income: "#4ade80",
      incomeLight: "#052e16",
      expense: "#f87171",
      expenseLight: "#450a0a",
      sidebar: "#0f172a",
      inputBg: "#1e293b",
    },
  },
  {
    id: "dracula",
    name: "Dracula",
    isDark: true,
    emoji: "🧛",
    colors: {
      bg: "#1e1f29",
      surface: "#282a36",
      surface2: "#44475a",
      border: "#44475a",
      text1: "#f8f8f2",
      text2: "#6272a4",
      text3: "#44475a",
      accent: "#bd93f9",
      accentHover: "#a97ff7",
      accentLight: "#44475a",
      accentFg: "#282a36",
      income: "#50fa7b",
      incomeLight: "#1a3a20",
      expense: "#ff5555",
      expenseLight: "#3a1414",
      sidebar: "#21222c",
      inputBg: "#282a36",
    },
  },
  {
    id: "nord",
    name: "Nord",
    isDark: true,
    emoji: "❄️",
    colors: {
      bg: "#2e3440",
      surface: "#3b4252",
      surface2: "#434c5e",
      border: "#4c566a",
      text1: "#eceff4",
      text2: "#d8dee9",
      text3: "#4c566a",
      accent: "#88c0d0",
      accentHover: "#72afc2",
      accentLight: "#3b4252",
      accentFg: "#2e3440",
      income: "#a3be8c",
      incomeLight: "#2a3826",
      expense: "#bf616a",
      expenseLight: "#3a1f22",
      sidebar: "#2e3440",
      inputBg: "#3b4252",
    },
  },
  {
    id: "catppuccin",
    name: "Catppuccin",
    isDark: true,
    emoji: "🐱",
    colors: {
      bg: "#1e1e2e",
      surface: "#313244",
      surface2: "#45475a",
      border: "#45475a",
      text1: "#cdd6f4",
      text2: "#a6adc8",
      text3: "#585b70",
      accent: "#cba6f7",
      accentHover: "#b993f4",
      accentLight: "#45475a",
      accentFg: "#1e1e2e",
      income: "#a6e3a1",
      incomeLight: "#1f3a1e",
      expense: "#f38ba8",
      expenseLight: "#3a1a22",
      sidebar: "#181825",
      inputBg: "#313244",
    },
  },
  {
    id: "tokyo-night",
    name: "Tokyo Night",
    isDark: true,
    emoji: "🗼",
    colors: {
      bg: "#1a1b2e",
      surface: "#24283b",
      surface2: "#292e42",
      border: "#3b4261",
      text1: "#c0caf5",
      text2: "#9aa5ce",
      text3: "#3b4261",
      accent: "#7aa2f7",
      accentHover: "#6990e5",
      accentLight: "#292e42",
      accentFg: "#1a1b2e",
      income: "#9ece6a",
      incomeLight: "#203321",
      expense: "#f7768e",
      expenseLight: "#3d1524",
      sidebar: "#1a1b2e",
      inputBg: "#24283b",
    },
  },
  {
    id: "rose-pine",
    name: "Rosé Pine",
    isDark: true,
    emoji: "🌹",
    colors: {
      bg: "#191724",
      surface: "#1f1d2e",
      surface2: "#26233a",
      border: "#26233a",
      text1: "#e0def4",
      text2: "#908caa",
      text3: "#393552",
      accent: "#c4a7e7",
      accentHover: "#b697e0",
      accentLight: "#26233a",
      accentFg: "#191724",
      income: "#9ccfd8",
      incomeLight: "#1a2e30",
      expense: "#eb6f92",
      expenseLight: "#3a1424",
      sidebar: "#191724",
      inputBg: "#1f1d2e",
    },
  },
  {
    id: "monokai",
    name: "Monokai",
    isDark: true,
    emoji: "🎨",
    colors: {
      bg: "#272822",
      surface: "#3e3d32",
      surface2: "#49483e",
      border: "#49483e",
      text1: "#f8f8f2",
      text2: "#75715e",
      text3: "#49483e",
      accent: "#e6db74",
      accentHover: "#d4c660",
      accentLight: "#49483e",
      accentFg: "#272822",
      income: "#a6e22e",
      incomeLight: "#1e2e0a",
      expense: "#f92672",
      expenseLight: "#3a0a1a",
      sidebar: "#1e1f1c",
      inputBg: "#3e3d32",
    },
  },
  {
    id: "solarized",
    name: "Solarized",
    isDark: true,
    emoji: "🌞",
    colors: {
      bg: "#002b36",
      surface: "#073642",
      surface2: "#094552",
      border: "#0d3d4b",
      text1: "#eee8d5",
      text2: "#93a1a1",
      text3: "#586e75",
      accent: "#268bd2",
      accentHover: "#1a7bbf",
      accentLight: "#094552",
      accentFg: "#fdf6e3",
      income: "#859900",
      incomeLight: "#1a2000",
      expense: "#dc322f",
      expenseLight: "#300a0a",
      sidebar: "#002b36",
      inputBg: "#073642",
    },
  },
];

export const defaultTheme = themes[0];

export function getTheme(id: string): Theme {
  return themes.find((t) => t.id === id) ?? defaultTheme;
}
