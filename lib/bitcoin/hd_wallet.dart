import 'dart:typed_data';

import 'package:bip32/bip32.dart' as bip32;
import 'package:bip39/bip39.dart' as bip39;
import 'package:bs58check/bs58check.dart' as bs58check;
import 'package:hex/hex.dart';

import '../btc_tool.dart';

enum HdDerivationScheme {
  bip44,
  bip84,
  bip86,
}

class HdWatchOnlyExport {
  final int version;
  final String exportedAt;
  final String scheme;
  final bool testnet;
  final String accountPath;
  final String extendedPublicKey;

  const HdWatchOnlyExport({
    required this.version,
    required this.exportedAt,
    required this.scheme,
    required this.testnet,
    required this.accountPath,
    required this.extendedPublicKey,
  });

  factory HdWatchOnlyExport.fromJson(Map<String, dynamic> json) {
    final type = (json['type'] ?? '').toString();
    if (type != 'watch-only') {
      throw const FormatException('JSON não é do tipo watch-only.');
    }

    final version = json['version'];
    final exportedAt = json['exportedAt'];
    final scheme = json['scheme'];
    final testnet = json['testnet'];
    final accountPath = json['accountPath'];
    final extendedPublicKey = json['extendedPublicKey'];

    if (version is! int) {
      throw const FormatException('Campo version inválido.');
    }

    if (exportedAt is! String || exportedAt.isEmpty) {
      throw const FormatException('Campo exportedAt inválido.');
    }

    if (scheme is! String || scheme.isEmpty) {
      throw const FormatException('Campo scheme inválido.');
    }

    if (testnet is! bool) {
      throw const FormatException('Campo testnet inválido.');
    }

    if (accountPath is! String || accountPath.isEmpty) {
      throw const FormatException('Campo accountPath inválido.');
    }

    if (extendedPublicKey is! String || extendedPublicKey.isEmpty) {
      throw const FormatException('Campo extendedPublicKey inválido.');
    }

    return HdWatchOnlyExport(
      version: version,
      exportedAt: exportedAt,
      scheme: scheme,
      testnet: testnet,
      accountPath: accountPath,
      extendedPublicKey: extendedPublicKey,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'exportedAt': exportedAt,
      'type': 'watch-only',
      'scheme': scheme,
      'testnet': testnet,
      'accountPath': accountPath,
      'extendedPublicKey': extendedPublicKey,
    };
  }
}

class HdDerivedAddress {
  final String path;
  final String addressLegacy;
  final String addressBech32;
  final String addressTaproot;
  final String privateKeyHex;
  final String privateKeyWif;
  final String privateKeyWifCompressed;
  final String publicKeyHex;
  final String publicKeyHexCompressed;

  const HdDerivedAddress({
    required this.path,
    required this.addressLegacy,
    required this.addressBech32,
    required this.addressTaproot,
    required this.privateKeyHex,
    required this.privateKeyWif,
    required this.privateKeyWifCompressed,
    required this.publicKeyHex,
    required this.publicKeyHexCompressed,
  });
}

class HdWalletDeriver {
  static bool isValidMnemonic(String mnemonic) => bip39.validateMnemonic(_normalizeMnemonic(mnemonic));

  static String generateMnemonic({int strength = 128}) => bip39.generateMnemonic(strength: strength);

