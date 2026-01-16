import 'dart:math';

import 'package:btcaddress/bitcoin/qr_mix.dart';
import 'package:btcaddress/btc_tool.dart';
import 'package:btcaddress/theme/app_theme.dart';
import 'package:btcaddress/widgets/copyable_textfield.dart';
import 'package:btcaddress/widgets/qr_code_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class QrMixScreen extends StatefulWidget {
  const QrMixScreen({super.key});

  @override
  State<QrMixScreen> createState() => _QrMixScreenState();
}

class _QrMixScreenState extends State<QrMixScreen> {
  final _textController = TextEditingController();
  final _saltHexController = TextEditingController();

  final _seedController = TextEditingController();
  final _privHexController = TextEditingController();
  final _legacyController = TextEditingController();
  final _compressedController = TextEditingController();
  final _bech32Controller = TextEditingController();
  final _taprootController = TextEditingController();

  bool _testnet = false;
  bool _showSecret = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _generateSalt();
  }

  @override
  void dispose() {
    _textController.dispose();
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

  Future<void> _pasteText() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (text.trim().isEmpty) return;
    setState(() {
      _textController.text = text;
      _error = '';
      _clearResult();
    });
  }

  void _mix() {
    try {
      final material = QrMixGenerator.fromText(
        text: _textController.text,
        saltHex: _saltHexController.text,
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
        title: const Text('QR-Mix (texto + salt)'),
        actions: [
          IconButton(
            tooltip: 'Gerar novo salt',
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
                    'Mistura por texto/QR',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Cole qualquer texto (por exemplo, o conteúdo de um QR) e misture com um salt local (aleatório) para gerar uma private key HEX válida. Para recuperar depois, guarde a seed (texto) gerada.',
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
                  const SizedBox(height: 12),
                  TextField(
                    controller: _textController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Texto (do QR ou manual)',
                      prefixIcon: const Icon(Icons.text_fields),
                      suffixIcon: IconButton(
                        tooltip: 'Colar',
                        icon: const Icon(Icons.content_paste),
                        onPressed: _pasteText,
                      ),
                    ),
                    onChanged: (_) => _clearResult(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _saltHexController,
                    decoration: const InputDecoration(
                      labelText: 'Salt local (HEX)',
                      prefixIcon: Icon(Icons.lock_outline),
                      helperText: 'Gerado automaticamente; você pode trocar se quiser. Guarde junto da seed.',
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F]')),
                    ],
                    onChanged: (_) => _clearResult(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: _mix,
                          icon: const Icon(Icons.qr_code_2_outlined),
                          label: const Text('Misturar e gerar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _textController.clear();
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
                          tooltip: 'Mostrar QR da seed',
                          icon: const Icon(Icons.qr_code),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => QRCodeDialog(
                                data: _seedController.text,
                                title: 'Seed (QR-Mix)',
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    CopyableTextField(
                      controller: _seedController,
                      label: 'Seed (texto) — guarde para recuperar',
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
