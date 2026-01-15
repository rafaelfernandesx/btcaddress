import 'dart:typed_data';

import 'package:crypto/crypto.dart';

class BitcoinAddressValidationResult {
  final bool isValid;
  final String? type;
  final String? network;
  final String? error;

  const BitcoinAddressValidationResult._({
    required this.isValid,
    this.type,
    this.network,
    this.error,
  });

  const BitcoinAddressValidationResult.valid({
    required String type,
    required String network,
  }) : this._(isValid: true, type: type, network: network);

  const BitcoinAddressValidationResult.invalid(String message) : this._(isValid: false, error: message);
}

class BitcoinAddressValidator {
  static BitcoinAddressValidationResult validate(String address) {
    final a = address.trim();
    if (a.isEmpty) return const BitcoinAddressValidationResult.invalid('Endereço vazio.');

    if (a.contains(':')) {
      return const BitcoinAddressValidationResult.invalid('Remova prefixos como "bitcoin:".');
    }

    if (a.startsWith('1') || a.startsWith('3') || a.startsWith('m') || a.startsWith('n') || a.startsWith('2')) {
      return _validateBase58Check(a);
    }

    final lower = a.toLowerCase();
    if (lower.startsWith('bc1') || lower.startsWith('tb1')) {
      return _validateSegwitBech32(a);
    }

    // Fallback: tente ambos.
    final b58 = _try(() => _validateBase58Check(a));
    if (b58 != null && b58.isValid) return b58;

    final seg = _try(() => _validateSegwitBech32(a));
    if (seg != null && seg.isValid) return seg;

    return const BitcoinAddressValidationResult.invalid('Formato de endereço desconhecido.');
  }

  static BitcoinAddressValidationResult? _try(BitcoinAddressValidationResult Function() fn) {
    try {
      return fn();
    } catch (_) {
      return null;
    }
  }

  // ---------------- Base58Check ----------------

  static const String _b58Alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

  static BitcoinAddressValidationResult _validateBase58Check(String address) {
    final bytes = _base58Decode(address);
    if (bytes.length != 25) {
      return const BitcoinAddressValidationResult.invalid('Base58Check inválido (tamanho inesperado).');
    }

    final payload = bytes.sublist(0, 21);
    final checksum = bytes.sublist(21, 25);
    final expected = _checksum4(payload);
    if (!_bytesEqual(checksum, expected)) {
      return const BitcoinAddressValidationResult.invalid('Checksum Base58Check inválido.');
    }

    final version = payload[0];
    // Mainnet
    if (version == 0x00) {
      return const BitcoinAddressValidationResult.valid(type: 'P2PKH (legacy)', network: 'mainnet');
    }
    if (version == 0x05) {
      return const BitcoinAddressValidationResult.valid(type: 'P2SH', network: 'mainnet');
    }

    // Testnet
    if (version == 0x6f) {
      return const BitcoinAddressValidationResult.valid(type: 'P2PKH (legacy)', network: 'testnet');
    }
    if (version == 0xc4) {
      return const BitcoinAddressValidationResult.valid(type: 'P2SH', network: 'testnet');
    }

    return BitcoinAddressValidationResult.valid(type: 'Base58Check (versão 0x${version.toRadixString(16)})', network: 'desconhecida');
  }

  static Uint8List _base58Decode(String input) {
    if (input.isEmpty) return Uint8List(0);

    // Rejeita caracteres inválidos cedo.
    for (final c in input.codeUnits) {
      if (!_b58Alphabet.contains(String.fromCharCode(c))) {
        throw const FormatException('Caractere inválido em Base58.');
      }
    }

    // Algoritmo clássico: converter base58 -> base256.
    final bytes = <int>[0];
    for (final rune in input.runes) {
      final int carry0 = _b58Alphabet.indexOf(String.fromCharCode(rune));
      int carry = carry0;
      for (int j = 0; j < bytes.length; j++) {
        carry += bytes[j] * 58;
        bytes[j] = carry & 0xff;
        carry >>= 8;
      }
      while (carry > 0) {
        bytes.add(carry & 0xff);
        carry >>= 8;
      }
    }

    // Preservar zeros à esquerda ("1" em base58).
    int leadingZeros = 0;
    for (int i = 0; i < input.length && input[i] == '1'; i++) {
      leadingZeros++;
    }

    final out = Uint8List(leadingZeros + bytes.length);
    for (int i = 0; i < bytes.length; i++) {
      out[out.length - 1 - i] = bytes[i];
    }
    return out;
  }

  static Uint8List _checksum4(List<int> payload) {
    final h1 = sha256.convert(payload).bytes;
    final h2 = sha256.convert(h1).bytes;
    return Uint8List.fromList(h2.sublist(0, 4));
  }

  // ---------------- Bech32 / Bech32m (SegWit) ----------------

  static const String _bech32Charset = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l';
  static const int _bech32Const = 1;
  static const int _bech32mConst = 0x2bc830a3;