  static List<HdDerivedAddress> deriveBatch({
    required String mnemonic,
    String passphrase = '',
    HdDerivationScheme scheme = HdDerivationScheme.bip84,
    bool testnet = false,
    int account = 0,
    int change = 0,
    int startIndex = 0,
    int count = 5,
  }) {
    final normalized = _normalizeMnemonic(mnemonic);
    if (!bip39.validateMnemonic(normalized)) {
      throw const FormatException('Mnemonic inválida (BIP39).');
    }

    final seed = _mnemonicToSeed(normalized, passphrase);
    final root = bip32.BIP32.fromSeed(seed);

    final coinType = testnet ? 1 : 0;
    final purpose = switch (scheme) {
      HdDerivationScheme.bip44 => 44,
      HdDerivationScheme.bip84 => 84,
      HdDerivationScheme.bip86 => 86,
    };

    final safeCount = count.clamp(1, 50);
    final out = <HdDerivedAddress>[];

    for (int i = 0; i < safeCount; i++) {
      final index = startIndex + i;
      final path = "m/$purpose'/$coinType'/$account'/$change/$index";
      final node = root.derivePath(path);
      final priv = node.privateKey;
      if (priv == null || priv.isEmpty) {
        throw StateError('Falha ao derivar chave privada em $path');
      }

      final tool = BitcoinTOOL();
      if (testnet) tool.setNetworkPrefix('6f');

      final privHex = HEX.encode(priv);
      tool.setPrivateKeyHex(privHex);

      out.add(
        HdDerivedAddress(
          path: path,
          addressLegacy: tool.getAddress(true),
          addressBech32: tool.getBech32Address(),
          addressTaproot: tool.getTaprootAddress(),
          privateKeyHex: tool.getPrivateKey(),
          privateKeyWif: tool.getWif(),
          privateKeyWifCompressed: tool.getWif(true),
          publicKeyHex: tool.getPubKey(),
          publicKeyHexCompressed: tool.getPubKey(compressed: true),
        ),
      );
    }

    return out;
  }

  static List<HdDerivedAddress> deriveBatchFromWatchOnly({
    required HdWatchOnlyExport watchOnly,
    int change = 0,
    int startIndex = 0,
    int count = 5,
  }) {
    final scheme = HdDerivationScheme.values.where((s) => s.name == watchOnly.scheme).cast<HdDerivationScheme?>().firstWhere(
          (s) => s != null,
          orElse: () => null,
        );
    if (scheme == null) {
      throw FormatException('Esquema watch-only inválido: ${watchOnly.scheme}');
    }

    final safeCount = count.clamp(1, 50);
    final accountPath = watchOnly.accountPath;
    final normalizedExtKey = _normalizeExtendedPublicKeyForBip32(
      watchOnly.extendedPublicKey,
      scheme: scheme,
      testnet: watchOnly.testnet,
    );

    final network = watchOnly.testnet ? _bip32Testnet : _bip32Mainnet;
    final accountNode = bip32.BIP32.fromBase58(normalizedExtKey, network);

    final tool = BitcoinTOOL();
    if (watchOnly.testnet) tool.setNetworkPrefix('6f');

    final out = <HdDerivedAddress>[];
    for (int i = 0; i < safeCount; i++) {
      final index = startIndex + i;
      final path = '$accountPath/$change/$index';

      final node = accountNode.derive(change).derive(index);
      final pubCompressed = HEX.encode(node.publicKey);
      final pubUncompressed = tool.uncompressPublicKeyHex(pubCompressed);

      out.add(
        HdDerivedAddress(
          path: path,
          addressLegacy: tool.getAddressFromPublicHex(
            pubCompressed,
            networkPrefix: watchOnly.testnet ? '6f' : '00',
          ),
          addressBech32: tool.getBech32AddressFromPublicKeyHex(
            pubCompressed,
            hrp: watchOnly.testnet ? 'tb' : 'bc',
          ),
          addressTaproot: tool.getTaprootAddressFromCompressedPublicKeyHex(
            pubCompressed,
            hrp: watchOnly.testnet ? 'tb' : 'bc',
          ),
          privateKeyHex: '',
          privateKeyWif: '',
          privateKeyWifCompressed: '',
          publicKeyHex: pubUncompressed,
          publicKeyHexCompressed: pubCompressed,
        ),
      );
    }

    return out;
  }

