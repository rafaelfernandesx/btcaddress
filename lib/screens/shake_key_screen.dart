import 'dart:async';

import 'package:btcaddress/bitcoin/shake_key.dart';
import 'package:btcaddress/btc_tool.dart';
import 'package:btcaddress/theme/app_theme.dart';
import 'package:btcaddress/widgets/copyable_textfield.dart';
import 'package:btcaddress/widgets/qr_code_dialog.dart';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

class ShakeKeyScreen extends StatefulWidget {
  const ShakeKeyScreen({super.key});

  @override
  State<ShakeKeyScreen> createState() => _ShakeKeyScreenState();
}

class _ShakeKeyScreenState extends State<ShakeKeyScreen> {
  final _saltController = TextEditingController();

  final _seedController = TextEditingController();
  final _privHexController = TextEditingController();
  final _legacyController = TextEditingController();
  final _compressedController = TextEditingController();
  final _bech32Controller = TextEditingController();
  final _taprootController = TextEditingController();

  final List<ShakeSample> _samples = [];

  StreamSubscription<AccelerometerEvent>? _sub;
  Timer? _timer;

  bool _isCollecting = false;
  bool _testnet = false;
  bool _showSecret = false;

  int _durationSeconds = 6;
  int _minSamples = 64;

  DateTime? _startedAt;
  String _error = '';

  @override
  void dispose() {
    _stopCollecting();
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

  Future<void> _startCollecting() async {
    _stopCollecting();

    setState(() {
      _samples.clear();
      _error = '';
      _clearResult();
      _isCollecting = true;
      _startedAt = DateTime.now();
    });

    _sub = accelerometerEventStream().listen(
      (event) {
        if (!_isCollecting) return;
        _samples.add(ShakeSample(x: event.x, y: event.y, z: event.z));
        if (_samples.length % 8 == 0 && mounted) {
          setState(() {});
        }
      },
      onError: (e) {
        if (!mounted) return;
        setState(() {
          _error = e.toString();
          _isCollecting = false;
        });
      },
    );

    _timer = Timer(Duration(seconds: _durationSeconds), () {
      _stopCollecting();
      _generate();
    });
  }

  void _stopCollecting() {
    _timer?.cancel();
    _timer = null;
    _sub?.cancel();
    _sub = null;

    if (_isCollecting && mounted) {
      setState(() {
        _isCollecting = false;
      });
    } else {
      _isCollecting = false;
    }
  }

  void _generate() {
    try {
      final material = ShakeKeyGenerator.fromSamples(
        List<ShakeSample>.from(_samples),
        salt: _saltController.text,
        minSamples: _minSamples,
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

  double get _progress {
    final start = _startedAt;
    if (!_isCollecting || start == null) return 0;
    final elapsedMs = DateTime.now().difference(start).inMilliseconds;
    final totalMs = (_durationSeconds * 1000).clamp(1, 1 << 31);
    return (elapsedMs / totalMs).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final samplesCount = _samples.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ShakeKey (sensores)'),
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
                    'Agite para gerar entropia',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'O app coleta amostras do acelerômetro por alguns segundos, quantiza e faz hash para gerar uma private key HEX válida (não é BIP39).',
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
                  LinearProgressIndicator(
                    value: _isCollecting ? _progress : null,
                    minHeight: 6,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isCollecting ? 'Coletando… amostras: $samplesCount' : 'Pronto. Amostras coletadas: $samplesCount',
                    style: Theme.of(context).textTheme.bodySmall,
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
                          onPressed: _isCollecting ? null : _startCollecting,
                          icon: const Icon(Icons.vibration_outlined),
                          label: Text(_isCollecting ? 'Coletando…' : 'Iniciar coleta'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: _isCollecting
                            ? () {
                                _stopCollecting();
                              }
                            : () {
                                setState(() {
                                  _samples.clear();
                                  _saltController.clear();
                                  _error = '';
                                  _clearResult();
                                });
                              },
                        icon: const Icon(Icons.stop_circle_outlined),
                        label: Text(_isCollecting ? 'Parar' : 'Limpar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _saltController,
                    decoration: const InputDecoration(
                      labelText: 'Sal (opcional)',
                      prefixIcon: Icon(Icons.lock_outline),
                      helperText: 'Uma frase curta aumenta o espaço de busca. Guarde se quiser reproduzir.',
                    ),
                    onChanged: (_) => _clearResult(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _durationSeconds,
                          decoration: const InputDecoration(
                            labelText: 'Duração',
                            prefixIcon: Icon(Icons.timer_outlined),
                          ),
                          items: const [
                            DropdownMenuItem(value: 4, child: Text('4s')),
                            DropdownMenuItem(value: 6, child: Text('6s')),
                            DropdownMenuItem(value: 8, child: Text('8s')),
                            DropdownMenuItem(value: 10, child: Text('10s')),
                          ],
                          onChanged: _isCollecting
                              ? null
                              : (v) {
                                  if (v == null) return;
                                  setState(() => _durationSeconds = v);
                                },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _minSamples,
                          decoration: const InputDecoration(
                            labelText: 'Mín. amostras',
                            prefixIcon: Icon(Icons.filter_9_plus_outlined),
                          ),
                          items: const [
                            DropdownMenuItem(value: 32, child: Text('32')),
                            DropdownMenuItem(value: 64, child: Text('64')),
                            DropdownMenuItem(value: 96, child: Text('96')),
                            DropdownMenuItem(value: 128, child: Text('128')),
                          ],
                          onChanged: _isCollecting
                              ? null
                              : (v) {
                                  if (v == null) return;
                                  setState(() => _minSamples = v);
                                },
                        ),
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
                                title: 'Seed (ShakeKey)',
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    CopyableTextField(
                      controller: _seedController,
                      label: 'Seed (texto)',
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