  static BitcoinAddressValidationResult _validateSegwitBech32(String address) {
    if (_hasMixedCase(address)) {
      return const BitcoinAddressValidationResult.invalid('Bech32 inválido (misto de maiúsculas/minúsculas).');
    }

    final decoded = _bech32Decode(address.toLowerCase());
    if (decoded == null) {
      return const BitcoinAddressValidationResult.invalid('Bech32 inválido (checksum/forma).');
    }

    final hrp = decoded.hrp;
    final data = decoded.data;
    if (data.isEmpty) {
      return const BitcoinAddressValidationResult.invalid('Bech32 inválido (sem dados).');
    }

    final witVer = data[0];
    if (witVer < 0 || witVer > 16) {
      return const BitcoinAddressValidationResult.invalid('SegWit inválido (witness version fora de 0..16).');
    }

    final prog = _convertBits(data.sublist(1), from: 5, to: 8, pad: false);
    if (prog == null) {
      return const BitcoinAddressValidationResult.invalid('SegWit inválido (conversão de bits falhou).');
    }

    if (prog.length < 2 || prog.length > 40) {
      return const BitcoinAddressValidationResult.invalid('SegWit inválido (witness program com tamanho inválido).');
    }

    // Verificar constante: v0 => bech32; v1+ => bech32m.
    if (witVer == 0 && decoded.encoding != _bech32Const) {
      return const BitcoinAddressValidationResult.invalid('SegWit v0 deve usar Bech32 (não Bech32m).');
    }
    if (witVer != 0 && decoded.encoding != _bech32mConst) {
      return const BitcoinAddressValidationResult.invalid('SegWit v1+ deve usar Bech32m.');
    }

    String type;
    if (witVer == 0 && prog.length == 20) {
      type = 'P2WPKH (Bech32)';
    } else if (witVer == 0 && prog.length == 32) {
      type = 'P2WSH (Bech32)';
    } else if (witVer == 1 && prog.length == 32) {
      type = 'P2TR (Taproot / Bech32m)';
    } else {
      type = 'SegWit v$witVer (${prog.length} bytes)';
    }

    final network = switch (hrp) {
      'bc' => 'mainnet',
      'tb' => 'testnet',
      _ => 'desconhecida',
    };

    // Checagens extras de BIP173/350.
    if (hrp != 'bc' && hrp != 'tb') {
      return BitcoinAddressValidationResult.valid(type: type, network: network);
    }

    if (witVer == 0 && (prog.length != 20 && prog.length != 32)) {
      return const BitcoinAddressValidationResult.invalid('SegWit v0 requer program de 20 ou 32 bytes.');
    }

    return BitcoinAddressValidationResult.valid(type: type, network: network);
  }

  static bool _hasMixedCase(String s) {
    final hasLower = s.contains(RegExp(r'[a-z]'));
    final hasUpper = s.contains(RegExp(r'[A-Z]'));
    return hasLower && hasUpper;
  }

  static _Bech32Decoded? _bech32Decode(String bech) {
    final pos = bech.lastIndexOf('1');
    if (pos < 1 || pos + 7 > bech.length) return null;

    final hrp = bech.substring(0, pos);
    final dataPart = bech.substring(pos + 1);

    final data = <int>[];
    for (final c in dataPart.codeUnits) {
      final ch = String.fromCharCode(c);
      final v = _bech32Charset.indexOf(ch);
      if (v < 0) return null;
      data.add(v);
    }

    final polymod = _bech32Polymod([..._bech32HrpExpand(hrp), ...data]);
    final encoding = (polymod == _bech32Const)
        ? _bech32Const
        : (polymod == _bech32mConst)
            ? _bech32mConst
            : null;

    if (encoding == null) return null;

    // remove checksum (últimos 6 valores)
    final payload = data.sublist(0, data.length - 6);
    return _Bech32Decoded(hrp: hrp, data: payload, encoding: encoding);
  }

  static int _bech32Polymod(List<int> values) {
    const List<int> generator = [
      0x3b6a57b2,
      0x26508e6d,
      0x1ea119fa,
      0x3d4233dd,
      0x2a1462b3,
    ];
    int chk = 1;
    for (final v in values) {
      final b = chk >> 25;
      chk = ((chk & 0x1ffffff) << 5) ^ v;
      for (int i = 0; i < 5; i++) {
        if (((b >> i) & 1) != 0) chk ^= generator[i];
      }
    }
    return chk;
  }

  static List<int> _bech32HrpExpand(String hrp) {
    final ret = <int>[];
    for (final c in hrp.codeUnits) {
      ret.add(c >> 5);
    }
    ret.add(0);
    for (final c in hrp.codeUnits) {
      ret.add(c & 31);
    }
    return ret;
  }

  static Uint8List? _convertBits(List<int> data, {required int from, required int to, required bool pad}) {
    int acc = 0;
    int bits = 0;
    final ret = <int>[];
    final maxv = (1 << to) - 1;
    for (final value in data) {
      if (value < 0 || (value >> from) != 0) return null;
      acc = (acc << from) | value;
      bits += from;
      while (bits >= to) {
        bits -= to;
        ret.add((acc >> bits) & maxv);
      }
    }
    if (pad) {
      if (bits > 0) ret.add((acc << (to - bits)) & maxv);
    } else {
      if (bits >= from) return null;
      if (((acc << (to - bits)) & maxv) != 0) return null;
    }
    return Uint8List.fromList(ret);
  }

  static bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class _Bech32Decoded {
  final String hrp;
  final List<int> data;
  final int encoding;

  const _Bech32Decoded({
    required this.hrp,
    required this.data,
    required this.encoding,
  });
}
