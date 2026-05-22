import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

bool get isDesktop =>
    !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

bool get supportsGoogleSignIn =>
    !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

Future<T?> showAdaptiveSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  if (isDesktop) {
    return showDialog<T>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: builder(ctx),
        ),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: builder,
  );
}
