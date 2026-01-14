import 'dart:math' as math;

import 'package:btcaddress/btc_tool.dart';
import 'package:btcaddress/data/bitcoin_puzzle_presets.dart';
import 'package:btcaddress/models/address_model.dart';
import 'package:btcaddress/screens/address_detail_screen.dart';
import 'package:btcaddress/services/puzzle_solver_service.dart';
import 'package:btcaddress/widgets/copyable_textfield.dart';
import 'package:flutter/material.dart';

enum _PuzzleLabMode {
  treino,
  bitcoinPuzzle,
}

class PuzzleLabScreen extends StatefulWidget {
  const PuzzleLabScreen({super.key});

  @override
  State<PuzzleLabScreen> createState() => _PuzzleLabScreenState();
}

class _PuzzleLabScreenState extends State<PuzzleLabScreen> {
  _PuzzleLabMode _mode = _PuzzleLabMode.treino;

  final _targetController = TextEditingController();

  final _toyTargetController = TextEditingController();
  final _toyPrivKeyController = TextEditingController();
  final _currentKeyController = TextEditingController();
  final _foundPrivKeyController = TextEditingController();
  final _foundCompressedController = TextEditingController();
  final _foundLegacyController = TextEditingController();

  final _solver = PuzzleSolverController();

  int _toyBitLength = 20;
  bool _checkLegacy = true;
  bool _checkCompressed = true;
  PuzzleSearchStrategy _toyStrategy = PuzzleSearchStrategy.sequential;

  bool _running = false;
  String? _message;
  PuzzleSolveProgress? _progress;
  PuzzleSolveFound? _found;

  // Toy puzzle helper (gera um alvo válido dentro do range)
  String? _toyPrivateKeyHex;
  String? _toyTargetAddress;
  bool _showToySolution = false;

  int _selectedPuzzleId = 1;
  String _puzzleQuery = '';
  BitcoinPuzzleSolveStatus? _statusFilter;
  final _puzzleAddressController = TextEditingController();
  final _candidatePrivKeyController = TextEditingController();
  String? _candidateResult;

  @override
  void dispose() {
    _targetController.dispose();
    _toyTargetController.dispose();
    _toyPrivKeyController.dispose();
    _currentKeyController.dispose();
    _foundPrivKeyController.dispose();
    _foundCompressedController.dispose();
    _foundLegacyController.dispose();
    _puzzleAddressController.dispose();
    _candidatePrivKeyController.dispose();
    _solver.stop();
    super.dispose();
  }

  BigInt _maxKey() {
    return (BigInt.one << _toyBitLength) - BigInt.one;
  }

  BigInt _puzzleStartKey(int bits) {
    if (bits <= 1) return BigInt.one;
    return BigInt.one << (bits - 1);
  }

  BigInt _puzzleEndKey(int bits) {
    return (BigInt.one << bits) - BigInt.one;
  }

