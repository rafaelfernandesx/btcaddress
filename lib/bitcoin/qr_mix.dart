import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:hex/hex.dart';

class QrMixMaterial {
  final String seedText;
  final String privateKeyHex;

  const QrMixMaterial({
    required this.seedText,
    required this.privateKeyHex,
  });
}

class QrMixGenerator {
  static final BigInt _secp256k1N = BigInt.parse(
    'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141',
    radix: 16,
  );

  /// Gera uma seed (texto) e uma private key (HEX) a partir de um texto
  /// (ex.: conteúdo de um QR) + um salt local em HEX.
  ///
  /// SeedText canônico: `qrmix1:<saltHex>:<base64url(utf8(text))>`
  static QrMixMaterial fromText({
    required String text,
    required String saltHex,
  }) {
    final normalizedText = text.trim();
    if (normalizedText.isEmpty) {
      throw const FormatException('Informe um texto para misturar (não pode ser vazio).');
    }

    final saltBytes = _decodeHex(saltHex.trim());
    if (saltBytes.isEmpty) {
      throw const FormatException('Informe um salt HEX (não pode ser vazio).');
    }

    final textBytes = Uint8List.fromList(utf8.encode(normalizedText));
    final mixed = Uint8List.fromList(<int>[...textBytes, ...saltBytes]);
    final digest = Uint8List.fromList(sha256.convert(mixed).bytes);

    final seedText = _buildSeedText(normalizedText, saltHex.trim());
    final privateKeyHex = _derivePrivateKeyHex(digest);

    return QrMixMaterial(seedText: seedText, privateKeyHex: privateKeyHex);
  }

  static QrMixMaterial fromSeedText(String seedText) {
    final trimmed = seedText.trim();
    final parts = trimmed.split(':');
    if (parts.length < 3) {
      throw const FormatException('Seed QR-Mix inválida (formato).');
    }

    final prefix = parts[0];
    if (prefix != 'qrmix1') {
      throw const FormatException('Seed QR-Mix inválida (prefixo).');
    }

    final saltHex = parts[1];
    final b64 = parts.sublist(2).join(':');

    String text;
    try {
      text = utf8.decode(base64Url.decode(b64));
    } catch (_) {
      throw const FormatException('Seed QR-Mix inválida (base64).');
    }

    return fromText(text: text, saltHex: saltHex);
  }

  static String _buildSeedText(String text, String saltHex) {
    final b64 = base64Url.encode(utf8.encode(text));
    return 'qrmix1:$saltHex:$b64';
  }

  static Uint8List _decodeHex(String hexStr) {
    if (hexStr.isEmpty) return Uint8List(0);
    final normalized = hexStr.toLowerCase();
    try {
      return Uint8List.fromList(HEX.decode(normalized));
    } catch (_) {
      throw const FormatException('Salt HEX inválido.');
    }
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
