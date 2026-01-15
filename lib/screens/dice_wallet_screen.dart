import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../bitcoin/dice_mnemonic.dart';
import 'hd_wallet_screen.dart';

class DiceWalletScreen extends StatefulWidget {
  const DiceWalletScreen({super.key});

  @override
  State<DiceWalletScreen> createState() => _DiceWalletScreenState();
}

class _DiceWalletScreenState extends State<DiceWalletScreen> {
  final _rollsController = TextEditingController();

  int _wordCount = 12;
  String? _mnemonic;
  String? _error;

  @override
  void dispose() {
    _rollsController.dispose();
    super.dispose();
  }

  int get _requiredRolls => DiceMnemonic.requiredRolls(wordCount: _wordCount);

  int get _rollCount => DiceMnemonic.normalizeRolls(_rollsController.text).length;

  void _appendRoll(int v) {
    HapticFeedback.selectionClick();
    final normalized = DiceMnemonic.normalizeRolls(_rollsController.text);
    _rollsController.text = '$normalized$v';
    setState(() {
      _mnemonic = null;
      _error = null;
    });
  }

  void _backspace() {
    final normalized = DiceMnemonic.normalizeRolls(_rollsController.text);
    if (normalized.isEmpty) return;
    _rollsController.text = normalized.substring(0, normalized.length - 1);
    setState(() {
      _mnemonic = null;
      _error = null;
    });
  }

  void _clear() {
    _rollsController.clear();
    setState(() {
      _mnemonic = null;
      _error = null;
    });
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (text.trim().isEmpty) return;
    _rollsController.text = DiceMnemonic.normalizeRolls(text);
    setState(() {
      _mnemonic = null;
      _error = null;
    });
  }

  void _generateMnemonic() {
    try {
      final m = DiceMnemonic.mnemonicFromDiceRolls(
        _rollsController.text,
        wordCount: _wordCount,
      );
      setState(() {
        _mnemonic = m;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _mnemonic = null;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = _rollCount;
    final req = _requiredRolls;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dice Wallet (BIP39)'),
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
                    'Gerar mnemonic com rolagens',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Role um dado físico e registre os resultados (1..6). Para 12 palavras: 50 rolagens. Para 24 palavras: 99 rolagens.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 12, label: Text('12 palavras')),
                      ButtonSegment(value: 24, label: Text('24 palavras')),
                    ],
                    selected: {_wordCount},
                    onSelectionChanged: (s) {
                      setState(() {
                        _wordCount = s.first;
                        _mnemonic = null;
                        _error = null;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: (count / req).clamp(0, 1).toDouble(),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Rolagens: $count/$req',
                    style: Theme.of(context).textTheme.labelLarge,
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
                    'Entrada',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _rollsController,
                    maxLines: 4,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Rolagens (1..6)',
                      prefixIcon: const Icon(Icons.casino_outlined),
                      suffixIcon: IconButton(
                        tooltip: 'Colar',
                        icon: const Icon(Icons.content_paste),
                        onPressed: _paste,
                      ),
                      helperText: 'Apenas 1..6 são considerados. Espaços e outros caracteres são ignorados.',
                    ),
                    onChanged: (_) => setState(() {
                      _mnemonic = null;
                      _error = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (int i = 1; i <= 6; i++)
                        SizedBox(
                          width: 56,
                          height: 48,
                          child: FilledButton(
                            onPressed: () => _appendRoll(i),
                            child: Text('$i'),
                          ),
                        ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: _backspace,
                          icon: const Icon(Icons.backspace_outlined),
                          label: const Text('Desfazer'),
                        ),
                      ),
                      SizedBox(
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: _clear,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Limpar'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: count >= req ? _generateMnemonic : null,
                      icon: const Icon(Icons.key_outlined),
                      label: const Text('Gerar mnemonic'),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_mnemonic != null)
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
                    const SizedBox(height: 8),
                    SelectableText(
                      _mnemonic!,
                      style: const TextStyle(fontFamily: 'monospace', height: 1.4),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Copiar',
                          icon: const Icon(Icons.copy),
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: _mnemonic!));
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Mnemonic copiada!'),
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => HdWalletScreen(initialMnemonic: _mnemonic!),
                              ),
                            );
                          },
                          icon: const Icon(Icons.account_tree_outlined),
                          label: const Text('Abrir Carteira HD'),
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
