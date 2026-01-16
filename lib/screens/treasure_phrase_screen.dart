import 'dart:math';

import 'package:btcaddress/bitcoin/treasure_phrase.dart';
import 'package:btcaddress/btc_tool.dart';
import 'package:btcaddress/theme/app_theme.dart';
import 'package:btcaddress/widgets/copyable_textfield.dart';
import 'package:btcaddress/widgets/qr_code_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TreasurePhraseScreen extends StatefulWidget {
  const TreasurePhraseScreen({super.key});

  @override
  State<TreasurePhraseScreen> createState() => _TreasurePhraseScreenState();
}

class _TreasurePhraseScreenState extends State<TreasurePhraseScreen> {
  final _phraseController = TextEditingController();
  final _saltHexController = TextEditingController();

  final _seedController = TextEditingController();
  final _privHexController = TextEditingController();
  final _legacyController = TextEditingController();
  final _compressedController = TextEditingController();
  final _bech32Controller = TextEditingController();
  final _taprootController = TextEditingController();

  bool _testnet = false;
  bool _showSecret = false;
  bool _showPhrase = false;
  String _error = '';

  int _iterations = 200000;

  @override
  void initState() {
    super.initState();
    _generateSalt();
  }

  @override
  void dispose() {
    _phraseController.dispose();
    _saltHexController.dispose();
    _seedController.dispose();
    _privHexController.dispose();
    _legacyController.dispose();
    _compressedController.dispose();
    _bech32Controller.dispose();
    _taprootController.dispose();
    super.dispose();
  }

  void _clearResult() {
    _seedController.clear();
    _privHexController.clear();
    _legacyController.clear();
    _compressedController.clear();
    _bech32Controller.clear();
    _taprootController.clear();
  }

  void _generateSalt() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    setState(() {
      _saltHexController.text = hex;
      _error = '';
      _clearResult();
    });
  }

  void _generate() {
    try {
      final seed = TreasurePhraseSeed(
        iterations: _iterations,
        saltHex: _saltHexController.text.trim(),
      );

      final material = TreasurePhraseGenerator.fromPhrase(
        phrase: _phraseController.text,
        seed: seed,
      );

      final btc = BitcoinTOOL();
      if (_testnet) btc.setNetworkPrefix('6f');
      btc.setPrivateKeyHex(material.privateKeyHex);

      setState(() {
        _seedController.text = material.seedText;
        _privHexController.text = material.privateKeyHex;
        _legacyController.text = btc.getAddress(false);
        _compressedController.text = btc.getAddress(true);
        _bech32Controller.text = btc.getBech32Address();
        _taprootController.text = btc.getTaprootAddress();
        _error = '';
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _clearResult();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Treasure Phrase (KDF)'),
        actions: [
          IconButton(
            tooltip: 'Novo salt',
            icon: const Icon(Icons.refresh),
            onPressed: _generateSalt,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Frase longa + KDF (PBKDF2-SHA256)',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Digite uma frase longa. O app usa PBKDF2-HMAC-SHA256 com salt e iterações para derivar uma chave. A seed exibida NÃO contém a frase — ela serve como “metadados” (salt + custo).',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Switch.adaptive(
                        value: _testnet,
                        onChanged: (v) => setState(() => _testnet = v),
                      ),
                      const SizedBox(width: 8),
                      Text(_testnet ? 'testnet' : 'mainnet'),
                      const Spacer(),
                      Switch.adaptive(
                        value: _showSecret,
                        onChanged: (v) => setState(() => _showSecret = v),
                      ),
                      const SizedBox(width: 8),
                      const Text('Mostrar HEX'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _showPhrase,
                    onChanged: (v) => setState(() => _showPhrase = v),
                    title: const Text('Mostrar frase na tela'),
                    subtitle: const Text('Cuidado com prints/gravações.'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _phraseController,
                    obscureText: !_showPhrase,
                    decoration: const InputDecoration(
                      labelText: 'Frase (segredo)',
                      prefixIcon: Icon(Icons.password_outlined),
                      helperText: 'Use uma frase longa e difícil. Sem BIP39.',
                    ),
                    onChanged: (_) => _clearResult(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _saltHexController,
                    decoration: const InputDecoration(
                      labelText: 'Salt (HEX)',
                      prefixIcon: Icon(Icons.lock_outline),
                      helperText: 'Guarde junto do custo (iterações). Não guarda a frase.',
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F]')),
                    ],
                    onChanged: (_) => _clearResult(),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Custo (iterações): $_iterations',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  Slider(
                    value: _iterations.toDouble(),
                    min: 10000,
                    max: 600000,
                    divisions: 59,
                    label: '$_iterations',
                    onChanged: (v) => setState(() {
                      _iterations = (v / 1000).round() * 1000;
                      _clearResult();
                    }),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: _generate,
                          icon: const Icon(Icons.auto_fix_high_outlined),
                          label: const Text('Derivar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _phraseController.clear();
                            _generateSalt();
                            _error = '';
                            _clearResult();
                          });
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Limpar'),
                      ),
                    ],
                  ),
                  if (_error.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_seedController.text.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Resultado',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Mostrar QR da seed (metadados)',
                          icon: const Icon(Icons.qr_code),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => QRCodeDialog(
                                data: _seedController.text,
                                title: 'Seed (Treasure)',
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    CopyableTextField(
                      controller: _seedController,
                      label: 'Seed (texto) — salt + iterações (não contém frase)',
                      prefixIcon: Icons.text_snippet_outlined,
                    ),
                    const SizedBox(height: 12),
                    if (_showSecret)
                      CopyableTextField(
                        controller: _privHexController,
                        label: 'PrivateKey (HEX)',
                        prefixIcon: Icons.vpn_key_outlined,
                      )
                    else
                      const Text('HEX oculto (ative “Mostrar HEX”).'),
                    const SizedBox(height: 12),
                    CopyableTextField(
                      controller: _legacyController,
                      label: 'P2PKH (legacy)',
                      prefixIcon: Icons.account_balance_wallet_outlined,
                    ),
                    const SizedBox(height: 12),
                    CopyableTextField(
                      controller: _compressedController,
                      label: 'P2PKH (compressed)',
                      prefixIcon: Icons.compress,
                    ),
                    const SizedBox(height: 12),
                    CopyableTextField(
                      controller: _bech32Controller,
                      label: 'Bech32 (P2WPKH)',
                      prefixIcon: Icons.qr_code_2_outlined,
                    ),
                    const SizedBox(height: 12),
                    CopyableTextField(
                      controller: _taprootController,
                      label: 'Taproot (P2TR)',
                      prefixIcon: Icons.bolt_outlined,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
