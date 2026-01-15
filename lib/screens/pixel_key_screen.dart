import 'package:btcaddress/btc_tool.dart';
import 'package:btcaddress/models/address_model.dart';
import 'package:btcaddress/screens/address_detail_screen.dart';
import 'package:btcaddress/widgets/copyable_textfield.dart';
import 'package:flutter/material.dart';

class PixelKeyScreen extends StatefulWidget {
  const PixelKeyScreen({super.key});

  @override
  State<PixelKeyScreen> createState() => _PixelKeyScreenState();
}

class _PixelKeyScreenState extends State<PixelKeyScreen> {
  static const int _bitCount = 256; // 256 botões = 256 bits

  // 0..255
  // Regra de conversão: o índice 0 representa o bit mais significativo (bit 255).
  // Assim, a grade lida da esquerda->direita / cima->baixo monta a chave em big-endian.
  final Set<int> _selectedBits = <int>{};

  final BitcoinTOOL _btc = BitcoinTOOL();
  final TextEditingController _privHexController = TextEditingController();
  final TextEditingController _legacyController = TextEditingController();
  final TextEditingController _compressedController = TextEditingController();

  String _error = '';

  @override
  void initState() {
    super.initState();
    _recompute();
  }

  @override
  void dispose() {
    _privHexController.dispose();
    _legacyController.dispose();
    _compressedController.dispose();
    super.dispose();
  }

  void _recompute() {
    BigInt key = BigInt.zero;
    for (final idx in _selectedBits) {
      final shift = 255 - idx;
      key |= (BigInt.one << shift);
    }

    final hex = key.toRadixString(16).padLeft(64, '0');
    _privHexController.text = hex;

    String legacy = '';
    String compressed = '';
    String error = '';

    if (key == BigInt.zero) {
      error = 'Selecione pelo menos 1 bit para gerar a chave.';
    } else {
      try {
        _btc.setPrivateKeyHex(hex);
        legacy = _btc.getAddress(false);
        compressed = _btc.getAddress(true);
      } catch (_) {
        error = 'Chave inválida (fora do range 1..n-1).';
      }
    }

    setState(() {
      _error = error;
      _legacyController.text = legacy;
      _compressedController.text = compressed;
    });
  }

  void _toggleBit(int index) {
    setState(() {
      if (_selectedBits.contains(index)) {
        _selectedBits.remove(index);
      } else {
        _selectedBits.add(index);
      }
    });
    _recompute();
  }

  Future<void> _openDetails() async {
    if (_error.isNotEmpty) return;

    final model = AddressModel(
      seed: 'pixelkey-bits:${_selectedBits.length}bits',
      addressBech32: _btc.getBech32Address(),
      addressTaproot: _btc.getTaprootAddress(),
      addressCompressed: _btc.getAddress(true),
      addressUncompressed: _btc.getAddress(false),
      privateKeyHex: _btc.getPrivateKey(),
      privateKeyWif: _btc.getWif(false),
      privateKeyWifCompressed: _btc.getWif(true),
      publicKeyHex: _btc.getPubKey(),
      publicKeyHexCompressed: _btc.getPubKey(compressed: true),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('PixelKey (256 bits)'),
        actions: [
          IconButton(
            tooltip: 'Limpar seleção',
            onPressed: () {
              setState(() {
                _selectedBits.clear();
              });
              _recompute();
            },
            icon: const Icon(Icons.delete_outline),
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
                    'Grade 16x16 (256 botões)',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Cada botão representa 1 bit da chave privada. Você pode selecionar/desselecionar vários.\n\n'
                    'O padrão vira um binário de 256 bits e é convertido para HEX automaticamente.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 16,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      childAspectRatio: 1,
                    ),
                    itemCount: _bitCount,
                    itemBuilder: (context, index) {
                      final isSelected = _selectedBits.contains(index);
                      final label = index.toRadixString(16).padLeft(2, '0').toUpperCase();

                      final bg = isSelected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.18) : Theme.of(context).colorScheme.surface;

                      return InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _toggleBit(index),
                        child: Container(
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor.withValues(alpha: 0.35),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              label,
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    fontFamily: 'monospace',
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Selecionados: ${_selectedBits.length} / 256',
                    style: Theme.of(context).textTheme.bodySmall,
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
                    'Resultado',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  CopyableTextField(
                    controller: _privHexController,
                    label: 'PrivateKey (HEX)',
                    prefixIcon: Icons.lock_outline,
                  ),
                  const SizedBox(height: 12),
                  if (_error.isNotEmpty)
                    Text(
                      _error,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                    )
                  else ...[
                    CopyableTextField(
                      controller: _legacyController,
                      label: 'Legacy (não comprimido)',
                      prefixIcon: Icons.account_balance_wallet_outlined,
                    ),
                    const SizedBox(height: 12),
                    CopyableTextField(
                      controller: _compressedController,
                      label: 'Comprimido (recomendado)',
                      prefixIcon: Icons.account_balance_wallet,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openDetails,
              icon: const Icon(Icons.account_balance_wallet),
              label: const Text('Abrir detalhes da carteira'),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
