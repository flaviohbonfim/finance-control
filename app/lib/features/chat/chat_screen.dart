import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown/markdown.dart' as md;

import '../../core/api/api_client.dart';
import '../../core/api/providers.dart';
import '../../core/theme/app_theme.dart';

// ── Markdown style ────────────────────────────────────────────────────────────

MarkdownStyleSheet _mdStyle(BuildContext context) => MarkdownStyleSheet(
      p: const TextStyle(fontSize: 14, height: 1.45),
      strong: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      em: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
      h1: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      h2: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      h3: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      listBullet: const TextStyle(fontSize: 14),
      code: TextStyle(
        fontSize: 13,
        fontFamily: 'monospace',
        backgroundColor: context.appBg,
        color: context.appPrimary,
      ),
      codeblockPadding: const EdgeInsets.all(12),
      codeblockDecoration: BoxDecoration(
        color: context.appBg,
        borderRadius: BorderRadius.circular(8),
      ),
      blockquotePadding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      blockquoteDecoration: BoxDecoration(
        border: Border(left: BorderSide(color: context.appPrimary, width: 3)),
      ),
      tableHead: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
      tableBody: const TextStyle(fontSize: 12),
      tableBorder: TableBorder.all(color: context.appBorder, width: 0.5),
      tableHeadAlign: TextAlign.left,
      tableCellsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      tableColumnWidth: const FlexColumnWidth(),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.appBorder)),
      ),
      blockSpacing: 8,
      listIndent: 16,
    );

// ── Message model ─────────────────────────────────────────────────────────────

