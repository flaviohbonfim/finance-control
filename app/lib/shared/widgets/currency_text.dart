import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final _brl = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

String fmtBrl(double v) => _brl.format(v);

class CurrencyText extends StatelessWidget {
  final double value;
  final double fontSize;
  final FontWeight fontWeight;
  final Color? color;
  final bool showSign;

  const CurrencyText(
    this.value, {
    super.key,
    this.fontSize = 14,
    this.fontWeight = FontWeight.w600,
    this.color,
    this.showSign = false,
  });

  @override
  Widget build(BuildContext context) {
    final prefix = showSign && value > 0 ? '+' : '';
    return Text(
      '$prefix${fmtBrl(value)}',
      style: TextStyle(fontSize: fontSize, fontWeight: fontWeight, color: color),
    );
  }
}