  static HdWatchOnlyExport deriveWatchOnly({
    required String mnemonic,
    String passphrase = '',
    HdDerivationScheme scheme = HdDerivationScheme.bip84,
    bool testnet = false,
    int account = 0,
  }) {
    final normalized = _normalizeMnemonic(mnemonic);
    if (!bip39.validateMnemonic(normalized)) {
      throw const FormatException('Mnemonic inválida (BIP39).');
    }

    final seed = _mnemonicToSeed(normalized, passphrase);
    final root = bip32.BIP32.fromSeed(seed);

    final coinType = testnet ? 1 : 0;
    final purpose = switch (scheme) {
      HdDerivationScheme.bip44 => 44,
      HdDerivationScheme.bip84 => 84,
      HdDerivationScheme.bip86 => 86,
    };

    final accountPath = "m/$purpose'/$coinType'/$account'";
    final accountNode = root.derivePath(accountPath);

    // bip32 retorna xpub/tpub em neutered().toBase58().
    final xpubOrTpub = accountNode.neutered().toBase58();

    final extendedPublicKey = switch (scheme) {
      HdDerivationScheme.bip84 => _convertXpubVersion(
          xpubOrTpub,
          toVersion: testnet ? _vpub : _zpub,
        ),
      HdDerivationScheme.bip44 => xpubOrTpub,
      HdDerivationScheme.bip86 => xpubOrTpub,
    };

    return HdWatchOnlyExport(
      version: 1,
      exportedAt: DateTime.now().toIso8601String(),
      scheme: scheme.name,
      testnet: testnet,
      accountPath: accountPath,
      extendedPublicKey: extendedPublicKey,
    );
  }

  static Uint8List _mnemonicToSeed(String mnemonic, String passphrase) {
    try {
      final seed = bip39.mnemonicToSeed(mnemonic, passphrase: passphrase);
      return seed;
    } catch (_) {
      // Fallback: versões antigas sem passphrase nomeada.
      return bip39.mnemonicToSeed(mnemonic);
    }
  }

  static String _normalizeMnemonic(String mnemonic) {
    return mnemonic.trim().toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).join(' ');
  }

  static String _normalizeExtendedPublicKeyForBip32(
    String extendedPublicKey, {
    required HdDerivationScheme scheme,
    required bool testnet,
  }) {
    final trimmed = extendedPublicKey.trim();
    if (trimmed.isEmpty) throw const FormatException('Extended key vazia.');

    // bip32 lib entende apenas xpub/tpub (version bytes padrão), então
    // convertemos zpub/vpub -> xpub/tpub quando necessário.
    final decoded = bs58check.decode(trimmed);
    if (decoded.length < 4) {
      throw const FormatException('Extended key inválida (curta demais).');
    }

    final ver = decoded.sublist(0, 4);
    final isXpub = _bytesEqual(ver, _xpub);
    final isTpub = _bytesEqual(ver, _tpub);
    final isZpub = _bytesEqual(ver, _zpub);
    final isVpub = _bytesEqual(ver, _vpub);

    if (testnet) {
      if (isTpub) return trimmed;
      if (scheme == HdDerivationScheme.bip84 && isVpub) {
        return _convertXpubVersion(trimmed, toVersion: _tpub);
      }
      if (isXpub || isZpub) {
        throw const FormatException('Extended key é mainnet, mas modo testnet está ativo.');
      }
    } else {
      if (isXpub) return trimmed;
      if (scheme == HdDerivationScheme.bip84 && isZpub) {
        return _convertXpubVersion(trimmed, toVersion: _xpub);
      }
      if (isTpub || isVpub) {
        throw const FormatException('Extended key é testnet, mas modo mainnet está ativo.');
      }
    }

    // Se não for um dos version bytes esperados, deixa o bip32 validar.
    return trimmed;
  }
}

final bip32.NetworkType _bip32Mainnet = bip32.NetworkType(
  wif: 0x80,
  bip32: bip32.Bip32Type(public: 0x0488b21e, private: 0x0488ade4),
);

final bip32.NetworkType _bip32Testnet = bip32.NetworkType(
  wif: 0xef,
  bip32: bip32.Bip32Type(public: 0x043587cf, private: 0x04358394),
);

final Uint8List _xpub = Uint8List.fromList([0x04, 0x88, 0xB2, 0x1E]);
final Uint8List _tpub = Uint8List.fromList([0x04, 0x35, 0x87, 0xCF]);
final Uint8List _zpub = Uint8List.fromList([0x04, 0xB2, 0x47, 0x46]);
final Uint8List _vpub = Uint8List.fromList([0x04, 0x5F, 0x1C, 0xF6]);

String _convertXpubVersion(String xpub, {required Uint8List toVersion}) {
  final decoded = bs58check.decode(xpub);
  if (decoded.length < 4) {
    throw const FormatException('Extended key inválida (curta demais).');
  }

  final out = Uint8List.fromList(decoded);
  out.setRange(0, 4, toVersion);
  return bs58check.encode(out);
}

bool _bytesEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
