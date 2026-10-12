import 'package:flutter/material.dart';

/// Переключатели прототипа, которыми управляет оверлей замера.
class AppState extends ChangeNotifier {
  bool blur = true;
  ThemeMode themeMode = ThemeMode.system;
  bool overlay = true;

  void setBlur(bool v) {
    blur = v;
    notifyListeners();
  }

  void cycleTheme() {
    themeMode = switch (themeMode) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
    notifyListeners();
  }

  void toggleOverlay() {
    overlay = !overlay;
    notifyListeners();
  }
}
