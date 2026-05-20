import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/models.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/currency_text.dart';

class LaunchModal extends StatefulWidget {
  final RecurringTransaction rt;
  final VoidCallback onDone;

  const LaunchModal({super.key, required this.rt, required this.onDone});

  @override
  State<LaunchModal> createState() => _LaunchModalState();
}

class _LaunchModalState extends State<LaunchModal> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  bool _success = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.rt.amount != null) {
      _ctrl.text = widget.rt.amount!.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _launch() async {
    setState(() { _loading = true; _error = null; });
    try {
      final amount = widget.rt.isFixed ? widget.rt.amount : double.tryParse(_ctrl.text);
      await api.post(
        '/recurring-transactions/${widget.rt.id}/launch',
        data: {'amount': amount},
      );
      setState(() { _success = true; _loading = false; });
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        Navigator.pop(context);
        widget.onDone();
      }
    } catch (e) {
      setState(() { _error = 'Erro ao lançar'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppTheme.cardBorder, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Lançar Recorrente',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          if (_success)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Column(children: [
                  Icon(Icons.check_circle, color: AppTheme.green, size: 48),
                  SizedBox(height: 8),
                  Text('Lançado com sucesso!',
                      style: TextStyle(color: AppTheme.green, fontWeight: FontWeight.w600)),
                ]),
              ),
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.bgColor, borderRadius: BorderRadius.circular(12)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.rt.description,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  '${widget.rt.isIncome ? 'Receita' : 'Despesa'} · ${widget.rt.accountName ?? ''}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            if (!widget.rt.isFixed) ...[
              TextField(
                controller: _ctrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Valor (R\$)'),
              ),
              const SizedBox(height: 16),
            ] else if (widget.rt.amount != null) ...[
              Row(children: [
                const Text('Valor: ', style: TextStyle(color: AppTheme.textSecondary)),
                CurrencyText(widget.rt.amount!, fontSize: 15),
              ]),
              const SizedBox(height: 16),
            ],
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: AppTheme.red, fontSize: 13)),
              const SizedBox(height: 8),
            ],
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    side: const BorderSide(color: AppTheme.cardBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _loading ? null : _launch,
                  style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
                  child: _loading
                      ? const SizedBox(height: 18, width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Confirmar'),
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}
