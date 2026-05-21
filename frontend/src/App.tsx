import { useEffect } from "react";
import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import { useAuthStore } from "@/store/auth";
import { useThemeStore } from "@/store/theme";
import Layout from "@/components/layout/Layout";
import Login from "@/pages/Login";
import Register from "@/pages/Register";
import VerifyEmail from "@/pages/VerifyEmail";
import ForgotPassword from "@/pages/ForgotPassword";
import ResetPassword from "@/pages/ResetPassword";
import Dashboard from "@/pages/Dashboard";
import Accounts from "@/pages/Accounts";
import Categories from "@/pages/Categories";
import Recorrentes from "@/pages/Recorrentes";
import Transactions from "@/pages/Transactions";
import Reports from "@/pages/Reports";
import Settings from "@/pages/Settings";
import Profile from "@/pages/Profile";
import ChatWidget from "@/components/chat/ChatWidget";

function PrivateRoute({ children }: { children: React.ReactNode }) {
  const { token, user } = useAuthStore();
  if (!token) return <Navigate to="/login" replace />;
  if (user && !user.is_verified) return <Navigate to="/verify-email" replace />;
  return (
    <>
      {children}
      <ChatWidget />
    </>
  );
}

function PublicRoute({ children }: { children: React.ReactNode }) {
  const { token, user } = useAuthStore();
  if (token && user?.is_verified) return <Navigate to="/" replace />;
  return <>{children}</>;
}

export default function App() {
  const { applyTheme } = useThemeStore();

  useEffect(() => {
    applyTheme();
  }, [applyTheme]);

  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<PublicRoute><Login /></PublicRoute>} />
        <Route path="/register" element={<PublicRoute><Register /></PublicRoute>} />
        <Route path="/verify-email" element={<VerifyEmail />} />
        <Route path="/forgot-password" element={<PublicRoute><ForgotPassword /></PublicRoute>} />
        <Route path="/reset-password" element={<PublicRoute><ResetPassword /></PublicRoute>} />
        <Route
          path="/"
          element={<PrivateRoute><Layout /></PrivateRoute>}
        >
          <Route index element={<Dashboard />} />
          <Route path="transactions" element={<Transactions />} />
          <Route path="recurring" element={<Recorrentes />} />
          <Route path="accounts" element={<Accounts />} />
          <Route path="categories" element={<Categories />} />
          <Route path="reports" element={<Reports />} />
          <Route path="settings" element={<Settings />} />
          <Route path="profile" element={<Profile />} />
        </Route>
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  );
}
