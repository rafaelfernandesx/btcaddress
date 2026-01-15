import 'package:bip39/bip39.dart' as bip39;
import 'package:btcaddress/bitcoin/dice_mnemonic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DiceMnemonic gera mnemonic válida (12 palavras)', () {
    // 50 rolagens: padrão repetido.
    const rolls = '12345612345612345612345612345612345612345612345612';
    expect(rolls.length, 50);

    final m1 = DiceMnemonic.mnemonicFromDiceRolls(rolls, wordCount: 12);
    final m2 = DiceMnemonic.mnemonicFromDiceRolls(rolls, wordCount: 12);

    expect(m1, m2);
    expect(bip39.validateMnemonic(m1), isTrue);
    expect(m1.split(' '), hasLength(12));
  });

  test('DiceMnemonic exige quantidade mínima de rolagens', () {
    expect(
      () => DiceMnemonic.mnemonicFromDiceRolls('123', wordCount: 12),
      throwsFormatException,
    );
  });

  test('DiceMnemonic gera mnemonic válida (24 palavras)', () {
    final rolls = List.filled(99, '6').join();
    final m = DiceMnemonic.mnemonicFromDiceRolls(rolls, wordCount: 24);
    expect(bip39.validateMnemonic(m), isTrue);
    expect(m.split(' '), hasLength(24));
  });
}
