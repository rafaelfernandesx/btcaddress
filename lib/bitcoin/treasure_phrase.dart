import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:hex/hex.dart';
import 'package:pointycastle/api.dart' show KeyDerivator;
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/key_derivators/api.dart' show Pbkdf2Parameters;
import 'package:pointycastle/key_derivators/pbkdf2.dart';
import 'package:pointycastle/macs/hmac.dart';

class TreasurePhraseSeed {
  final int iterations;
  final String saltHex;

  const TreasurePhraseSeed({
    required this.iterations,
    required this.saltHex,
  });

  /// Formato: `treasure1:<iterations>:<saltHex>`
  static TreasurePhraseSeed parse(String seedText) {
    final trimmed = seedText.trim();
    final parts = trimmed.split(':');
    if (parts.length != 3) {
      throw const FormatException('Seed Treasure inválida (formato).');
    }

    if (parts[0] != 'treasure1') {
      throw const FormatException('Seed Treasure inválida (prefixo).');
    }

    final iterations = int.tryParse(parts[1]);
    if (iterations == null || iterations < 10_000 || iterations > 5_000_000) {
      throw const FormatException('Iterações inválidas (use 10k..5M).');
    }

    final saltHex = parts[2].trim();
    final saltBytes = _decodeHex(saltHex);
    if (saltBytes.length < 8) {
      throw const FormatException('Salt HEX muito curto (mínimo: 8 bytes).');
    }

    return TreasurePhraseSeed(iterations: iterations, saltHex: saltHex);
  }

  String toSeedText() => 'treasure1:$iterations:$saltHex';
}

class TreasurePhraseMaterial {
  final String seedText;
  final String privateKeyHex;

  const TreasurePhraseMaterial({
    required this.seedText,
    required this.privateKeyHex,
  });
}

class TreasurePhraseGenerator {
  static final BigInt _secp256k1N = BigInt.parse(
    'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141',
    radix: 16,
  );

  /// Deriva uma chave a partir de uma frase longa usando PBKDF2-HMAC-SHA256.
  ///
  /// - key32 = PBKDF2(phrase, salt, iterations, 32)
  /// - digest = SHA-256(key32)
  /// - PrivateKeyHex = SHA-256(digest || counter) até cair em 1..(n-1)
  /// - SeedText = treasure1:iterations:saltHex (não contém a frase)
  static TreasurePhraseMaterial fromPhrase({
    required String phrase,
    required TreasurePhraseSeed seed,
  }) {
    final normalizedPhrase = phrase.trim();
    if (normalizedPhrase.length < 12) {
      throw const FormatException('Frase muito curta (mínimo: 12 caracteres).');
    }

    final saltBytes = _decodeHex(seed.saltHex);
    if (saltBytes.length < 8) {
      throw const FormatException('Salt HEX muito curto (mínimo: 8 bytes).');
    }

    final key32 = _pbkdf2Sha256(
      password: utf8.encode(normalizedPhrase),
      salt: saltBytes,
      iterations: seed.iterations,
      derivedKeyLength: 32,
    );

    final digest = Uint8List.fromList(sha256.convert(key32).bytes);
    final privateKeyHex = _derivePrivateKeyHex(digest);

    return TreasurePhraseMaterial(
      seedText: seed.toSeedText(),
      privateKeyHex: privateKeyHex,
    );
  }

  static Uint8List _pbkdf2Sha256({
    required List<int> password,
    required Uint8List salt,
    required int iterations,
    required int derivedKeyLength,
  }) {
    final KeyDerivator derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    derivator.init(Pbkdf2Parameters(salt, iterations, derivedKeyLength));
    return derivator.process(Uint8List.fromList(password));
  }

  static String _derivePrivateKeyHex(Uint8List digest) {
    for (int counter = 0; counter < 4096; counter++) {
      final bytes = BytesBuilder();
      bytes.add(digest);
      bytes.add(_u32be(counter));
      final candidate = Uint8List.fromList(sha256.convert(bytes.toBytes()).bytes);
      final hex = HEX.encode(candidate);
      final k = BigInt.parse(hex, radix: 16);
      if (k == BigInt.zero) continue;
      if (k >= _secp256k1N) continue;
      return hex;
    }
    throw StateError('Falha ao derivar uma private key válida.');
  }

  static List<int> _u32be(int v) {
    return [
      (v >> 24) & 0xFF,
      (v >> 16) & 0xFF,
      (v >> 8) & 0xFF,
      v & 0xFF,
    ];
  }
}

Uint8List _decodeHex(String hexStr) {
  if (hexStr.isEmpty) return Uint8List(0);
  final normalized = hexStr.toLowerCase();
  try {
    return Uint8List.fromList(HEX.decode(normalized));
  } catch (_) {
    throw const FormatException('Salt HEX inválido.');
  }
}
