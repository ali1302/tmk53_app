import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';

enum TmkThemeId { dark, maroon, teal }

class ThemeProvider extends ChangeNotifier {
  static const _prefsKey = 'tmk_color_theme';

  TmkThemeId _themeId = TmkThemeId.maroon;
  bool _ready = false;

  TmkThemeId get themeId => _themeId;
  bool get isReady => _ready;

  TmkPalette get palette => TmkPalette.of(_themeId);

  ThemeData get themeData => AppTheme.fromPalette(palette);

  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    _themeId = TmkThemeId.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => TmkThemeId.maroon,
    );
    AppColors.bind(palette);
    _ready = true;
    notifyListeners();
  }

  Future<void> setTheme(TmkThemeId id) async {
    if (_themeId == id) return;
    _themeId = id;
    AppColors.bind(palette);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, id.name);
  }
}
