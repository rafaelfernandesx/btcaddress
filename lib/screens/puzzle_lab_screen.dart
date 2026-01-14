import 'dart:math' as math;

import 'package:btcaddress/btc_tool.dart';
import 'package:btcaddress/models/address_model.dart';
import 'package:btcaddress/screens/address_detail_screen.dart';
import 'package:btcaddress/services/puzzle_solver_service.dart';
import 'package:btcaddress/widgets/copyable_textfield.dart';
import 'package:flutter/material.dart';

class PuzzleLabScreen extends StatefulWidget {
  const PuzzleLabScreen({super.key});

  @override
  State<PuzzleLabScreen> createState() => _PuzzleLabScreenState();
}

class _PuzzleLabScreenState extends State<PuzzleLabScreen> {
  final _targetController = TextEditingController();

  final _toyTargetController = TextEditingController();
  final _toyPrivKeyController = TextEditingController();
  final _currentKeyController = TextEditingController();
  final _foundPrivKeyController = TextEditingController();
  final _foundCompressedController = TextEditingController();
  final _foundLegacyController = TextEditingController();

  final _solver = PuzzleSolverController();

  int _bitLength = 20;
  bool _checkLegacy = true;
  bool _checkCompressed = true;

  bool _running = false;
  String? _message;
  PuzzleSolveProgress? _progress;
  PuzzleSolveFound? _found;

  // Toy puzzle helper (gera um alvo válido dentro do range)
  String? _toyPrivateKeyHex;
  String? _toyTargetAddress;
  bool _showToySolution = false;

  @override
  void dispose() {
    _targetController.dispose();
    _toyTargetController.dispose();
    _toyPrivKeyController.dispose();
    _currentKeyController.dispose();
    _foundPrivKeyController.dispose();
    _foundCompressedController.dispose();
    _foundLegacyController.dispose();
    _solver.stop();
    super.dispose();
  }

  BigInt _maxKey() {
    return (BigInt.one << _bitLength) - BigInt.one;
  }

  Future<void> _start() async {
    final target = _targetController.text.trim();

    if (target.isEmpty) {
      setState(() {
        _message = 'Informe o endereço alvo.';
      });
      return;
    }

    if (!_checkLegacy && !_checkCompressed) {
      setState(() {
        _message = 'Selecione pelo menos 1 tipo (Legacy/Comprimido).';
      });
      return;
    }

    setState(() {
      _message = null;
      _progress = null;
      _found = null;
      _currentKeyController.text = '';
      _running = true;
    });

    try {
      await _solver.start(
        targetAddress: target,
        bitLength: _bitLength,
        checkLegacy: _checkLegacy,
        checkCompressed: _checkCompressed,
        onProgress: (p) {
          if (!mounted) return;
          setState(() {
            _progress = p;
            _currentKeyController.text = p.currentPrivKeyHex;
          });
        },
        onFound: (f) {
          if (!mounted) return;
          setState(() {
            _found = f;
            _foundPrivKeyController.text = f.privateKeyHex;
            _foundCompressedController.text = f.addressCompressed;
            _foundLegacyController.text = f.addressLegacy;
            _running = false;
          });
          _solver.stop();
        },
        onNotFound: () {
          if (!mounted) return;
          setState(() {
            _message = 'Não encontrado nesse range (1..2^$_bitLength-1).';
            _running = false;
          });
          _solver.stop();
        },
        onError: (e) {
          if (!mounted) return;
          setState(() {
            _message = e.toString();
            _running = false;
          });
          _solver.stop();
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = e.toString();
        _running = false;
      });
    }
  }

  Future<void> _stop() async {
    await _solver.stop();
    if (!mounted) return;
    setState(() {
      _running = false;
      _message = 'Busca cancelada.';
    });
  }

  void _generateToyPuzzle() {
    final random = math.Random.secure();
    final max = _maxKey();
    if (max <= BigInt.one) {
      setState(() {
        _message = 'bitLength muito pequeno.';
      });
      return;
    }

    // Gera k em [1, max] (8..32 bits). Para 32 bits, Random.nextInt não aceita 2^32.
    int intCandidate;
    if (_bitLength == 32) {
      final hi = random.nextInt(1 << 16);
      final lo = random.nextInt(1 << 16);
      intCandidate = (hi << 16) | lo;
    } else {
      intCandidate = random.nextInt(1 << _bitLength);
    }
    final BigInt k = BigInt.from(intCandidate == 0 ? 1 : intCandidate);

    final privHex = k.toRadixString(16).padLeft(64, '0');
    final btc = BitcoinTOOL()..setPrivateKeyHex(privHex);

    final compressed = btc.getAddress(true);

    // Por padrão, usa comprimido como alvo (mais comum)
    _targetController.text = compressed;
    _toyTargetController.text = compressed;
    _toyPrivKeyController.text = privHex;

    setState(() {
      _toyPrivateKeyHex = privHex;
      _toyTargetAddress = compressed;
      _showToySolution = false;
      _message = 'Toy puzzle gerado. Tente encontrar a chave no range 1..2^$_bitLength-1.';
    });
  }

