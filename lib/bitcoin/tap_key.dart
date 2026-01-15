import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:hex/hex.dart';

class TapKeyMaterial {
  final String seedText;
  final String privateKeyHex;

  const TapKeyMaterial({
    required this.seedText,
    required this.privateKeyHex,
  });
}

class TapKeyGenerator {
  static final BigInt _secp256k1N = BigInt.parse(
    'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141',
    radix: 16,
  );

  /// Gera uma seed (texto) e uma private key (HEX) a partir de intervalos
  /// entre taps (ms). Não usa BIP39.
  ///
  /// O fluxo é:
  /// - Serializa os intervalos em bytes (2 bytes por intervalo, big-endian)
  /// - Mistura com `salt` via SHA-256
  /// - SeedText = base64url("tap:" + digest)
  /// - PrivateKeyHex = SHA-256(digest || counter) até cair em [1, n-1]
  static TapKeyMaterial fromIntervals(
    List<int> intervalsMs, {
    String salt = '',
  }) {
    if (intervalsMs.length < 16) {
      throw const FormatException('Faça mais taps (mínimo: 17 taps / 16 intervalos).');
    }

    final input = _encodeIntervals(intervalsMs);
    final mixed = Uint8List.fromList(<int>[...input, ...utf8.encode(salt)]);
    final digest = Uint8List.fromList(sha256.convert(mixed).bytes);

    final seedText = 'tap:${base64Url.encode(digest)}';
    final privateKeyHex = _derivePrivateKeyHex(digest);

    return TapKeyMaterial(seedText: seedText, privateKeyHex: privateKeyHex);
  }

  static Uint8List _encodeIntervals(List<int> intervalsMs) {
    final out = BytesBuilder();
    for (final ms in intervalsMs) {
      final v = ms.clamp(0, 65535);
      out.add([(v >> 8) & 0xFF, v & 0xFF]);
    }
    return out.toBytes();
  }

  static String _derivePrivateKeyHex(Uint8List digest) {
    // Tenta diferentes contadores até obter uma chave no range válido.
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
