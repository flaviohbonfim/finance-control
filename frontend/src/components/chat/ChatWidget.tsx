import { useEffect, useRef, useState } from "react";
import {
  MessageCircle, X, Send, Loader2, Bot, User,
  Maximize2, Minimize2, Copy, Check, ChevronLeft, ChevronRight,
} from "lucide-react";
import ReactMarkdown from "react-markdown";
import { useQueryClient } from "@tanstack/react-query";
import { useAuthStore } from "@/store/auth";

interface Message {
  id: string;
  role: "user" | "assistant";
  content: string;
  loading?: boolean;
}

interface HistoryItem {
  role: "user" | "model";
  content: string;
}

const BASE_URL = "/api/v1";

function CopyButton({ text }: { text: string }) {
  const [copied, setCopied] = useState(false);
  const copy = () => {
    navigator.clipboard.writeText(text).then(() => {
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    });
  };
  return (
    <button
      onClick={copy}
      className="opacity-0 group-hover:opacity-100 transition-opacity p-1 rounded hover:bg-gray-200 dark:hover:bg-gray-600 text-gray-400 hover:text-gray-600 dark:hover:text-gray-300"
      title="Copiar resposta"
    >
      {copied ? <Check size={13} /> : <Copy size={13} />}
    </button>
  );
}

function MarkdownMessage({ content }: { content: string }) {
  return (
    <ReactMarkdown
      components={{
        p: ({ children }) => <p className="mb-1 last:mb-0">{children}</p>,
        strong: ({ children }) => <strong className="font-semibold">{children}</strong>,
        em: ({ children }) => <em className="italic">{children}</em>,
        ul: ({ children }) => <ul className="list-disc list-inside space-y-0.5 my-1">{children}</ul>,
        ol: ({ children }) => <ol className="list-decimal list-inside space-y-0.5 my-1">{children}</ol>,
        li: ({ children }) => <li className="leading-snug">{children}</li>,
        code: ({ children }) => (
          <code className="bg-black/10 dark:bg-white/10 rounded px-1 py-0.5 text-xs font-mono">
            {children}
          </code>
        ),
        h1: ({ children }) => <p className="font-bold text-base mb-1">{children}</p>,
        h2: ({ children }) => <p className="font-semibold mb-1">{children}</p>,
        h3: ({ children }) => <p className="font-semibold mb-0.5">{children}</p>,
      }}
    >
      {content}
    </ReactMarkdown>
  );
}

