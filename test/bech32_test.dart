import 'package:btcaddress/btc_tool.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Bech32 P2WPKH matches BIP173 example (pubkey G)', () {
    final btc = BitcoinTOOL();

    // Private key = 1 -> pubkey = generator point (G).
    btc.setPrivateKeyHex('1'.padLeft(64, '0'));

    final address = btc.getBech32Address(hrp: 'bc');

    // BIP173 Examples: Mainnet P2WPKH for pubkey
    // 0279BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798
    expect(address, 'bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4');
  });
}
