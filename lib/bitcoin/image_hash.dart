import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:hex/hex.dart';

class ImageHashMaterial {
  final String seedText;
  final String privateKeyHex;

  const ImageHashMaterial({
    required this.seedText,
    required this.privateKeyHex,
  });
}

class ImageHashGenerator {
  static final BigInt _secp256k1N = BigInt.parse(
    'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141',
    radix: 16,
  );

  /// Gera material a partir dos bytes da imagem + um salt local em HEX.
  ///
  /// Observação: a seed gerada contém o digest (misturado) e o salt.
  /// Guardar a seed equivale a guardar o segredo.
  static ImageHashMaterial fromBytes({
    required Uint8List imageBytes,
    required String saltHex,
  }) {
    if (imageBytes.isEmpty) {
      throw const FormatException('Imagem vazia (bytes ausentes).');
    }

    final saltBytes = _decodeHex(saltHex.trim());
    if (saltBytes.isEmpty) {
      throw const FormatException('Informe um salt HEX (não pode ser vazio).');
    }

    final mixed = Uint8List.fromList(<int>[...imageBytes, ...saltBytes]);
    final digest = Uint8List.fromList(sha256.convert(mixed).bytes);

    final seedText = _buildSeedText(saltHex: saltHex.trim(), digest: digest);
    final privateKeyHex = _derivePrivateKeyHex(digest);

    return ImageHashMaterial(seedText: seedText, privateKeyHex: privateKeyHex);
  }

  /// Reconstrói o material apenas a partir da seed, sem precisar da imagem.
  static ImageHashMaterial fromSeedText(String seedText) {
    final trimmed = seedText.trim();
    final parts = trimmed.split(':');
    if (parts.length < 3) {
      throw const FormatException('Seed ImageHash inválida (formato).');
    }

    final prefix = parts[0];
    if (prefix != 'img1') {
      throw const FormatException('Seed ImageHash inválida (prefixo).');
    }

    final saltHex = parts[1];
    final b64 = parts.sublist(2).join(':');

    Uint8List digest;
    try {
      digest = Uint8List.fromList(base64Url.decode(b64));
    } catch (_) {
      throw const FormatException('Seed ImageHash inválida (base64).');
    }

    if (digest.length != 32) {
      throw const FormatException('Seed ImageHash inválida (digest).');
    }

    final privateKeyHex = _derivePrivateKeyHex(digest);
    final normalizedSeed = _buildSeedText(saltHex: saltHex, digest: digest);

    return ImageHashMaterial(seedText: normalizedSeed, privateKeyHex: privateKeyHex);
  }

  static String _buildSeedText({required String saltHex, required Uint8List digest}) {
    return 'img1:$saltHex:${base64Url.encode(digest)}';
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
