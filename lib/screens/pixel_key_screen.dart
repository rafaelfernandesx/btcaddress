import 'dart:math' as math;

import 'package:btcaddress/btc_tool.dart';
import 'package:btcaddress/models/address_model.dart';
import 'package:btcaddress/screens/address_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PixelKeyScreen extends StatefulWidget {
  const PixelKeyScreen({super.key});

  @override
  State<PixelKeyScreen> createState() => _PixelKeyScreenState();
}

class _PixelKeyScreenState extends State<PixelKeyScreen> {
  static const int _bytesLen = 32; // 256-bit private key
  static const int _cols = 8; // 8x4 = 32 pixels

  final BitcoinTOOL _btc = BitcoinTOOL();
  final List<int> _bytes = List<int>.filled(_bytesLen, 0);

  String _hexPreview = ''.padLeft(64, '0');
  String _status = 'Toque nos pixels para editar a chave.';

  @override
  void initState() {
    super.initState();
    _syncHex();
  }

  void _syncHex() {
    final hex = _bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    setState(() {
      _hexPreview = hex;
    });
  }

  void _randomize() {
    final r = math.Random.secure();
    for (int i = 0; i < _bytes.length; i++) {
      _bytes[i] = r.nextInt(256);
    }
    _syncHex();
  }

  void _clear() {
    for (int i = 0; i < _bytes.length; i++) {
      _bytes[i] = 0;
    }
    _syncHex();
  }

  Future<void> _setByteDialog(int index) async {
    int temp = _bytes[index];
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Byte ${index + 1}'),
          content: StatefulBuilder(
            builder: (context, setStateLocal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Valor: $temp (0x${temp.toRadixString(16).padLeft(2, '0')})'),
                  const SizedBox(height: 12),
                  Slider(
                    min: 0,
                    max: 255,
                    divisions: 255,
                    value: temp.toDouble(),
                    label: temp.toString(),
                    onChanged: (v) => setStateLocal(() => temp = v.round()),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, temp),
              child: Text('Aplicar'),
            ),
          ],
        );
      },
    );

    if (result == null) return;
    setState(() {
      _bytes[index] = result;
      _status = 'Byte ${index + 1} definido para $result.';
    });
    _syncHex();
  }

  Color _byteColor(int value, Brightness brightness) {
    // Visual: escala de cinza (0..255). No tema escuro, um leve boost.
    final v = brightness == Brightness.dark ? (value * 0.9 + 20).clamp(0, 255).round() : value;
    return Color.fromARGB(255, v, v, v);
  }

  Future<void> _copyHex() async {
    await Clipboard.setData(ClipboardData(text: _hexPreview));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('HEX copiado!'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _generateWalletFromPixels() async {
    // Evitar chave 0...0
    final allZero = _bytes.every((b) => b == 0);
    if (allZero) {
      setState(() {
        _status = 'Chave inválida: todos os bytes são 0.';
      });
      return;
    }

    try {
      _btc.setPrivateKeyHex(_hexPreview);
    } catch (_) {
      setState(() {
        _status = 'Chave inválida (fora do range). Tente alterar alguns pixels.';
      });
      return;
    }

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
      seed: 'pixelkey:${_hexPreview.substring(0, 8)}…',
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
    final brightness = Theme.of(context).brightness;

    return Scaffold(
      appBar: AppBar(
        title: Text('PixelKey (Bloco de Damas)'),
        actions: [
          IconButton(
            tooltip: 'Aleatório',
            onPressed: _randomize,
            icon: const Icon(Icons.casino),
          ),
          IconButton(
            tooltip: 'Zerar',
            onPressed: _clear,
            icon: const Icon(Icons.restart_alt),
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
                    'Como funciona',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Cada “pixel” é 1 byte (0–255) da sua chave privada (32 bytes).\n'
                    'Toque: +1 | Duplo toque: -1 | Pressione: escolher valor.',
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Chave Privada (HEX)',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copiar HEX',
                        onPressed: _copyHex,
                        icon: const Icon(Icons.copy),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Theme.of(context).colorScheme.surface,
                      border: Border.all(
                        color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: SelectableText(
                      _hexPreview,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
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
                    'Pixels (32 bytes)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final spacing = 8.0;
                      final tileSize = (constraints.maxWidth - (spacing * (_cols - 1))) / _cols;

                      return Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: List.generate(_bytesLen, (i) {
                          final byte = _bytes[i];
                          final row = i ~/ _cols;
                          final col = i % _cols;
                          final isChecker = (row + col).isEven;

                          final base = Theme.of(context).colorScheme.surface;
                          final checkerBg = isChecker ? base : base.withValues(alpha: 0.7);

                          return SizedBox(
                            width: tileSize,
                            height: tileSize,
                            child: Material(
                              color: checkerBg,
                              borderRadius: BorderRadius.circular(10),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () {
                                  setState(() {
                                    _bytes[i] = (byte + 1) & 0xFF;
                                    _status = 'Byte ${i + 1}: ${_bytes[i]}';
                                  });
                                  _syncHex();
                                },
                                onDoubleTap: () {
                                  setState(() {
                                    _bytes[i] = (byte - 1) & 0xFF;
                                    _status = 'Byte ${i + 1}: ${_bytes[i]}';
                                  });
                                  _syncHex();
                                },
                                onLongPress: () => _setByteDialog(i),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: tileSize * 0.70,
                                      height: tileSize * 0.70,
                                      decoration: BoxDecoration(
                                        color: _byteColor(byte, brightness),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _status,
                    style: Theme.of(context).textTheme.bodySmall,
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
              label: const Text('Gerar carteira a partir dos pixels'),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