  Future<void> _openFoundDetails() async {
    final found = _found;
    if (found == null) return;

    final btc = BitcoinTOOL()..setPrivateKeyHex(found.privateKeyHex);

    final model = AddressModel(
      seed: 'puzzle-lab:$_bitLength-bits',
      addressCompressed: btc.getAddress(true),
      addressUncompressed: btc.getAddress(false),
      privateKeyHex: btc.getPrivateKey(),
      privateKeyWif: btc.getWif(false),
      privateKeyWifCompressed: btc.getWif(true),
      publicKeyHex: btc.getPubKey(),
      publicKeyHexCompressed: btc.getPubKey(compressed: true),
      timestamp: DateTime.now(),
    );

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddressDetailScreen(address: model),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final max = _maxKey();
    final totalKeys = max.toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Puzzle Lab'),
        actions: [
          IconButton(
            tooltip: 'Gerar toy puzzle',
            onPressed: _running ? null : _generateToyPuzzle,
            icon: const Icon(Icons.auto_fix_high),
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
                    'Sobre',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Este módulo é educativo: ele tenta encontrar uma chave privada por força bruta em um keyspace pequeno (8..32 bits).\n\n'
                    'Puzzles reais de Bitcoin usam ranges gigantescos (ex.: 160+ bits), então não é viável resolver no celular/PC comum com brute force.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
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
                    'Configuração',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _targetController,
                    decoration: const InputDecoration(
                      labelText: 'Endereço alvo (Legacy ou Comprimido)',
                      prefixIcon: Icon(Icons.flag_outlined),
                    ),
                    textInputAction: TextInputAction.done,
                    enabled: !_running,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Keyspace: $_bitLength bits',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Total (aprox.): $totalKeys chaves (1..2^$_bitLength-1)',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      DropdownButton<int>(
                        value: _bitLength,
                        onChanged: _running
                            ? null
                            : (v) {
                                if (v == null) return;
                                setState(() {
                                  _bitLength = v;
                                });
                              },
                        items: const [
                          8,
                          12,
                          16,
                          20,
                          24,
                          28,
                          32,
                        ]
                            .map(
                              (e) => DropdownMenuItem<int>(
                                value: e,
                                child: Text('$e'),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      FilterChip(
                        label: const Text('Legacy (não comprimido)'),
                        selected: _checkLegacy,
                        onSelected: _running
                            ? null
                            : (v) {
                                setState(() {
                                  _checkLegacy = v;
                                });
                              },
                      ),
                      FilterChip(
                        label: const Text('Comprimido'),
                        selected: _checkCompressed,
                        onSelected: _running
                            ? null
                            : (v) {
                                setState(() {
                                  _checkCompressed = v;
                                });
                              },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _running ? _stop : _start,
                      icon: Icon(_running ? Icons.stop : Icons.play_arrow),
                      label: Text(_running ? 'Parar' : 'Iniciar busca'),
                    ),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _message!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_toyTargetAddress != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Toy Puzzle (gerado)',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    CopyableTextField(
                      controller: _toyTargetController,
                      label: 'Endereço alvo (comprimido)',
                      prefixIcon: Icons.flag,
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      value: _showToySolution,
                      onChanged: _running
                          ? null
                          : (v) {
                              setState(() {
                                _showToySolution = v;
                              });
                            },
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Mostrar solução (private key)'),
                    ),
                    if (_showToySolution && _toyPrivateKeyHex != null) ...[
                      const SizedBox(height: 8),
                      CopyableTextField(
                        controller: _toyPrivKeyController,
                        label: 'PrivateKey (HEX)',
                        prefixIcon: Icons.lock_outline,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          if (_progress != null || _found != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Progresso',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    if (_found != null) ...[
                      Text(
                        'Encontrado após ${_found!.tested} tentativas!',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                      const SizedBox(height: 12),
                      CopyableTextField(
                        controller: _foundPrivKeyController,
                        label: 'PrivateKey (HEX)',
                        prefixIcon: Icons.lock_open,
                      ),
                      const SizedBox(height: 12),
                      CopyableTextField(
                        controller: _foundCompressedController,
                        label: 'Endereço (Comprimido)',
                        prefixIcon: Icons.account_balance_wallet,
                      ),
                      const SizedBox(height: 12),
                      CopyableTextField(
                        controller: _foundLegacyController,
                        label: 'Endereço (Legacy)',
                        prefixIcon: Icons.account_balance_wallet_outlined,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _openFoundDetails,
                          icon: const Icon(Icons.account_balance_wallet),
                          label: const Text('Abrir detalhes da carteira'),
                        ),
                      ),
                    ] else ...[
                      Text(
                        'Testadas: ${_progress?.tested ?? 0}',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Velocidade: ${(_progress?.keysPerSecond ?? 0).toStringAsFixed(0)} keys/s',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      CopyableTextField(
                        controller: _currentKeyController,
                        label: 'Chave atual (HEX)',
                        prefixIcon: Icons.timelapse,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Dica: aumente bits aos poucos (ex.: 16, 20, 24).',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
