import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/address_model.dart';

class StorageService {
  static const String _historyKey = 'address_history';
  static const String _themeKey = 'theme_mode';

  Future<void> saveAddress(AddressModel address) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList(_historyKey) ?? [];

    // Limitar histórico a 50 itens
    if (history.length >= 50) {
      history.removeAt(0);
    }

    history.add(jsonEncode(address.toJson()));
    await prefs.setStringList(_historyKey, history);
  }

  Future<List<AddressModel>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList(_historyKey) ?? [];

    return history.map((item) => AddressModel.fromJson(jsonDecode(item))).toList().reversed.toList();
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }

  Future<void> setThemeMode(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, isDark);
  }

  Future<bool> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_themeKey) ?? false;
  }
}
