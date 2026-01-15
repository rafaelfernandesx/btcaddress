import 'dart:typed_data';

import 'package:bip32/bip32.dart' as bip32;
import 'package:bip39/bip39.dart' as bip39;
import 'package:hex/hex.dart';

import '../btc_tool.dart';

enum HdDerivationScheme {
  bip44,
  bip84,
  bip86,
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
}