  Future<void> _start() async {
    // Segurança/ética: o solver aqui é somente para o modo de treino (toy puzzle gerado no app).
    final target = _targetController.text.trim();
    if (_toyTargetAddress == null || target.isEmpty || target != _toyTargetAddress) {
      setState(() {
        _message = 'Gere um Toy Puzzle primeiro (o solver só roda no modo de treino).';
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
        bitLength: _toyBitLength,
        checkLegacy: _checkLegacy,
        checkCompressed: _checkCompressed,
        strategy: _toyStrategy,
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
            _message = 'Não encontrado nesse range (1..2^$_toyBitLength-1).';
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
    if (_toyBitLength == 32) {
      final hi = random.nextInt(1 << 16);
      final lo = random.nextInt(1 << 16);
      intCandidate = (hi << 16) | lo;
    } else {
      intCandidate = random.nextInt(1 << _toyBitLength);
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
      _message = 'Toy puzzle gerado. Tente encontrar a chave no range 1..2^$_toyBitLength-1.';
    });
  }

  void _applyPuzzlePreset(int puzzleId) {
    final preset = kBitcoinPuzzlePresetsById[puzzleId];
    if (preset == null) return;

    setState(() {
      _selectedPuzzleId = puzzleId;
      _puzzleAddressController.text = preset.address;
      _candidatePrivKeyController.text = '';
      _candidateResult = null;
      _message = null;
    });
  }

  List<BitcoinPuzzlePreset> _filteredPresets() {
    final q = _puzzleQuery.trim().toLowerCase();
    return kBitcoinPuzzlePresets.where((p) {
      if (_statusFilter != null && p.status != _statusFilter) return false;
      if (q.isEmpty) return true;
      return p.id.toString() == q || p.address.toLowerCase().contains(q);
    }).toList();
  }

  Color _statusColor(BuildContext context, BitcoinPuzzleSolveStatus status) {
    switch (status) {
      case BitcoinPuzzleSolveStatus.unsolved:
        return Theme.of(context).colorScheme.tertiary;
      case BitcoinPuzzleSolveStatus.solved:
        return Theme.of(context).colorScheme.primary;
      case BitcoinPuzzleSolveStatus.unknown:
        return Theme.of(context).colorScheme.outline;
    }
  }

  String _statusLabel(BitcoinPuzzlePreset preset) {
    if (preset.status == BitcoinPuzzleSolveStatus.unsolved) return 'Unsolved';
    if (preset.status == BitcoinPuzzleSolveStatus.solved) return 'Solved (${preset.statusLabel})';
    return 'Unknown';
  }

  void _verifyCandidate() {
    final address = _puzzleAddressController.text.trim();
    final candidate = _candidatePrivKeyController.text.trim();

    if (address.isEmpty || candidate.isEmpty) {
      setState(() {
        _candidateResult = 'Informe o endereço e a private key (HEX).';
      });
      return;
    }

    final normalized = candidate.toLowerCase().replaceAll(RegExp(r'[^0-9a-f]'), '');
    if (normalized.length != 64) {
      setState(() {
        _candidateResult = 'A private key HEX deve ter 64 caracteres (32 bytes).';
      });
      return;
    }

    try {
      final btc = BitcoinTOOL()..setPrivateKeyHex(normalized);
      final legacy = btc.getAddress(false);
      final compressed = btc.getAddress(true);
      final matches = legacy == address || compressed == address;

      setState(() {
        _candidateResult = matches ? 'Match! A chave gera o endereço alvo.' : 'Não corresponde. Legacy=$legacy | Comprimido=$compressed';
      });
    } catch (e) {
      setState(() {
        _candidateResult = 'Chave inválida: ${e.toString()}';
      });
    }
  }

  Future<void> _openFoundDetails() async {
    final found = _found;
    if (found == null) return;

    final btc = BitcoinTOOL()..setPrivateKeyHex(found.privateKeyHex);

    final model = AddressModel(
      seed: 'puzzle-lab:$_toyBitLength-bits',
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

    final selectedPreset = kBitcoinPuzzlePresetsById[_selectedPuzzleId] ?? kBitcoinPuzzlePresets.first;
    final puzzleBits = selectedPreset.bits;
    final puzzleStart = _puzzleStartKey(puzzleBits);
    final puzzleEnd = _puzzleEndKey(puzzleBits);
    final puzzleStartHex = puzzleStart.toRadixString(16).padLeft(64, '0');
    final puzzleEndHex = puzzleEnd.toRadixString(16).padLeft(64, '0');

    final filtered = _filteredPresets();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Puzzle Lab'),
        actions: [
          IconButton(
            tooltip: 'Gerar toy puzzle',
            onPressed: _mode == _PuzzleLabMode.treino && !_running ? _generateToyPuzzle : null,
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
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<_PuzzleLabMode>(
                  segments: const [
                    ButtonSegment(value: _PuzzleLabMode.treino, label: Text('Treino')),
                    ButtonSegment(value: _PuzzleLabMode.bitcoinPuzzle, label: Text('Bitcoin Puzzle')),
                  ],
                  selected: <_PuzzleLabMode>{_mode},
                  onSelectionChanged: _running
                      ? null
                      : (selection) {
                          final next = selection.first;
                          setState(() {
                            _mode = next;
                            _message = null;
                            _candidateResult = null;
                          });

                          if (next == _PuzzleLabMode.bitcoinPuzzle) {
                            _applyPuzzlePreset(_selectedPuzzleId);
                          }
                        },
                ),
              ),
            ),
          ),
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
                    'Treino: o app gera um Toy Puzzle (keyspace pequeno) e você tenta achar a chave.\n\n'
                    'Bitcoin Puzzle: mostra os puzzles reais (endereços) e permite verificar uma chave que você já possua, mas não tenta “adivinhar” chaves de puzzles reais. Isso não é viável computacionalmente e também pode ser usado de forma indevida.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_mode == _PuzzleLabMode.treino)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Configuração (Treino)',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _targetController,
                      decoration: const InputDecoration(
                        labelText: 'Endereço alvo (gerado no Toy Puzzle)',
                        prefixIcon: Icon(Icons.flag_outlined),
                      ),
                      readOnly: true,
                      enabled: true,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Keyspace: $_toyBitLength bits',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Total (aprox.): $totalKeys chaves (1..2^$_toyBitLength-1)',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        DropdownButton<int>(
                          value: _toyBitLength,
                          onChanged: _running
                              ? null
                              : (v) {
                                  if (v == null) return;
                                  setState(() {
                                    _toyBitLength = v;
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
                    Text(
                      'Estratégia de busca',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<PuzzleSearchStrategy>(
                      segments: const [
                        ButtonSegment(
                          value: PuzzleSearchStrategy.sequential,
                          label: Text('Sequencial'),
                          icon: Icon(Icons.format_list_numbered),
                        ),
                        ButtonSegment(
                          value: PuzzleSearchStrategy.random,
                          label: Text('Aleatória'),
                          icon: Icon(Icons.casino_outlined),
                        ),
                      ],
                      selected: <PuzzleSearchStrategy>{_toyStrategy},
                      onSelectionChanged: _running
                          ? null
                          : (selection) {
                              setState(() {
                                _toyStrategy = selection.first;
                              });
                            },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _toyStrategy == PuzzleSearchStrategy.random
                          ? 'Aleatória: testa chaves em ordem pseudo-aleatória (educacional). Pode repetir tentativas e não garante achar em N passos.'
                          : 'Sequencial: testa chaves de 1 até 2^bits-1 (educacional).',
                      style: Theme.of(context).textTheme.bodySmall,
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
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bitcoin Puzzle (Real)',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Lista atualizada de puzzles com status e recompensa.\n'
                      'Este app não faz tentativa aleatória/brute force em puzzles reais.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Selecionado: Puzzle #${selectedPreset.id} (${selectedPreset.bits} bits)',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Chip(
                          label: Text(_statusLabel(selectedPreset)),
                          backgroundColor: _statusColor(context, selectedPreset.status).withValues(alpha: 0.12),
                          side: BorderSide(color: _statusColor(context, selectedPreset.status).withValues(alpha: 0.35)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Recompensa: ${selectedPreset.rewardBtc} ₿',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 12),
                    CopyableTextField(
                      controller: _puzzleAddressController,
                      label: 'Endereço do puzzle',
                      prefixIcon: Icons.flag,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Range (private key): [2^${puzzleBits - 1}, 2^$puzzleBits - 1]\n'
                      'Início: $puzzleStartHex\n'
                      'Fim:    $puzzleEndHex',
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Lista',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Buscar por # ou endereço',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (v) {
                        setState(() {
                          _puzzleQuery = v;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilterChip(
                          selected: _statusFilter == null,
                          label: const Text('Todos'),
                          onSelected: (_) {
                            setState(() {
                              _statusFilter = null;
                            });
                          },
                        ),
                        FilterChip(
                          selected: _statusFilter == BitcoinPuzzleSolveStatus.unsolved,
                          label: const Text('Unsolved'),
                          onSelected: (_) {
                            setState(() {
                              _statusFilter = BitcoinPuzzleSolveStatus.unsolved;
                            });
                          },
                        ),
                        FilterChip(
                          selected: _statusFilter == BitcoinPuzzleSolveStatus.solved,
                          label: const Text('Solved'),
                          onSelected: (_) {
                            setState(() {
                              _statusFilter = BitcoinPuzzleSolveStatus.solved;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Mostrando ${filtered.length} de ${kBitcoinPuzzlePresets.length}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 16),
                      itemBuilder: (context, index) {
                        final p = filtered[index];
                        final isSelected = p.id == selectedPreset.id;
                        final statusColor = _statusColor(context, p.status);

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor:
                                isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
                            foregroundColor: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface,
                            child: Text(
                              '${p.id}',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                          title: Text('Puzzle #${p.id} • ${p.bits} bits'),
                          subtitle: Text(
                            p.address,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${p.rewardBtc} ₿',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: statusColor.withValues(alpha: 0.35)),
                                ),
                                child: Text(
                                  _statusLabel(p),
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                          onTap: () {
                            _applyPuzzlePreset(p.id);
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Verificar chave (opcional)',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _candidatePrivKeyController,
                      decoration: const InputDecoration(
                        labelText: 'PrivateKey (HEX) para verificar',
                        prefixIcon: Icon(Icons.key),
                        helperText: 'Cole uma chave e veja se gera o endereço do puzzle.',
                      ),
                      minLines: 1,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _verifyCandidate,
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Verificar'),
                      ),
                    ),
                    if (_candidateResult != null) ...[
                      const SizedBox(height: 12),
                      SelectableText(
                        _candidateResult!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          if (_mode == _PuzzleLabMode.treino && _toyTargetAddress != null)
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
          if (_mode == _PuzzleLabMode.treino && (_progress != null || _found != null)) ...[
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
