import 'package:btcaddress/bitcoin/shake_key.dart';
import 'package:btcaddress/btc_tool.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ShakeKey: determinístico com mesmas amostras + salt', () {
    final samples = List<ShakeSample>.generate(
      80,
      (i) => ShakeSample(
        x: (i % 7) * 0.01,
        y: (i % 11) * -0.02,
        z: 9.8 + (i % 3) * 0.005,
      ),
    );

    final a = ShakeKeyGenerator.fromSamples(samples, salt: 'abc', minSamples: 64);
    final b = ShakeKeyGenerator.fromSamples(samples, salt: 'abc', minSamples: 64);

    expect(a.seedText, b.seedText);
    expect(a.privateKeyHex, b.privateKeyHex);
    expect(a.privateKeyHex.length, 64);

    final btc = BitcoinTOOL();
    btc.setPrivateKeyHex(a.privateKeyHex);
    expect(btc.getAddress(true), isNotEmpty);
    expect(btc.getBech32Address(), isNotEmpty);
    expect(btc.getTaprootAddress(), isNotEmpty);
  });

  test('ShakeKey: exige amostras mínimas', () {
    final samples = List<ShakeSample>.generate(
      10,
      (i) => ShakeSample(x: i.toDouble(), y: 0, z: 0),
    );

    expect(
      () => ShakeKeyGenerator.fromSamples(samples, minSamples: 64),
      throwsFormatException,
    );
  });
}