class _Message {
  final String role; // 'user' | 'model'
  final String content;
  const _Message({required this.role, required this.content});
  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

// ── Screen ────────────────────────────────────────────────────────────────────

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messages = <_Message>[];
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  bool _isStreaming = false;
  String _streamingText = '';
  String _statusText = '';
  String? _error;
  String _sseAccumulator = '';

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Send ─────────────────────────────────────────────────────────────────────

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _isStreaming) return;
    _ctrl.clear();

    final history = _messages.map((m) => m.toJson()).toList();

    setState(() {
      _messages.add(_Message(role: 'user', content: text));
      _isStreaming = true;
      _streamingText = '';
      _statusText = '';
      _error = null;
      _sseAccumulator = '';
    });
    _scrollToBottom();

    try {
      final response = await api.dio.post(
        '/ai/chat',
        data: {'message': text, 'history': history},
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: Duration.zero,
        ),
      );

      final ResponseBody body = response.data;
      await for (final chunk in body.stream) {
        if (!mounted) break;
        _sseAccumulator += utf8.decode(chunk, allowMalformed: true);
        final parts = _sseAccumulator.split('\n\n');
        for (int i = 0; i < parts.length - 1; i++) {
          _parseEvent(parts[i]);
        }
        _sseAccumulator = parts.last;
      }
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message ?? 'Erro de conexão';
        _isStreaming = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Erro inesperado: $e';
        _isStreaming = false;
      });
    }
  }

  // ── SSE ───────────────────────────────────────────────────────────────────────

  void _parseEvent(String block) {
    String? eventType;
    String? data;
    for (final line in block.split('\n')) {
      if (line.startsWith('event: ')) {
        eventType = line.substring(7).trim();
      } else if (line.startsWith('data: ')) {
        data = line.substring(6).trim();
      }
    }
    if (eventType == null || data == null) return;
    try {
      _handleEvent(eventType, jsonDecode(data) as Map<String, dynamic>);
    } catch (_) {}
  }

  void _handleEvent(String type, Map<String, dynamic> json) {
    switch (type) {
      case 'status':
        setState(() => _statusText = json['text'] as String? ?? '');

      case 'delta':
        setState(() {
          _streamingText += json['text'] as String? ?? '';
          _statusText = '';
        });
        _scrollToBottom();

      case 'done':
        final full = json['text'] as String? ?? _streamingText;
        setState(() {
          if (full.isNotEmpty) {
            _messages.add(_Message(role: 'model', content: full));
          }
          _streamingText = '';
          _statusText = '';
          _isStreaming = false;
        });
        _scrollToBottom();

      case 'error':
        setState(() {
          _error = json['detail'] as String? ?? 'Erro desconhecido';
          _streamingText = '';
          _statusText = '';
          _isStreaming = false;
        });

      case 'invalidate':
        final keys = (json['keys'] as List?)?.cast<String>() ?? [];
        _invalidate(keys);
    }
  }

  void _invalidate(List<String> keys) {
    for (final k in keys) {
      switch (k) {
        case 'dashboard':
          ref.invalidate(dashboardProvider);
        case 'transactions':
          ref.invalidate(transactionsProvider);
        case 'accounts':
          ref.invalidate(accountsProvider);
        case 'recurring':
          ref.invalidate(recurringProvider);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearChat() => setState(() {
        _messages.clear();
        _streamingText = '';
        _statusText = '';
        _error = null;
        _isStreaming = false;
      });

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildBody()),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: context.appPrimary.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.smart_toy,
                  size: 20, color: context.appPrimary),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Assistente IA',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                Text('Pergunte sobre suas finanças',
                    style:
                        TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              ],
            ),
            const Spacer(),
            if (_messages.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 20, color: AppTheme.textMuted),
                tooltip: 'Limpar conversa',
                onPressed: _clearChat,
              ),
          ],
        ),
      );

  Widget _buildBody() {
    if (_messages.isEmpty && !_isStreaming && _error == null) {
      return _buildEmptyState();
    }

    final hasExtra = _isStreaming || _error != null;
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      itemCount: _messages.length + (hasExtra ? 1 : 0),
      itemBuilder: (_, i) {
        if (i < _messages.length) return _MessageBubble(msg: _messages[i]);
        if (_error != null) return _ErrorBubble(error: _error!);
        return _StreamingBubble(text: _streamingText, status: _statusText);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: context.appPrimary.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.smart_toy,
                  size: 36, color: context.appPrimary),
            ),
            const SizedBox(height: 16),
            const Text('Como posso ajudar?',
                style:
                    TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text(
              'Pergunte sobre saldo, gastos, categorias\nou peça para criar transações.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                _SuggestionChip(
                  label: 'Qual meu saldo?',
                  onTap: () =>
                      _sendSuggestion('Qual é meu saldo atual em cada conta?'),
                ),
                _SuggestionChip(
                  label: 'Gastos do mês',
                  onTap: () => _sendSuggestion(
                      'Quanto gastei esse mês e em quais categorias?'),
                ),
                _SuggestionChip(
                  label: 'Maiores despesas',
                  onTap: () => _sendSuggestion(
                      'Quais foram minhas maiores despesas recentes?'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _sendSuggestion(String text) {
    _ctrl.text = text;
    _send();
  }

  Widget _buildInputBar() {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 12 + inset),
      decoration: BoxDecoration(
        color: context.appSurface,
        border: Border(top: BorderSide(color: context.appBorder)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: context.appBg,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: context.appBorder),
              ),
              child: TextField(
                controller: _ctrl,
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Escreva sua pergunta…',
                  hintStyle:
                      TextStyle(color: AppTheme.textMuted, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _isStreaming ? null : _send,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _isStreaming
                    ? context.appPrimary.withAlpha(80)
                    : context.appPrimary,
                shape: BoxShape.circle,
              ),
              child: _isStreaming
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Message bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final _Message msg;
  const _MessageBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final isUser = msg.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: context.appPrimary.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.smart_toy,
                  size: 15, color: context.appPrimary),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? context.appPrimary : context.appSurface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
              ),
              child: isUser
                  ? SelectableText(
                      msg.content,
                      style: const TextStyle(
                          fontSize: 14, color: Colors.white, height: 1.45),
                    )
                  : MarkdownBody(
                      data: msg.content,
                      selectable: true,
                      extensionSet: md.ExtensionSet.gitHubFlavored,
                      styleSheet: _mdStyle(context),
                    ),
            ),
          ),
          if (isUser) const SizedBox(width: 36),
        ],
      ),
    );
  }
}

// ── Streaming bubble ──────────────────────────────────────────────────────────

class _StreamingBubble extends StatelessWidget {
  final String text;
  final String status;
  const _StreamingBubble({required this.text, required this.status});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: context.appPrimary.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.smart_toy,
                size: 15, color: context.appPrimary),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: context.appSurface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(18),
                ),
              ),
              child: text.isNotEmpty
                  ? Text('$text▋',
                      style: const TextStyle(fontSize: 14, height: 1.45))
                  : Row(
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: context.appPrimary),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            status.isNotEmpty ? status : 'pensando...',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textMuted,
                                fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error bubble ──────────────────────────────────────────────────────────────

class _ErrorBubble extends StatelessWidget {
  final String error;
  const _ErrorBubble({required this.error});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppTheme.red.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline,
                size: 15, color: AppTheme.red),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.red.withAlpha(15),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(18),
                ),
                border: Border.all(color: AppTheme.red.withAlpha(60)),
              ),
              child: Text(error,
                  style:
                      const TextStyle(fontSize: 13, color: AppTheme.red)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Suggestion chip ───────────────────────────────────────────────────────────

class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SuggestionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.appBorder),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 12, color: AppTheme.textSecondary)),
      ),
    );
  }
}
