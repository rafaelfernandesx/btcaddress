import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:hex/hex.dart';

class SplitKeyParts {
  final String partA;
  final String partB;

  const SplitKeyParts({
    required this.partA,
    required this.partB,
  });

  static SplitKeyParts generate({int bytes = 32}) {
    if (bytes < 16 || bytes > 64) {
      throw const FormatException('Tamanho inválido para SplitKey (16..64 bytes).');
    }

    final rnd = Random.secure();
    final a = Uint8List.fromList(List<int>.generate(bytes, (_) => rnd.nextInt(256)));
    final b = Uint8List.fromList(List<int>.generate(bytes, (_) => rnd.nextInt(256)));
    return fromBytes(a: a, b: b);
  }

  static SplitKeyParts fromBytes({required Uint8List a, required Uint8List b}) {
    if (a.length != b.length) {
      throw const FormatException('As partes A e B devem ter o mesmo tamanho.');
    }

    final encA = _encodePart(prefix: 'sk1A', payload: a);
    final encB = _encodePart(prefix: 'sk1B', payload: b);
    return SplitKeyParts(partA: encA, partB: encB);
  }

  static String encodePartA(Uint8List payload) => _encodePart(prefix: 'sk1A', payload: payload);

  static String encodePartB(Uint8List payload) => _encodePart(prefix: 'sk1B', payload: payload);

  static Uint8List decodePart(String part) {
    final trimmed = part.trim();
    final idx = trimmed.indexOf(':');
    if (idx <= 0) throw const FormatException('Parte inválida (prefixo ausente).');

    final prefix = trimmed.substring(0, idx);
    if (prefix != 'sk1A' && prefix != 'sk1B') {
      throw const FormatException('Parte inválida (prefixo).');
    }

    final b64 = trimmed.substring(idx + 1);
    Uint8List raw;
    try {
      raw = Uint8List.fromList(base64Url.decode(b64));
    } catch (_) {
      throw const FormatException('Parte inválida (base64).');
    }

    if (raw.length < 4 + 16) {
      throw const FormatException('Parte inválida (curta demais).');
    }

    final payload = raw.sublist(0, raw.length - 4);
    final checksum = raw.sublist(raw.length - 4);
    final expected = _checksum4(payload);
    if (!_bytesEqual(checksum, expected)) {
      throw const FormatException('Parte inválida (checksum).');
    }

    return payload;
  }

  static String _encodePart({required String prefix, required Uint8List payload}) {
    final checksum = _checksum4(payload);
    final out = Uint8List.fromList(<int>[...payload, ...checksum]);
    final b64 = base64Url.encode(out);
    return '$prefix:$b64';
  }

  static Uint8List _checksum4(Uint8List payload) {
    final h = sha256.convert(payload).bytes;
    return Uint8List.fromList(h.sublist(0, 4));
  }
}

class SplitKeyMaterial {
  final String seedText;
  final String privateKeyHex;

  const SplitKeyMaterial({
    required this.seedText,
    required this.privateKeyHex,
  });
}

class SplitKeyCombiner {
  static final BigInt _secp256k1N = BigInt.parse(
    'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141',
    radix: 16,
  );

  static SplitKeyMaterial combine({
    required String partA,
    required String partB,
    String salt = '',
  }) {
    final a = SplitKeyParts.decodePart(partA);
    final b = SplitKeyParts.decodePart(partB);
    if (a.length != b.length) {
      throw const FormatException('As partes A e B precisam ter o mesmo tamanho.');
    }

    final mixed = Uint8List.fromList(<int>[...a, ...b, ...utf8.encode(salt)]);
    final digest = Uint8List.fromList(sha256.convert(mixed).bytes);

    final seedText = 'split:${base64Url.encode(digest)}';
    final privateKeyHex = _derivePrivateKeyHex(digest);

    return SplitKeyMaterial(seedText: seedText, privateKeyHex: privateKeyHex);
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

bool _bytesEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
