import 'package:btcaddress/btc_tool.dart';
import 'package:btcaddress/models/address_model.dart';
import 'package:btcaddress/screens/address_detail_screen.dart';
import 'package:btcaddress/widgets/copyable_textfield.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PixelKeyScreen extends StatefulWidget {
  const PixelKeyScreen({super.key});

  @override
  State<PixelKeyScreen> createState() => _PixelKeyScreenState();
}

class _PixelKeyScreenState extends State<PixelKeyScreen> {
  static const int _bytesLen = 32; // 256-bit private key
  static const int _valueCount = 256; // 0..255

  final BitcoinTOOL _btc = BitcoinTOOL();
  final List<int> _bytes = List<int>.filled(_bytesLen, 0);

  final TextEditingController _hexController = TextEditingController();
  final TextEditingController _hexEffectiveController = TextEditingController();
  final TextEditingController _legacyController = TextEditingController();
  final TextEditingController _compressedController = TextEditingController();

  int _selectedByteIndex = 0;
  String _error = '';
  bool _updatingFromUi = false;

  @override
  void initState() {
    super.initState();
    _applyHexInput('');
  }

  @override
  void dispose() {
    _hexController.dispose();
    _hexEffectiveController.dispose();
    _legacyController.dispose();
    _compressedController.dispose();
    super.dispose();
  }

  String _sanitizeHex(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^0-9a-fA-F]'), '').toLowerCase();
    if (cleaned.length <= 64) return cleaned;
    // Mantém os últimos 64 caracteres (útil para colagens com prefixo/extra)
    return cleaned.substring(cleaned.length - 64);
  }

  void _applyHexInput(String input, {bool forceControllerToEffective = false}) {
    if (_updatingFromUi) return;

    final sanitized = _sanitizeHex(input);
    final effective = sanitized.padLeft(64, '0');

    for (int i = 0; i < _bytesLen; i++) {
      _bytes[i] = int.parse(effective.substring(i * 2, i * 2 + 2), radix: 16);
    }

    String legacy = '';
    String compressed = '';
    String error = '';

    final keyInt = BigInt.parse(effective, radix: 16);
    if (keyInt == BigInt.zero) {
      error = 'Chave inválida: valor 0.';
    } else {
      try {
        _btc.setPrivateKeyHex(effective);
        legacy = _btc.getAddress(false);
        compressed = _btc.getAddress(true);
      } catch (_) {
        error = 'Chave inválida (fora do range 1..n-1).';
      }
    }

    setState(() {
      _error = error;
      _hexEffectiveController.text = effective;
      _legacyController.text = legacy;
      _compressedController.text = compressed;
    });

    if (forceControllerToEffective) {
      _updatingFromUi = true;
      _hexController.text = effective;
      _hexController.selection = TextSelection.fromPosition(
        TextPosition(offset: _hexController.text.length),
      );
      _updatingFromUi = false;
    }
  }

  void _setByteValue(int value) {
    setState(() {
      _bytes[_selectedByteIndex] = value;
    });
    final effective = _bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    _applyHexInput(effective, forceControllerToEffective: true);
  }

  Future<void> _generateWalletFromPixels() async {
    if (_error.isNotEmpty) return;
    final address = _buildAddressModel();
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddressDetailScreen(address: address),
      ),
    );
  }

  AddressModel _buildAddressModel() {
    return AddressModel(
      seed: 'pixelkey:${_hexEffectiveController.text.substring(0, 8)}…',
      addressCompressed: _btc.getAddress(true),
      addressUncompressed: _btc.getAddress(false),
      privateKeyHex: _btc.getPrivateKey(),
      privateKeyWif: _btc.getWif(false),
      privateKeyWifCompressed: _btc.getWif(true),
      publicKeyHex: _btc.getPubKey(),
      publicKeyHexCompressed: _btc.getPubKey(compressed: true),
      timestamp: DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedValue = _bytes[_selectedByteIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text('PixelKey (Bloco de Damas)'),
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
                    'Selecione um byte (1..32) e depois escolha o valor na grade 0..255.\n'
                    'Você também pode editar o HEX manualmente: a grade e os bytes acompanham.',
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
                    'Chave privada (HEX)',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _hexController,
                    decoration: const InputDecoration(
                      labelText: 'Editar HEX (0..64 chars)',
                      prefixIcon: Icon(Icons.tag),
                      helperText: 'A chave efetiva usa padding à esquerda até 64 caracteres.',
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F]')),
                      LengthLimitingTextInputFormatter(64),
                    ],
                    onChanged: (v) => _applyHexInput(v),
                  ),
                  const SizedBox(height: 12),
                  CopyableTextField(
                    controller: _hexEffectiveController,
                    label: 'HEX efetivo (64 chars)',
                    prefixIcon: Icons.lock_outline,
                  ),
                  if (_error.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_error.isEmpty && _compressedController.text.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Endereços',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
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
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
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
                          'Byte selecionado: ${_selectedByteIndex + 1}  |  Valor: $selectedValue (0x${selectedValue.toRadixString(16).padLeft(2, '0')})',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 54,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _bytesLen,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final isSelected = i == _selectedByteIndex;
                        final byte = _bytes[i];
                        return ChoiceChip(
                          selected: isSelected,
                          label: Text('${i + 1}: ${byte.toRadixString(16).padLeft(2, '0').toUpperCase()}'),
                          onSelected: (_) {
                            setState(() {
                              _selectedByteIndex = i;
                            });
                          },
                        );
                      },
                    ),
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
                    'Grade 0..255 (clique para marcar e aplicar)',
                    style: Theme.of(context).textTheme.titleLarge,
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
                    itemCount: _valueCount,
                    itemBuilder: (context, value) {
                      final isSelected = value == selectedValue;
                      final hex = value.toRadixString(16).padLeft(2, '0').toUpperCase();

                      final bg = isSelected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.18) : Theme.of(context).colorScheme.surface;

                      return InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _setByteValue(value),
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
                              hex,
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    fontFamily: 'monospace',
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _generateWalletFromPixels,
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
