import 'package:btcaddress/bitcoin/tap_key.dart';
import 'package:btcaddress/btc_tool.dart';
import 'package:btcaddress/theme/app_theme.dart';
import 'package:btcaddress/widgets/copyable_textfield.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TapKeyScreen extends StatefulWidget {
  const TapKeyScreen({super.key});

  @override
  State<TapKeyScreen> createState() => _TapKeyScreenState();
}

class _TapKeyScreenState extends State<TapKeyScreen> {
  final _saltController = TextEditingController();

  final _seedController = TextEditingController();
  final _privHexController = TextEditingController();
  final _legacyController = TextEditingController();
  final _compressedController = TextEditingController();
  final _bech32Controller = TextEditingController();
  final _taprootController = TextEditingController();

  final List<int> _tapTimesUs = [];

  int _targetIntervals = 64;
  bool _testnet = false;
  bool _showSecret = false;

  String _error = '';

  @override
  void dispose() {
    _saltController.dispose();
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

  void _clear() {
    setState(() {
      _tapTimesUs.clear();
      _error = '';
      _seedController.clear();
      _privHexController.clear();
      _legacyController.clear();
      _compressedController.clear();
      _bech32Controller.clear();
      _taprootController.clear();
    });
  }

  void _tap() {
    HapticFeedback.selectionClick();
    final now = DateTime.now().microsecondsSinceEpoch;
    setState(() {
      _tapTimesUs.add(now);
      _error = '';
    });

    if (_intervalCount >= _targetIntervals) {
      _generate();
    }
  }

  void _generate() {
    try {
      final intervals = _intervalsMs();
      final salt = _saltController.text;

      final material = TapKeyGenerator.fromIntervals(
        intervals.take(_targetIntervals).toList(),
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
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final intervals = _intervalCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('TapKey (seed + HEX)'),
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
                    'Geração por ritmo',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Toque repetidamente para gerar entropia (tempo entre taps). Ao atingir a meta, o app gera uma seed em texto e uma private key HEX válida.',
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
                      helperText: 'Pode ser uma frase curta para aumentar o espaço de busca. Não é BIP39.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            backgroundColor: AppTheme.primaryColor,
                          ),
                          onPressed: _tap,
                          icon: const Icon(Icons.touch_app_outlined),
                          label: const Text('TAP'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: _clear,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Limpar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: intervals >= 16 ? _generate : null,
                          icon: const Icon(Icons.auto_fix_high_outlined),
                          label: const Text('Gerar agora'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: _showSecret,
                          onChanged: (v) => setState(() => _showSecret = v),
                          title: const Text('Mostrar HEX'),
                          subtitle: const Text('Cuidado ao printar tela.'),
                        ),
                      ),
                    ],
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
                      controller: _legacyController,
                      label: 'Legacy',
                      prefixIcon: Icons.account_balance_wallet_outlined,
                    ),
                    const SizedBox(height: 12),
                    CopyableTextField(
                      controller: _compressedController,
                      label: 'Comprimido',
                      prefixIcon: Icons.account_balance_wallet,
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
