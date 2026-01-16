import 'dart:typed_data';

import 'package:btcaddress/bitcoin/image_hash.dart';
import 'package:btcaddress/btc_tool.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ImageHash: determinístico com mesmos bytes+salt', () {
    final img = Uint8List.fromList(List<int>.generate(128, (i) => (i * 7) & 0xFF));

    final m1 = ImageHashGenerator.fromBytes(
      imageBytes: img,
      saltHex: '00112233445566778899aabbccddeeff',
    );
    final m2 = ImageHashGenerator.fromBytes(
      imageBytes: img,
      saltHex: '00112233445566778899aabbccddeeff',
    );

    expect(m1.seedText, m2.seedText);
    expect(m1.privateKeyHex, m2.privateKeyHex);
    expect(m1.privateKeyHex.length, 64);
  });

  test('ImageHash: fromSeedText reproduz material', () {
    final img = Uint8List.fromList(List<int>.generate(64, (i) => (255 - i) & 0xFF));

    final m1 = ImageHashGenerator.fromBytes(
      imageBytes: img,
      saltHex: 'deadbeefdeadbeefdeadbeefdeadbeef',
    );
    final m2 = ImageHashGenerator.fromSeedText(m1.seedText);

    expect(m2.seedText, m1.seedText);
    expect(m2.privateKeyHex, m1.privateKeyHex);

    final btc = BitcoinTOOL();
    btc.setPrivateKeyHex(m2.privateKeyHex);
    expect(btc.getAddress(true), isNotEmpty);
    expect(btc.getBech32Address(), isNotEmpty);
    expect(btc.getTaprootAddress(), isNotEmpty);
  });

  test('ImageHash: validações básicas', () {
    expect(
      () => ImageHashGenerator.fromBytes(imageBytes: Uint8List(0), saltHex: '00'),
      throwsFormatException,
    );
    expect(
      () => ImageHashGenerator.fromBytes(
        imageBytes: Uint8List.fromList([1, 2, 3]),
        saltHex: '',
      ),
      throwsFormatException,
    );
    expect(
      () => ImageHashGenerator.fromSeedText('qrmix1:00:aaaa'),
      throwsFormatException,
    );
  });
}
