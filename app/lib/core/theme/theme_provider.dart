import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'app_theme.dart';

const _kThemeKey = 'theme_variant';

class ThemeNotifier extends Notifier<AppThemeVariant> {
  static const _storage = FlutterSecureStorage();

  @override
  AppThemeVariant build() {
    _load();
    return AppThemeVariant.dark;
  }

  Future<void> _load() async {
    final val = await _storage.read(key: _kThemeKey);
    if (val == null) return;
    final found = AppThemeVariant.values.where((v) => v.name == val).firstOrNull;
    if (found != null) state = found;
  }

  Future<void> set(AppThemeVariant variant) async {
    state = variant;
    await _storage.write(key: _kThemeKey, value: variant.name);
  }
}

final themeProvider =
    NotifierProvider<ThemeNotifier, AppThemeVariant>(ThemeNotifier.new);
