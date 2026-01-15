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
  final PuzzleSearchStrategy _toyStrategy = PuzzleSearchStrategy.sequential;

  int? _toyRandomSeed;

  final bool _simulateBitcoinPuzzle = false;
  int _simulatePuzzleId = 1;
  final String _simulateQuery = '';
  BitcoinPuzzleSolveStatus? _simulateStatusFilter;

  bool _running = false;
  bool _runningRealPuzzle = false;
  String? _message;
  PuzzleSolveProgress? _progress;
  PuzzleSolveFound? _found;

  // Real puzzle brute force
  int? _realPuzzleId;
  String? _realPuzzleAddress;
  int _realPuzzleBits = 32;
  int _realTestedKeys = 0;
  int _realKeysPerSecond = 0;
  BigInt _realCurrentKey = BigInt.zero;
  DateTime? _realStartTime;
  bool _realCheckLegacy = true;
  bool _realCheckCompressed = true;

  // Toy puzzle helper
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

  BigInt _toyStartKey() {
    if (!_simulateBitcoinPuzzle) return BigInt.one;
    if (_toyBitLength <= 1) return BigInt.one;
    return BigInt.one << (_toyBitLength - 1);
  }

  BigInt _toyEndKey() {
    if (!_simulateBitcoinPuzzle) return _maxKey();
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

    final int? randomSeed = _toyStrategy == PuzzleSearchStrategy.random ? (_toyRandomSeed ?? DateTime.now().microsecondsSinceEpoch) : null;

    if (_toyStrategy == PuzzleSearchStrategy.random) {
      _toyRandomSeed = randomSeed;
    }

    try {
      await _solver.start(
        targetAddress: target,
        bitLength: _toyBitLength,
        checkLegacy: _checkLegacy,
        checkCompressed: _checkCompressed,
        strategy: _toyStrategy,
        randomSeed: randomSeed,
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
    if (_running) {
      await _solver.stop();
    }
    if (_runningRealPuzzle) {
      _stopRealPuzzleBruteForce();
    }
    if (!mounted) return;
    setState(() {
      _running = false;
      _runningRealPuzzle = false;
      _message = 'Busca cancelada.';
    });
  }

  void _generateToyPuzzle() {
    final random = math.Random.secure();

    final start = _toyStartKey();
    final end = _toyEndKey();
    if (end <= BigInt.one || end < start) {
      setState(() {
        _message = 'bitLength muito pequeno.';
      });
      return;
    }

    // Gera k no range de treino.
    BigInt k;
    if (_simulateBitcoinPuzzle) {
      final bits = _toyBitLength;
      if (bits < 8 || bits > 32) {
        setState(() {
          _message = 'Simulação disponível apenas para 8..32 bits (educacional).';
        });
        return;
      }
      if (bits == 1) {
        k = BigInt.one;
      } else {
        final offsetMax = 1 << (bits - 1);
        final offset = random.nextInt(offsetMax);
        final intCandidate = (1 << (bits - 1)) + offset;
        k = BigInt.from(intCandidate);
      }
    } else {
      // Range padrão: [1, 2^bits-1].
      int intCandidate;
      if (_toyBitLength == 32) {
        final hi = random.nextInt(1 << 16);
        final lo = random.nextInt(1 << 16);
        intCandidate = (hi << 16) | lo;
      } else {
        intCandidate = random.nextInt(1 << _toyBitLength);
      }
      k = BigInt.from(intCandidate == 0 ? 1 : intCandidate);
    }

    final privHex = k.toRadixString(16).padLeft(64, '0');
    final btc = BitcoinTOOL()..setPrivateKeyHex(privHex);

    final compressed = btc.getAddress(true);

    _targetController.text = compressed;
    _toyTargetController.text = compressed;
    _toyPrivKeyController.text = privHex;

    setState(() {
      _toyPrivateKeyHex = privHex;
      _toyTargetAddress = compressed;
      _showToySolution = false;
      _toyRandomSeed = null;
      _message = _simulateBitcoinPuzzle
          ? 'Simulação gerada (Puzzle #$_simulatePuzzleId). Tente encontrar a chave no range 2^${_toyBitLength - 1}..2^$_toyBitLength-1.'
          : 'Toy puzzle gerado. Tente encontrar a chave no range 1..2^$_toyBitLength-1.';
    });
  }

  void _applySimulationPreset(int puzzleId) {
    final preset = kBitcoinPuzzlePresetsById[puzzleId];
    if (preset == null) return;

    setState(() {
      _simulatePuzzleId = puzzleId;
      _message = null;
    });

    if (preset.bits < 8 || preset.bits > 32) {
      setState(() {
        _message = 'Esse preset tem ${preset.bits} bits. A simulação do solver é apenas para 8..32 bits (educacional).';
      });
      return;
    }

    setState(() {
      _toyBitLength = preset.bits;
    });

    _generateToyPuzzle();
  }

  List<BitcoinPuzzlePreset> _filteredSimulationPresets() {
    final q = _simulateQuery.trim().toLowerCase();
    return kBitcoinPuzzlePresets.where((p) {
      if (_simulateStatusFilter != null && p.status != _simulateStatusFilter) return false;
      if (q.isEmpty) return true;
      return p.id.toString() == q || p.address.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _repeatTest() async {
    if (_running) return;
    if (_toyTargetAddress == null) return;

    setState(() {
      _message = null;
      _progress = null;
      _found = null;
      _currentKeyController.text = '';
      _foundPrivKeyController.text = '';
      _foundCompressedController.text = '';
      _foundLegacyController.text = '';
    });

    await _start();
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
      _realPuzzleId = puzzleId;
      _realPuzzleAddress = preset.address;
      _realPuzzleBits = preset.bits;
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
      addressBech32: btc.getBech32Address(),
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

  // ==================== REAL PUZZLE BRUTE FORCE ====================
  Future<void> _startRealPuzzleBruteForce() async {
    if (_realPuzzleAddress == null || _realPuzzleAddress!.isEmpty) {
      setState(() {
        _message = 'Selecione um puzzle primeiro.';
      });
      return;
    }

    if (!_realCheckLegacy && !_realCheckCompressed) {
      setState(() {
        _message = 'Selecione pelo menos 1 tipo (Legacy/Comprimido).';
      });
      return;
    }

    setState(() {
      _runningRealPuzzle = true;
      _realTestedKeys = 0;
      _realKeysPerSecond = 0;
      _realStartTime = DateTime.now();
      _message = 'Iniciando brute force no Puzzle #$_realPuzzleId ($_realPuzzleBits bits)...';
    });

    // Calcular range do puzzle
    final startKey = _puzzleStartKey(_realPuzzleBits);
    final endKey = _puzzleEndKey(_realPuzzleBits);

    print('Iniciando brute force no puzzle $_realPuzzleId');
    print('Range: $startKey a $endKey');
    print('Total de chaves: ${endKey - startKey + BigInt.one}');

    // Executar em um Isolate para não travar a UI
    await _runBruteForceIsolate(startKey, endKey);
  }

  Future<void> _runBruteForceIsolate(BigInt startKey, BigInt endKey) async {
    // Para fins educacionais, vou implementar uma versão simplificada
    // Em produção, você usaria um Isolate real

    BigInt current = startKey;
    final targetAddress = _realPuzzleAddress!;
    final checkLegacy = _realCheckLegacy;
    final checkCompressed = _realCheckCompressed;

    DateTime lastUpdate = DateTime.now();
    int testedSinceLastUpdate = 0;

    try {
      while (_runningRealPuzzle && current <= endKey) {
        // Converter chave para HEX
        final privHex = current.toRadixString(16).padLeft(64, '0');

        // Gerar endereços
        final btc = BitcoinTOOL()..setPrivateKeyHex(privHex);

        if (checkCompressed) {
          final compressed = btc.getAddress(true);
          if (compressed == targetAddress) {
            _handleFoundKey(privHex, btc);
            return;
          }
        }

        if (checkLegacy) {
          final legacy = btc.getAddress(false);
          if (legacy == targetAddress) {
            _handleFoundKey(privHex, btc);
            return;
          }
        }

        _realTestedKeys++;
        testedSinceLastUpdate++;

        // Atualizar estatísticas a cada segundo
        final now = DateTime.now();
        if (now.difference(lastUpdate).inMilliseconds >= 1000) {
          _realKeysPerSecond = testedSinceLastUpdate;
          testedSinceLastUpdate = 0;
          lastUpdate = now;

          // Atualizar UI
          if (mounted) {
            setState(() {
              _realCurrentKey = current;
            });
          }
        }

        // Incrementar chave
        current = current + BigInt.one;

        // Dar tempo para UI (remover em produção para máxima velocidade)
        if (_realTestedKeys % 1000 == 0) {
          await Future.delayed(const Duration(milliseconds: 1));
        }
      }

      if (mounted && _runningRealPuzzle) {
        setState(() {
          _runningRealPuzzle = false;
          _message = 'Puzzle não encontrado no range especificado.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _runningRealPuzzle = false;
          _message = 'Erro durante brute force: $e';
        });
      }
    }
  }

  void _handleFoundKey(String privHex, BitcoinTOOL btc) {
    if (!mounted) return;

    final compressed = btc.getAddress(true);
    final legacy = btc.getAddress(false);

    setState(() {
      _runningRealPuzzle = false;
      _foundPrivKeyController.text = privHex;
      _foundCompressedController.text = compressed;
      _foundLegacyController.text = legacy;

      // Criar resultado encontrado
      _found = PuzzleSolveFound(
        privateKeyHex: privHex,
        addressCompressed: compressed,
        addressLegacy: legacy,
        tested: _realTestedKeys,
      );

      _message = 'ENCONTRADO! Puzzle #$_realPuzzleId resolvido após $_realTestedKeys tentativas!';
    });

    // Mostrar alerta
    _showPuzzleSolvedAlert();
  }

  void _stopRealPuzzleBruteForce() {
    setState(() {
      _runningRealPuzzle = false;
    });
  }

  void _showPuzzleSolvedAlert() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🎉 Puzzle Resolvido!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Parabéns! Você resolveu o Puzzle #$_realPuzzleId!', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('Esta é uma demonstração educacional. Em um puzzle real:'),
            const SizedBox(height: 8),
            const Text('• A recompensa seria real'),
            const Text('• O processo levaria milhões de anos com hardware normal'),
            const Text('• A chave privada precisaria ser mantida em segredo'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _openFoundDetails();
            },
            child: const Text('Ver Detalhes'),
          ),
        ],
      ),
    );
  }

  Widget _buildRealPuzzleBruteForcePanel() {
    final totalKeysEstimate =
        _realPuzzleBits < 64 ? (BigInt.one << _realPuzzleBits) - (BigInt.one << (_realPuzzleBits - 1)) : BigInt.parse('Muito grande para exibir');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Brute Force (Puzzle Real)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              '⚠️ AVISO: Esta é uma demonstração educacional.\n'
              'Puzzles reais são praticamente impossíveis de resolver com hardware comum.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
            const SizedBox(height: 12),

            // Estatísticas
            if (_runningRealPuzzle) ...[
              Text(
                'Status: Buscando...',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: null, // Indeterminado
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chaves testadas:',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          '$_realTestedKeys',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Velocidade:',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          '$_realKeysPerSecond keys/s',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Chave atual: ${_realCurrentKey.toRadixString(16).padLeft(64, '0').substring(0, 16)}...',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _stop,
                  icon: const Icon(Icons.stop),
                  label: const Text('Parar Busca'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  ),
                ),
              ),
            ] else ...[
              Text(
                'Puzzle #$_realPuzzleId ($_realPuzzleBits bits)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Range: 2^${_realPuzzleBits - 1} a 2^$_realPuzzleBits - 1',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Total estimado: $totalKeysEstimate chaves',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),

              // Opções de busca
              Text(
                'Tipos de endereço para verificar:',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  FilterChip(
                    label: const Text('Legacy'),
                    selected: _realCheckLegacy,
                    onSelected: _runningRealPuzzle
                        ? null
                        : (v) {
                            setState(() {
                              _realCheckLegacy = v;
                            });
                          },
                  ),
                  FilterChip(
                    label: const Text('Comprimido'),
                    selected: _realCheckCompressed,
                    onSelected: _runningRealPuzzle
                        ? null
                        : (v) {
                            setState(() {
                              _realCheckCompressed = v;
                            });
                          },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Estimativa de tempo
              _buildTimeEstimate(),
              const SizedBox(height: 12),

              // Botões de ação
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _runningRealPuzzle ? null : _startRealPuzzleBruteForce,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Iniciar Busca'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _runningRealPuzzle
                          ? null
                          : () {
                              // Limpar resultados anteriores
                              setState(() {
                                _found = null;
                                _foundPrivKeyController.text = '';
                                _foundCompressedController.text = '';
                                _foundLegacyController.text = '';
                                _message = null;
                              });
                            },
                      icon: const Icon(Icons.clear),
                      label: const Text('Limpar'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimeEstimate() {
    if (_realPuzzleBits <= 32) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estimativa (aproximada):',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            const Text('• 32 bits: Dias a semanas (CPU comum)'),
            const Text('• 40 bits: Meses a anos'),
            const Text('• 50 bits: Séculos'),
            const Text('• 66+ bits: Impossível com tecnologia atual'),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '⚠️ Este puzzle tem $_realPuzzleBits bits.\n'
          'Não é viável resolver com hardware comum.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final max = _maxKey();
    final totalKeys = max.toString();

    final toyStart = _toyStartKey();
    final toyEnd = _toyEndKey();
    final toyStartHex = toyStart.toRadixString(16).padLeft(64, '0');
    final toyEndHex = toyEnd.toRadixString(16).padLeft(64, '0');

    final selectedPreset = kBitcoinPuzzlePresetsById[_selectedPuzzleId] ?? kBitcoinPuzzlePresets.first;
    final puzzleBits = selectedPreset.bits;
    final puzzleStart = _puzzleStartKey(puzzleBits);
    final puzzleEnd = _puzzleEndKey(puzzleBits);
    final puzzleStartHex = puzzleStart.toRadixString(16).padLeft(64, '0');
    final puzzleEndHex = puzzleEnd.toRadixString(16).padLeft(64, '0');

    final filtered = _filteredPresets();
    final simSelectedPreset = kBitcoinPuzzlePresetsById[_simulatePuzzleId] ?? kBitcoinPuzzlePresets.first;
    final simFiltered = _filteredSimulationPresets();

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
                  onSelectionChanged: (_running || _runningRealPuzzle)
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
                    'Bitcoin Puzzle: mostra os puzzles reais com funcionalidade de brute force '
                    '(apenas para demonstração educacional).\n\n'
                    '⚠️ Brute force em puzzles reais não é viável computacionalmente para puzzles maiores que 32 bits.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_mode == _PuzzleLabMode.treino) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Treino (Toy Puzzle)',
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
                              Text(
                                'Total: $totalKeys chaves',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        DropdownButton<int>(
                          value: _toyBitLength,
                          onChanged: _running
                              ? null
                              : (v) {
                                  if (v == null) return;
                                  setState(() => _toyBitLength = v);
                                },
                          items: [8, 12, 16, 20, 24, 28, 32]
                              .map((e) => DropdownMenuItem<int>(
                                    value: e,
                                    child: Text('$e bits'),
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      children: [
                        FilterChip(
                          label: const Text('Legacy'),
                          selected: _checkLegacy,
                          onSelected: _running ? null : (v) => setState(() => _checkLegacy = v),
                        ),
                        FilterChip(
                          label: const Text('Comprimido'),
                          selected: _checkCompressed,
                          onSelected: _running ? null : (v) => setState(() => _checkCompressed = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _running ? _stop : _start,
                        icon: Icon(_running ? Icons.stop : Icons.play_arrow),
                        label: Text(_running ? 'Parar' : 'Iniciar Busca'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_toyTargetAddress != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Toy Puzzle Gerado', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 12),
                      CopyableTextField(
                        controller: _toyTargetController,
                        label: 'Endereço alvo',
                        prefixIcon: Icons.flag,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ] else ...[
            // Modo Bitcoin Puzzle Real
            const SizedBox(height: 16),
            _buildRealPuzzleBruteForcePanel(),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lista de Puzzles Bitcoin',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Buscar por # ou endereço',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (v) => setState(() => _puzzleQuery = v),
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
                        final isSelected = p.id == _selectedPuzzleId;
                        final statusColor = _statusColor(context, p.status);

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor:
                                isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
                            child: Text('${p.id}', style: const TextStyle(fontWeight: FontWeight.w800)),
                          ),
                          title: Text('Puzzle #${p.id} • ${p.bits} bits'),
                          subtitle: Text(p.address, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('${p.rewardBtc} ₿',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Theme.of(context).colorScheme.primary,
                                  )),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: statusColor.withOpacity(0.35)),
                                ),
                                child: Text(_statusLabel(p), style: const TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                          onTap: () => _applyPuzzlePreset(p.id),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_found != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🎉 Chave Encontrada!',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
                    Row(
                      children: [
                        Expanded(
                          child: CopyableTextField(
                            controller: _foundCompressedController,
                            label: 'Comprimido',
                            prefixIcon: Icons.account_balance_wallet,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CopyableTextField(
                            controller: _foundLegacyController,
                            label: 'Legacy',
                            prefixIcon: Icons.account_balance_wallet_outlined,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _openFoundDetails,
                        icon: const Icon(Icons.info_outline),
                        label: const Text('Ver Detalhes da Carteira'),
                      ),
                    ),
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
