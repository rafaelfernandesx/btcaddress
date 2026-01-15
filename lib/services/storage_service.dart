import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/address_model.dart';

class StorageService {
  static const String _historyKey = 'address_history';
  static const String _themeKey = 'theme_mode';

  static const int _historyLimit = 50;

  List<AddressModel> _normalizeForStorage(List<AddressModel> addresses) {
    final list = [...addresses];
    list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return list.length <= _historyLimit ? list : list.sublist(list.length - _historyLimit);
  }

  String _dedupeKey(AddressModel a) {
    if (a.privateKeyHex.isNotEmpty) return 'k:${a.privateKeyHex}';
    if (a.addressTaproot.isNotEmpty) return 'a:${a.addressTaproot}';
    if (a.addressBech32.isNotEmpty) return 'a:${a.addressBech32}';
    if (a.addressCompressed.isNotEmpty) return 'a:${a.addressCompressed}';
    return 'a:${a.addressUncompressed}';
  }

  Future<void> saveAddress(AddressModel address) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList(_historyKey) ?? [];

    // Limitar histórico a 50 itens
    if (history.length >= _historyLimit) {
      history.removeAt(0);
    }

    history.add(jsonEncode(address.toJson()));
    await prefs.setStringList(_historyKey, history);
  }

  Future<int> overwriteHistory(List<AddressModel> addresses) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = _normalizeForStorage(addresses);
    final encoded = trimmed.map((a) => jsonEncode(a.toJson())).toList();
    await prefs.setStringList(_historyKey, encoded);
    return trimmed.length;
  }

  Future<int> mergeHistory(List<AddressModel> imported) async {
    // getHistory() retorna em ordem reversa (mais recente primeiro).
    final existingDisplayOrder = await getHistory();
    final existingChrono = existingDisplayOrder.reversed.toList();

    final combined = <AddressModel>[...existingChrono, ...imported];
    combined.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final map = <String, AddressModel>{};
    for (final item in combined) {
      map[_dedupeKey(item)] = item;
    }

    return overwriteHistory(map.values.toList());
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
