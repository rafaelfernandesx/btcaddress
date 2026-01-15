import 'dart:typed_data';

import 'package:btcaddress/btc_tool.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hex/hex.dart';

void main() {
  test('Bech32m encodes witness v1 program (BIP350 vector)', () {
    final btc = BitcoinTOOL();

    // witness program = x(G)
    const programHex = '79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798';
    final program = Uint8List.fromList(HEX.decode(programHex));

    final addr = btc.encodeSegwitAddress(
      witnessVersion: 1,
      program: program,
      hrp: 'bc',
    );

    // BIP350 test vector
    expect(addr, 'bc1p0xlxvlhemja6c4dqv22uapctqupfhlxm9h8z3k2e72q4k9hcz7vqzk5jj0');
  });
}
