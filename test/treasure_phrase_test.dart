import 'package:btcaddress/bitcoin/treasure_phrase.dart';
import 'package:btcaddress/btc_tool.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TreasurePhrase: determinístico com mesma frase + seed', () {
    const phrase = 'uma frase longa e difícil 1234567890!@#';
    const seed = TreasurePhraseSeed(iterations: 200000, saltHex: '00112233445566778899aabbccddeeff');

    final a = TreasurePhraseGenerator.fromPhrase(phrase: phrase, seed: seed);
    final b = TreasurePhraseGenerator.fromPhrase(phrase: phrase, seed: seed);

    expect(a.seedText, seed.toSeedText());
    expect(a.privateKeyHex, b.privateKeyHex);
    expect(a.privateKeyHex.length, 64);

    final btc = BitcoinTOOL();
    btc.setPrivateKeyHex(a.privateKeyHex);
    expect(btc.getAddress(true), isNotEmpty);
    expect(btc.getBech32Address(), isNotEmpty);
    expect(btc.getTaprootAddress(), isNotEmpty);
  });

  test('TreasurePhraseSeed: parse/format e validações', () {
    final s = TreasurePhraseSeed.parse('treasure1:200000:0011223344556677');
    expect(s.iterations, 200000);
    expect(s.saltHex, '0011223344556677');
    expect(s.toSeedText(), 'treasure1:200000:0011223344556677');

    expect(() => TreasurePhraseSeed.parse('x:1:aa'), throwsFormatException);
    expect(() => TreasurePhraseSeed.parse('treasure1:9:aa'), throwsFormatException);
    expect(() => TreasurePhraseSeed.parse('treasure1:10000:zz'), throwsFormatException);
    expect(() => TreasurePhraseSeed.parse('treasure1:10000:00'), throwsFormatException);
  });

  test('TreasurePhrase: exige frase mínima', () {
    const seed = TreasurePhraseSeed(iterations: 200000, saltHex: '0011223344556677');
    expect(
      () => TreasurePhraseGenerator.fromPhrase(phrase: 'curta', seed: seed),
      throwsFormatException,
    );
  });
}
