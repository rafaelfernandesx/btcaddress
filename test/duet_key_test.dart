import 'package:btcaddress/bitcoin/duet_key.dart';
import 'package:btcaddress/btc_tool.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DuetKey gera partes diferentes para A e B e combina em chave válida', () {
    final intervals = List<int>.generate(64, (i) => (i * 53) % 700 + 1);

    final partA = DuetKey.partAFromIntervals(intervals, salt: 's');
    final partB = DuetKey.partBFromIntervals(intervals, salt: 's');

    expect(partA, isNotEmpty);
    expect(partB, isNotEmpty);
    expect(partA.startsWith('sk1A:'), isTrue);
    expect(partB.startsWith('sk1B:'), isTrue);
    expect(partA == partB, isFalse);

    final material = DuetKey.combine(partA: partA, partB: partB, salt: 's');
    expect(material.seedText.startsWith('split:'), isTrue);
    expect(material.privateKeyHex.length, 64);

    final btc = BitcoinTOOL()..setPrivateKeyHex(material.privateKeyHex);
    expect(btc.getAddress(true), isNotEmpty);
    expect(btc.getBech32Address(), isNotEmpty);
    expect(btc.getTaprootAddress(), isNotEmpty);
  });
}
