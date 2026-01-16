import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'split_key.dart';

class DuetKey {
  /// Gera a Parte A (sk1A:...) a partir de intervalos (ms).
  static String partAFromIntervals(List<int> intervalsMs, {String salt = ''}) {
    return _partFromIntervals('A', intervalsMs, salt: salt);
  }

  /// Gera a Parte B (sk1B:...) a partir de intervalos (ms).
  static String partBFromIntervals(List<int> intervalsMs, {String salt = ''}) {
    return _partFromIntervals('B', intervalsMs, salt: salt);
  }

  /// Combina Parte A e Parte B (pode usar um salt adicional).
  static SplitKeyMaterial combine({required String partA, required String partB, String salt = ''}) {
    return SplitKeyCombiner.combine(partA: partA, partB: partB, salt: salt);
  }

  static String _partFromIntervals(String role, List<int> intervalsMs, {required String salt}) {
    if (intervalsMs.length < 16) {
      throw const FormatException('Faça mais taps (mínimo: 17 taps / 16 intervalos).');
    }

    final payload = _digestToPayload(role, intervalsMs, salt: salt);
    return role == 'A' ? SplitKeyParts.encodePartA(payload) : SplitKeyParts.encodePartB(payload);
  }

  static Uint8List _digestToPayload(String role, List<int> intervalsMs, {required String salt}) {
    final bytes = BytesBuilder();
    bytes.add(utf8.encode('duet:$role:'));
    for (final ms in intervalsMs) {
      final v = ms.clamp(0, 65535);
      bytes.add([(v >> 8) & 0xFF, v & 0xFF]);
    }
    if (salt.trim().isNotEmpty) {
      bytes.add(utf8.encode(':'));
      bytes.add(utf8.encode(salt));
    }
    return Uint8List.fromList(sha256.convert(bytes.toBytes()).bytes);
  }
}
