import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:hex/hex.dart';

class ShakeSample {
  final double x;
  final double y;
  final double z;

  const ShakeSample({
    required this.x,
    required this.y,
    required this.z,
  });
}

class ShakeKeyMaterial {
  final String seedText;
  final String privateKeyHex;

  const ShakeKeyMaterial({
    required this.seedText,
    required this.privateKeyHex,
  });
}

class ShakeKeyGenerator {
  static final BigInt _secp256k1N = BigInt.parse(
    'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141',
    radix: 16,
  );

  /// Gera uma seed (texto) e uma private key (HEX) a partir de amostras do
  /// acelerômetro.
  ///
  /// Fluxo:
  /// - Quantiza (x,y,z) em int16 com escala (padrão: 1000)
  /// - Serializa em bytes
  /// - SHA-256(dados || salt)
  /// - SeedText = shake:base64url(digest)
  /// - PrivateKeyHex = SHA-256(digest || counter) até cair em 1..(n-1)
  static ShakeKeyMaterial fromSamples(
    List<ShakeSample> samples, {
    String salt = '',
    int minSamples = 64,
    int quantizationScale = 1000,
  }) {
    if (samples.length < minSamples) {
      throw FormatException('Amostras insuficientes (mínimo: $minSamples).');
    }

    final encoded = _encodeSamples(samples, quantizationScale: quantizationScale);
    final mixed = Uint8List.fromList(<int>[...encoded, ...utf8.encode(salt)]);
    final digest = Uint8List.fromList(sha256.convert(mixed).bytes);

    final seedText = 'shake:${base64Url.encode(digest)}';
    final privateKeyHex = _derivePrivateKeyHex(digest);

    return ShakeKeyMaterial(seedText: seedText, privateKeyHex: privateKeyHex);
  }

  static Uint8List _encodeSamples(
    List<ShakeSample> samples, {
    required int quantizationScale,
  }) {
    final out = BytesBuilder();
    for (final s in samples) {
      out.add(_i16be((s.x * quantizationScale).round()));
      out.add(_i16be((s.y * quantizationScale).round()));
      out.add(_i16be((s.z * quantizationScale).round()));
    }
    return out.toBytes();
  }

  static List<int> _i16be(int v) {
    final clamped = v.clamp(-32768, 32767);
    final u = clamped & 0xFFFF;
    return [(u >> 8) & 0xFF, u & 0xFF];
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
