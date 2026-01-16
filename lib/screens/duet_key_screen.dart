import 'package:btcaddress/bitcoin/duet_key.dart';
import 'package:btcaddress/btc_tool.dart';
import 'package:btcaddress/theme/app_theme.dart';
import 'package:btcaddress/widgets/copyable_textfield.dart';
import 'package:btcaddress/widgets/qr_code_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DuetKeyScreen extends StatefulWidget {
  const DuetKeyScreen({super.key});

  @override
  State<DuetKeyScreen> createState() => _DuetKeyScreenState();
}

class _DuetKeyScreenState extends State<DuetKeyScreen> {
  final _saltController = TextEditingController();

  final _partAController = TextEditingController();
  final _partBController = TextEditingController();

  final _seedController = TextEditingController();
  final _privHexController = TextEditingController();
  final _legacyController = TextEditingController();
  final _compressedController = TextEditingController();
  final _bech32Controller = TextEditingController();
  final _taprootController = TextEditingController();

  bool _testnet = false;
  bool _showSecret = false;

  // Captura por timing.
  final List<int> _tapTimesUs = [];
  int _targetIntervals = 64;

  String _error = '';

  @override
  void dispose() {
    _saltController.dispose();
    _partAController.dispose();
    _partBController.dispose();
    _seedController.dispose();
    _privHexController.dispose();
    _legacyController.dispose();
    _compressedController.dispose();
    _bech32Controller.dispose();
    _taprootController.dispose();
    super.dispose();
  }

  int get _intervalCount => (_tapTimesUs.length - 1).clamp(0, 1 << 31);

  List<int> _intervalsMs() {
    if (_tapTimesUs.length < 2) return const [];
    final out = <int>[];
    for (int i = 1; i < _tapTimesUs.length; i++) {
      final deltaUs = _tapTimesUs[i] - _tapTimesUs[i - 1];
      final ms = (deltaUs / 1000).round().clamp(0, 65535);
      out.add(ms);
    }
    return out;
  }

  void _clearResult() {
    _seedController.clear();
    _privHexController.clear();
    _legacyController.clear();
    _compressedController.clear();
    _bech32Controller.clear();
    _taprootController.clear();
  }

  void _resetCapture() {
    setState(() {
      _tapTimesUs.clear();
      _error = '';
    });
  }

  void _tap() {
    HapticFeedback.selectionClick();
    final now = DateTime.now().microsecondsSinceEpoch;
    setState(() {
      _tapTimesUs.add(now);
      _error = '';
    });
  }

  void _generatePartA() {
    try {
      final intervals = _intervalsMs().take(_targetIntervals).toList();
      final salt = _saltController.text;
      final partA = DuetKey.partAFromIntervals(intervals, salt: salt);
      setState(() {
        _partAController.text = partA;
        _error = '';
        _clearResult();
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    }
  }

  void _generatePartB() {
    try {
      final intervals = _intervalsMs().take(_targetIntervals).toList();
      final salt = _saltController.text;
      final partB = DuetKey.partBFromIntervals(intervals, salt: salt);
      setState(() {
        _partBController.text = partB;
        _error = '';
        _clearResult();
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    }
  }

  void _combine() {
    try {
      final salt = _saltController.text;
      final material = DuetKey.combine(
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

  @override
  Widget build(BuildContext context) {
    final intervals = _intervalCount;
    final canGenerate = intervals >= 16;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dueto (2 pessoas)'),
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
                    'Como funciona',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pessoa 1 gera a Parte A e Pessoa 2 gera a Parte B (cada uma com seu ritmo de taps). Depois você combina A+B para obter a seed texto e a private key HEX.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Intervalos: $intervals/$_targetIntervals',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                      Switch.adaptive(
                        value: _testnet,
                        onChanged: (v) => setState(() => _testnet = v),
                      ),
                      const SizedBox(width: 8),
                      Text(_testnet ? 'testnet' : 'mainnet'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    value: _targetIntervals.toDouble(),
                    min: 16,
                    max: 256,
                    divisions: 15,
                    label: '$_targetIntervals',
                    onChanged: (v) => setState(() => _targetIntervals = v.round()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _saltController,
                    decoration: const InputDecoration(
                      labelText: 'Sal (opcional)',
                      prefixIcon: Icon(Icons.lock_outline),
                      helperText: 'Opcional: se usado, precisa ser o mesmo no A e no B.',
                    ),
                    onChanged: (_) => _clearResult(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                          ),
                          onPressed: _tap,
                          icon: const Icon(Icons.touch_app_outlined),
                          label: const Text('TAP'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: _resetCapture,
                        icon: const Icon(Icons.restart_alt_outlined),
                        label: const Text('Zerar taps'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: canGenerate ? _generatePartA : null,
                          icon: const Icon(Icons.looks_one_outlined),
                          label: const Text('Gerar Parte A'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: canGenerate ? _generatePartB : null,
                          icon: const Icon(Icons.looks_two_outlined),
                          label: const Text('Gerar Parte B'),
                        ),
                      ),
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
                  if (_error.isNotEmpty) ...[
                    const SizedBox(height: 8),
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
                        child: FilledButton.icon(
                          onPressed: _combine,
                          icon: const Icon(Icons.merge_type_outlined),
                          label: const Text('Combinar A+B'),
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
                            _resetCapture();
                          });
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Limpar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'QR da Parte A',
                        icon: const Icon(Icons.qr_code_2_outlined),
                        onPressed: _partAController.text.trim().isEmpty
                            ? null
                            : () {
                                showDialog(
                                  context: context,
                                  builder: (_) => QRCodeDialog(
                                    data: _partAController.text.trim(),
                                    title: 'Parte A',
                                  ),
                                );
                              },
                      ),
                      IconButton(
                        tooltip: 'QR da Parte B',
                        icon: const Icon(Icons.qr_code_outlined),
                        onPressed: _partBController.text.trim().isEmpty
                            ? null
                            : () {
                                showDialog(
                                  context: context,
                                  builder: (_) => QRCodeDialog(
                                    data: _partBController.text.trim(),
                                    title: 'Parte B',
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
