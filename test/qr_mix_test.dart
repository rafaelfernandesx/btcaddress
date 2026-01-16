import 'package:btcaddress/bitcoin/qr_mix.dart';
import 'package:btcaddress/btc_tool.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('QR-Mix: determinístico com mesmo texto+salt', () {
    final m1 = QrMixGenerator.fromText(
      text: 'hello world',
      saltHex: '00112233445566778899aabbccddeeff',
    );
    final m2 = QrMixGenerator.fromText(
      text: 'hello world',
      saltHex: '00112233445566778899aabbccddeeff',
    );

    expect(m1.privateKeyHex, m2.privateKeyHex);
    expect(m1.privateKeyHex.length, 64);
    expect(m1.seedText, m2.seedText);
  });

  test('QR-Mix: fromSeedText reproduz material', () {
    final m1 = QrMixGenerator.fromText(
      text: 'conteudo-qr',
      saltHex: 'deadbeefdeadbeefdeadbeefdeadbeef',
    );
    final m2 = QrMixGenerator.fromSeedText(m1.seedText);

    expect(m2.privateKeyHex, m1.privateKeyHex);
    expect(m2.seedText, m1.seedText);

    final btc = BitcoinTOOL();
    btc.setPrivateKeyHex(m2.privateKeyHex);
    expect(btc.getAddress(true), isNotEmpty);
    expect(btc.getBech32Address(), isNotEmpty);
    expect(btc.getTaprootAddress(), isNotEmpty);
  });

  test('QR-Mix: validações básicas', () {
    expect(
      () => QrMixGenerator.fromText(text: '   ', saltHex: '00'),
      throwsFormatException,
    );
    expect(
      () => QrMixGenerator.fromText(text: 'x', saltHex: 'zz'),
      throwsFormatException,
    );
    expect(
      () => QrMixGenerator.fromSeedText('tap:abc'),
      throwsFormatException,
    );
  });
}
