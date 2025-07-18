// settings.dart
import 'package:flutter/material.dart';

/// Unit preferences
enum WeightUnit { metric, imperial }
enum CardioUnit { km, miles, feet }

/// Theme & unit settings controller
class Settings extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.light;
  WeightUnit weightUnit = WeightUnit.metric;
  CardioUnit cardioUnit = CardioUnit.km;

  void toggleTheme(bool isDark) {
    themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  void setWeightUnit(WeightUnit u) {
    weightUnit = u;
    notifyListeners();
  }

  void setCardioUnit(CardioUnit u) {
    cardioUnit = u;
    notifyListeners();
  }
}
