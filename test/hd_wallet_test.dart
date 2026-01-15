import 'package:bs58check/bs58check.dart' as bs58check;
import 'package:btcaddress/bitcoin/hd_wallet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BIP84 vector: abandon...about -> first receiving address', () {
    const mnemonic = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

    final addrs = HdWalletDeriver.deriveBatch(
      mnemonic: mnemonic,
      scheme: HdDerivationScheme.bip84,
      testnet: false,
      account: 0,
      change: 0,
      startIndex: 0,
      count: 1,
    );

    expect(addrs, hasLength(1));
    expect(addrs.first.addressBech32, 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu');
  });

  test('BIP84 watch-only gera zpub (version bytes)', () {
    const mnemonic = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

    final export = HdWalletDeriver.deriveWatchOnly(
      mnemonic: mnemonic,
      scheme: HdDerivationScheme.bip84,
      testnet: false,
      account: 0,
    );

    expect(export.extendedPublicKey.startsWith('zpub'), isTrue);

    final raw = bs58check.decode(export.extendedPublicKey);
    expect(raw.sublist(0, 4), equals([0x04, 0xB2, 0x47, 0x46]));
  });

  test('BIP84 watch-only deriva endereços (sem mnemonic)', () {
    const mnemonic = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

    final export = HdWalletDeriver.deriveWatchOnly(
      mnemonic: mnemonic,
      scheme: HdDerivationScheme.bip84,
      testnet: false,
      account: 0,
    );

    final addrs = HdWalletDeriver.deriveBatchFromWatchOnly(
      watchOnly: export,
      change: 0,
      startIndex: 0,
      count: 1,
    );

    expect(addrs, hasLength(1));
    expect(addrs.first.addressBech32, 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu');
    expect(addrs.first.privateKeyHex, isEmpty);
  });
}
