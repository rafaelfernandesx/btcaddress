import 'dart:typed_data';

import 'package:btcaddress/bitcoin/audio_key.dart';
import 'package:btcaddress/btc_tool.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AudioKey: determinístico com mesmos bytes+salt', () {
    final audio = Uint8List.fromList(List<int>.generate(256, (i) => (i * 13) & 0xFF));

    final m1 = AudioKeyGenerator.fromBytes(
      audioBytes: audio,
      saltHex: '00112233445566778899aabbccddeeff',
    );
    final m2 = AudioKeyGenerator.fromBytes(
      audioBytes: audio,
      saltHex: '00112233445566778899aabbccddeeff',
    );

    expect(m1.seedText, m2.seedText);
    expect(m1.privateKeyHex, m2.privateKeyHex);
    expect(m1.privateKeyHex.length, 64);
  });

  test('AudioKey: fromSeedText reproduz material', () {
    final audio = Uint8List.fromList(List<int>.generate(64, (i) => (255 - i) & 0xFF));

    final m1 = AudioKeyGenerator.fromBytes(
      audioBytes: audio,
      saltHex: 'deadbeefdeadbeefdeadbeefdeadbeef',
    );
    final m2 = AudioKeyGenerator.fromSeedText(m1.seedText);

    expect(m2.seedText, m1.seedText);
    expect(m2.privateKeyHex, m1.privateKeyHex);

    final btc = BitcoinTOOL();
    btc.setPrivateKeyHex(m2.privateKeyHex);
    expect(btc.getAddress(true), isNotEmpty);
    expect(btc.getBech32Address(), isNotEmpty);
    expect(btc.getTaprootAddress(), isNotEmpty);
  });

  test('AudioKey: validações básicas', () {
    expect(
      () => AudioKeyGenerator.fromBytes(audioBytes: Uint8List(0), saltHex: '00'),
      throwsFormatException,
    );
    expect(
      () => AudioKeyGenerator.fromBytes(
        audioBytes: Uint8List.fromList([1, 2, 3]),
        saltHex: '',
      ),
      throwsFormatException,
    );
    expect(
      () => AudioKeyGenerator.fromSeedText('img1:00:aaaa'),
      throwsFormatException,
    );
  });
}
