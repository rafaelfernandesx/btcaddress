import 'package:btcaddress/bitcoin/split_key.dart';
import 'package:btcaddress/btc_tool.dart';
import 'package:btcaddress/theme/app_theme.dart';
import 'package:btcaddress/widgets/copyable_textfield.dart';
import 'package:btcaddress/widgets/qr_code_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SplitKeyScreen extends StatefulWidget {
  const SplitKeyScreen({super.key});

  @override
  State<SplitKeyScreen> createState() => _SplitKeyScreenState();
}

class _SplitKeyScreenState extends State<SplitKeyScreen> {
  final _partAController = TextEditingController();
  final _partBController = TextEditingController();
  final _saltController = TextEditingController();

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
  void dispose() {
    _partAController.dispose();
    _partBController.dispose();
    _saltController.dispose();
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

  void _generateParts() {
    final parts = SplitKeyParts.generate();
    setState(() {
      _partAController.text = parts.partA;
      _partBController.text = parts.partB;
      _error = '';
      _clearResult();
    });
  }

  Future<void> _pasteTo(TextEditingController c) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) return;
    setState(() {
      c.text = text;
      _error = '';
      _clearResult();
    });
  }

  void _combine() {
    try {
      final salt = _saltController.text;
      final material = SplitKeyCombiner.combine(
        partA: _partAController.text,
        partB: _partBController.text,
        salt: salt,
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
        title: const Text('SplitKey (2 partes)'),
        actions: [
          IconButton(
            tooltip: 'Gerar novas partes',
            icon: const Icon(Icons.refresh),
            onPressed: _generateParts,
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
                    'Partes',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Gere duas partes (A e B) e guarde separadamente. Para recuperar a carteira, cole as duas e clique em “Combinar”.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _generateParts,
                      icon: const Icon(Icons.call_split_outlined),
                      label: const Text('Gerar Partes A/B'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _partAController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Parte A (sk1A:...)',
                      prefixIcon: const Icon(Icons.looks_one_outlined),
                      suffixIcon: IconButton(
                        tooltip: 'Colar',
                        icon: const Icon(Icons.content_paste),
                        onPressed: () => _pasteTo(_partAController),
                      ),
                    ),
                    onChanged: (_) => _clearResult(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _partBController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Parte B (sk1B:...)',
                      prefixIcon: const Icon(Icons.looks_two_outlined),
                      suffixIcon: IconButton(
                        tooltip: 'Colar',
                        icon: const Icon(Icons.content_paste),
                        onPressed: () => _pasteTo(_partBController),
                      ),
                    ),
                    onChanged: (_) => _clearResult(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _saltController,
                          decoration: const InputDecoration(
                            labelText: 'Sal (opcional)',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                          onChanged: (_) => _clearResult(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Switch.adaptive(
                        value: _testnet,
                        onChanged: (v) => setState(() => _testnet = v),
                      ),
                      const SizedBox(width: 8),
                      Text(_testnet ? 'testnet' : 'mainnet'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _showSecret,
                    onChanged: (v) => setState(() => _showSecret = v),
                    title: const Text('Mostrar HEX (private key) na tela'),
                    subtitle: const Text('Cuidado com prints/gravações.'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _combine,
                          icon: const Icon(Icons.merge_type_outlined),
                          label: const Text('Combinar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _partAController.clear();
                            _partBController.clear();
                            _saltController.clear();
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
                    Text(
                      'Resultado',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    CopyableTextField(
                      controller: _seedController,
                      label: 'Seed (texto)',
                      prefixIcon: Icons.text_fields,
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
                      controller: _compressedController,
                      label: 'Comprimido',
                      prefixIcon: Icons.account_balance_wallet,
                    ),
                    const SizedBox(height: 12),
                    CopyableTextField(
                      controller: _legacyController,
                      label: 'Legacy',
                      prefixIcon: Icons.account_balance_wallet_outlined,
                    ),
                    const SizedBox(height: 12),
                    CopyableTextField(
                      controller: _bech32Controller,
                      label: 'Bech32',
                      prefixIcon: Icons.qr_code,
                    ),
                    const SizedBox(height: 12),
                    CopyableTextField(
                      controller: _taprootController,
                      label: 'Taproot',
                      prefixIcon: Icons.bolt_outlined,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'QR da seed',
                          icon: const Icon(Icons.qr_code_2_outlined),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => QRCodeDialog(
                                data: _seedController.text,
                                title: 'Seed (SplitKey)',
                              ),
                            );
                          },
                        ),
                        if (_showSecret)
                          IconButton(
                            tooltip: 'QR da private key',
                            icon: const Icon(Icons.qr_code_outlined),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (_) => QRCodeDialog(
                                  data: _privHexController.text,
                                  title: 'PrivateKey (HEX)',
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
