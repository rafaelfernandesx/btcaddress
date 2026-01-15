import 'dart:convert';

import 'package:bip39/bip39.dart' as bip39;
import 'package:crypto/crypto.dart';
import 'package:hex/hex.dart';

class DiceMnemonic {
  static const int rollsFor12Words = 50;
  static const int rollsFor24Words = 99;

  static int requiredRolls({required int wordCount}) {
    return switch (wordCount) {
      12 => rollsFor12Words,
      24 => rollsFor24Words,
      _ => throw const FormatException('wordCount deve ser 12 ou 24.'),
    };
  }

  /// Gera uma mnemonic BIP39 a partir de rolagens de dado (1..6).
  ///
  /// Para reduzir risco de viés, a entrada é normalizada e passada por SHA-256;
  /// em seguida, usa-se 16 bytes (12 palavras) ou 32 bytes (24 palavras) como entropia.
  static String mnemonicFromDiceRolls(
    String rolls, {
    int wordCount = 12,
  }) {
    final normalized = normalizeRolls(rolls);
    final req = requiredRolls(wordCount: wordCount);

    if (normalized.length < req) {
      throw FormatException('Faltam rolagens: ${normalized.length}/$req.');
    }

    final used = normalized.substring(0, req);
    final digest = sha256.convert(utf8.encode(used)).bytes;

    final entropyBytes = switch (wordCount) {
      12 => digest.sublist(0, 16),
      24 => digest.sublist(0, 32),
      _ => throw const FormatException('wordCount deve ser 12 ou 24.'),
    };

    final entropyHex = HEX.encode(entropyBytes);
    return bip39.entropyToMnemonic(entropyHex);
  }

  /// Mantém apenas caracteres 1..6.
  static String normalizeRolls(String s) {
    final sb = StringBuffer();
    for (final c in s.codeUnits) {
      if (c >= 0x31 && c <= 0x36) {
        sb.writeCharCode(c);
      }
    }
    return sb.toString();
  }
}
