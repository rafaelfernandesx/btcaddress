import 'dart:typed_data';

import 'package:btcaddress/bitcoin/split_key.dart';
import 'package:btcaddress/btc_tool.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SplitKeyParts encode/decode com checksum', () {
    final a = Uint8List.fromList(List<int>.generate(32, (i) => i));
    final b = Uint8List.fromList(List<int>.generate(32, (i) => 255 - i));

    final parts = SplitKeyParts.fromBytes(a: a, b: b);

    final da = SplitKeyParts.decodePart(parts.partA);
    final db = SplitKeyParts.decodePart(parts.partB);

    expect(da, equals(a));
    expect(db, equals(b));
  });

  test('SplitKeyCombiner é determinístico e gera chave válida', () {
    final a = Uint8List.fromList(List<int>.filled(32, 0x11));
    final b = Uint8List.fromList(List<int>.filled(32, 0x22));
    final parts = SplitKeyParts.fromBytes(a: a, b: b);

    final m1 = SplitKeyCombiner.combine(partA: parts.partA, partB: parts.partB, salt: 'x');
    final m2 = SplitKeyCombiner.combine(partA: parts.partA, partB: parts.partB, salt: 'x');

    expect(m1.seedText, m2.seedText);
    expect(m1.privateKeyHex, m2.privateKeyHex);
    expect(m1.privateKeyHex.length, 64);
    expect(m1.seedText.startsWith('split:'), isTrue);

    final btc = BitcoinTOOL();
    btc.setPrivateKeyHex(m1.privateKeyHex);
    expect(btc.getAddress(true), isNotEmpty);
    expect(btc.getBech32Address(), isNotEmpty);
    expect(btc.getTaprootAddress(), isNotEmpty);
  });

  test('SplitKeyParts rejeita checksum inválido', () {
    final parts = SplitKeyParts.generate();
    final bad = '${parts.partA}x';
    expect(() => SplitKeyParts.decodePart(bad), throwsFormatException);
  });
}
