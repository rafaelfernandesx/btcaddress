import 'package:btcaddress/bitcoin/tap_key.dart';
import 'package:btcaddress/btc_tool.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TapKeyGenerator é determinístico e gera private key válida', () {
    // Intervalos fixos para teste determinístico.
    final intervals = List<int>.generate(64, (i) => (i * 37) % 500 + 1);

    final a = TapKeyGenerator.fromIntervals(intervals, salt: 'teste');
    final b = TapKeyGenerator.fromIntervals(intervals, salt: 'teste');

    expect(a.seedText, b.seedText);
    expect(a.privateKeyHex, b.privateKeyHex);
    expect(a.privateKeyHex.length, 64);
    expect(a.seedText.startsWith('tap:'), isTrue);

    final btc = BitcoinTOOL();
    btc.setPrivateKeyHex(a.privateKeyHex);
    expect(btc.getAddress(true), isNotEmpty);
    expect(btc.getBech32Address(), isNotEmpty);
    expect(btc.getTaprootAddress(), isNotEmpty);
  });

  test('TapKeyGenerator exige mínimo de intervalos', () {
    expect(
      () => TapKeyGenerator.fromIntervals([1, 2, 3]),
      throwsFormatException,
    );
  });
}