export default function ChatWidget() {
  const [open, setOpen] = useState(false);
  const [expanded, setExpanded] = useState(false);
  const [minimized, setMinimized] = useState(
    () => localStorage.getItem("chat-minimized") === "true"
  );

  const setMin = (v: boolean) => {
    setMinimized(v);
    localStorage.setItem("chat-minimized", String(v));
    if (v) setOpen(false);
  };
  const [input, setInput] = useState("");
  const [messages, setMessages] = useState<Message[]>([]);
  const [streaming, setStreaming] = useState(false);
  const [toolHint, setToolHint] = useState<string | null>(null);
  const queryClient = useQueryClient();
  const bottomRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLTextAreaElement>(null);
  const { token } = useAuthStore();

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages, toolHint]);

  useEffect(() => {
    if (open) setTimeout(() => inputRef.current?.focus(), 100);
  }, [open]);

  const historyFromMessages = (msgs: Message[]): HistoryItem[] =>
    msgs
      .filter((m) => !m.loading && m.content)
      .map((m) => ({ role: m.role === "user" ? "user" : "model", content: m.content }));

  const sendMessage = async () => {
    const text = input.trim();
    if (!text || streaming) return;

    const userMsg: Message = { id: crypto.randomUUID(), role: "user", content: text };
    const assistantId = crypto.randomUUID();
    const assistantMsg: Message = { id: assistantId, role: "assistant", content: "", loading: true };

    setMessages((prev) => [...prev, userMsg, assistantMsg]);
    setInput("");
    setStreaming(true);
    setToolHint(null);

    // Reset textarea height
    if (inputRef.current) {
      inputRef.current.style.height = "auto";
    }

    try {
      const history = historyFromMessages(messages);
      const res = await fetch(`${BASE_URL}/ai/chat`, {
        method: "POST",
        headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
        body: JSON.stringify({ message: text, history }),
      });

      if (!res.ok || !res.body) throw new Error(`HTTP ${res.status}`);

      const reader = res.body.getReader();
      const decoder = new TextDecoder();
      let buffer = "";
      let fullText = "";
      let currentEvent = "";

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        buffer += decoder.decode(value, { stream: true });
        const lines = buffer.split("\n");
        buffer = lines.pop() ?? "";

        for (const line of lines) {
          if (line.startsWith("event: ")) {
            currentEvent = line.slice(7).trim();
          } else if (line.startsWith("data: ")) {
            const data = line.slice(6);
            let sseError: string | null = null;
            try {
              const parsed = JSON.parse(data);
              if (currentEvent === "delta" && parsed.text) {
                fullText += parsed.text;
                setMessages((prev) =>
                  prev.map((m) =>
                    m.id === assistantId ? { ...m, content: fullText, loading: false } : m
                  )
                );
                setToolHint(null);
              } else if (currentEvent === "status" && parsed.text) {
                setToolHint(parsed.text);
              } else if (currentEvent === "tool_call" && parsed.name) {
                const hints: Record<string, string> = {
                  get_accounts: "consultando contas...",
                  get_dashboard: "consultando dashboard...",
                  get_transactions: "buscando transações...",
                  get_monthly_summary: "analisando resumo mensal...",
                  get_expense_by_category: "analisando despesas por categoria...",
                };
                setToolHint(hints[parsed.name] ?? "consultando dados...");
              } else if (currentEvent === "invalidate" && parsed.keys) {
                (parsed.keys as string[]).forEach((key) =>
                  queryClient.invalidateQueries({ queryKey: [key] })
                );
              } else if (currentEvent === "done") {
                setToolHint(null);
              } else if (currentEvent === "error") {
                sseError = parsed.detail ?? "Erro no servidor";
              }
            } catch {
              // skip malformed JSON
            }
            if (sseError) throw new Error(sseError);
            currentEvent = "";
          } else if (line === "") {
            currentEvent = "";
          }
        }
      }

      setMessages((prev) =>
        prev.map((m) =>
          m.id === assistantId
            ? { ...m, loading: false, content: fullText || "Não consegui gerar uma resposta." }
            : m
        )
      );
    } catch (err) {
      const detail = err instanceof Error ? err.message : "Tente novamente.";
      setMessages((prev) =>
        prev.map((m) =>
          m.id === assistantId
            ? { ...m, loading: false, content: `⚠️ ${detail}` }
            : m
        )
      );
    } finally {
      setStreaming(false);
      setToolHint(null);
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      sendMessage();
    }
  };

  const panelW = expanded ? "w-[600px]" : "w-[360px]";
  const panelH = expanded ? "h-[700px]" : "h-[520px]";

  if (minimized) {
    return (
      <button
        onClick={() => setMin(false)}
        className="fixed right-0 bottom-24 z-50 bg-primary-600 hover:bg-primary-700 text-white rounded-l-xl shadow-lg flex flex-col items-center justify-center gap-1.5 py-4 px-2 transition-colors"
        aria-label="Mostrar assistente"
        title="Mostrar assistente"
      >
        <MessageCircle size={15} />
        <ChevronLeft size={13} />
      </button>
    );
  }

  return (
    <>
      {/* Floating button + hide control */}
      <div className="fixed bottom-6 right-6 z-50 flex flex-col items-end gap-2">
        {!open && (
          <button
            onClick={() => setMin(true)}
            className="w-7 h-7 rounded-full bg-gray-200 dark:bg-gray-700 hover:bg-gray-300 dark:hover:bg-gray-600 text-gray-500 dark:text-gray-300 flex items-center justify-center shadow transition-colors"
            title="Ocultar assistente"
            aria-label="Ocultar assistente"
          >
            <ChevronRight size={14} />
          </button>
        )}
        <button
          onClick={() => setOpen((o) => !o)}
          className="w-14 h-14 rounded-full bg-primary-600 hover:bg-primary-700 text-white shadow-lg flex items-center justify-center transition-all"
          aria-label="Abrir assistente financeiro"
        >
          {open ? <X size={22} /> : <MessageCircle size={22} />}
        </button>
      </div>

      {/* Chat panel */}
      {open && (
        <div
          className={`fixed bottom-24 right-6 z-50 ${panelW} max-w-[calc(100vw-24px)] ${panelH} max-h-[calc(100vh-120px)] bg-white dark:bg-gray-900 rounded-2xl shadow-2xl border border-gray-200 dark:border-gray-700 flex flex-col overflow-hidden transition-all duration-200`}
        >
          {/* Header */}
          <div className="flex items-center gap-3 px-4 py-3 border-b border-gray-100 dark:border-gray-700 bg-primary-600 text-white rounded-t-2xl">
            <Bot size={20} className="flex-shrink-0" />
            <div className="flex-1 min-w-0">
              <p className="text-sm font-semibold">Assistente Financeiro</p>
              <p className="text-xs text-primary-200">Powered by Gemini</p>
            </div>
            <button
              onClick={() => setExpanded((e) => !e)}
              className="hidden sm:block p-1 rounded hover:bg-primary-500 transition-colors"
              title={expanded ? "Diminuir" : "Expandir"}
            >
              {expanded ? <Minimize2 size={16} /> : <Maximize2 size={16} />}
            </button>
            <button
              onClick={() => setOpen(false)}
              className="p-1 rounded hover:bg-primary-500 transition-colors"
              title="Fechar"
            >
              <X size={16} />
            </button>
          </div>

          {/* Messages */}
          <div className="flex-1 overflow-y-auto px-4 py-3 space-y-3">
            {messages.length === 0 && (
              <div className="text-center text-gray-400 text-sm mt-8">
                <Bot size={32} className="mx-auto mb-2 text-primary-300" />
                <p>Olá! Sou seu assistente financeiro.</p>
                <p className="mt-1 text-xs">Pergunte sobre saldo, despesas, receitas ou qualquer dado financeiro.</p>
              </div>
            )}

            {messages.map((msg) => (
              <div
                key={msg.id}
                className={`flex gap-2 group ${msg.role === "user" ? "flex-row-reverse" : "flex-row"}`}
              >
                <div
                  className={`w-7 h-7 rounded-full flex items-center justify-center flex-shrink-0 mt-0.5 ${
                    msg.role === "user"
                      ? "bg-primary-100 text-primary-600"
                      : "bg-gray-100 dark:bg-gray-700 text-gray-500"
                  }`}
                >
                  {msg.role === "user" ? <User size={14} /> : <Bot size={14} />}
                </div>

                <div className={`max-w-[82%] flex flex-col gap-1 ${msg.role === "user" ? "items-end" : "items-start"}`}>
                  <div
                    className={`px-3 py-2 rounded-2xl text-sm leading-relaxed ${
                      msg.role === "user"
                        ? "bg-primary-600 text-white rounded-tr-sm"
                        : "bg-gray-100 dark:bg-gray-800 text-gray-800 dark:text-gray-200 rounded-tl-sm"
                    }`}
                  >
                    {msg.loading && !msg.content ? (
                      <Loader2 size={14} className="animate-spin" />
                    ) : msg.role === "assistant" ? (
                      <MarkdownMessage content={msg.content} />
                    ) : (
                      <span className="whitespace-pre-wrap">{msg.content}</span>
                    )}
                  </div>

                  {/* Copy button for assistant messages */}
                  {msg.role === "assistant" && !msg.loading && msg.content && (
                    <div className="flex items-center gap-1">
                      <CopyButton text={msg.content} />
                    </div>
                  )}
                </div>
              </div>
            ))}

            {toolHint && (
              <div className="flex gap-2 items-center text-xs text-gray-400 px-1">
                <Loader2 size={12} className="animate-spin flex-shrink-0" />
                <span>{toolHint}</span>
              </div>
            )}

            <div ref={bottomRef} />
          </div>

          {/* Input */}
          <div className="px-3 py-3 border-t border-gray-100 dark:border-gray-700">
            <div className="flex gap-2 items-end">
              <textarea
                ref={inputRef}
                value={input}
                onChange={(e) => setInput(e.target.value)}
                onKeyDown={handleKeyDown}
                placeholder="Pergunte algo sobre suas finanças..."
                rows={1}
                disabled={streaming}
                className="flex-1 resize-none rounded-xl border border-gray-200 dark:border-gray-600 bg-gray-50 dark:bg-gray-800 text-sm text-gray-900 dark:text-white px-3 py-2 focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-primary-500 disabled:opacity-50 max-h-24 overflow-y-auto"
                style={{ lineHeight: "1.4" }}
                onInput={(e) => {
                  const el = e.currentTarget;
                  el.style.height = "auto";
                  el.style.height = Math.min(el.scrollHeight, 96) + "px";
                }}
              />
              <button
                onClick={sendMessage}
                disabled={streaming || !input.trim()}
                className="w-9 h-9 rounded-xl bg-primary-600 hover:bg-primary-700 disabled:opacity-40 text-white flex items-center justify-center flex-shrink-0 transition-colors"
              >
                {streaming ? <Loader2 size={16} className="animate-spin" /> : <Send size={16} />}
              </button>
            </div>
            <p className="text-xs text-gray-400 mt-1.5 text-center">
              Enter para enviar · Shift+Enter para nova linha
            </p>
          </div>
        </div>
      )}
    </>
  );
}
