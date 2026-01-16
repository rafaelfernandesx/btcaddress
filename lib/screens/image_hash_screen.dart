import 'dart:math';

import 'package:btcaddress/bitcoin/image_hash.dart';
import 'package:btcaddress/btc_tool.dart';
import 'package:btcaddress/theme/app_theme.dart';
import 'package:btcaddress/widgets/copyable_textfield.dart';
import 'package:btcaddress/widgets/qr_code_dialog.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ImageHashScreen extends StatefulWidget {
  const ImageHashScreen({super.key});

  @override
  State<ImageHashScreen> createState() => _ImageHashScreenState();
}

class _ImageHashScreenState extends State<ImageHashScreen> {
  final _saltHexController = TextEditingController();
  final _seedController = TextEditingController();
  final _privHexController = TextEditingController();
  final _legacyController = TextEditingController();
  final _compressedController = TextEditingController();
  final _bech32Controller = TextEditingController();
  final _taprootController = TextEditingController();

  Uint8List? _imageBytes;
  String _fileName = '';
  int _fileSize = 0;

  bool _testnet = false;
  bool _showSecret = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _generateSalt();
  }

  @override
  void dispose() {
    _saltHexController.dispose();
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

  void _generateSalt() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    setState(() {
      _saltHexController.text = hex;
      _error = '';
      _clearResult();
    });
  }

  Future<void> _pickImage() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
        allowMultiple: false,
      );
      if (res == null || res.files.isEmpty) return;

      final file = res.files.first;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        setState(() {
          _error = 'Não foi possível ler os bytes da imagem (tente outra).';
        });
        return;
      }

      setState(() {
        _imageBytes = bytes;
        _fileName = file.name;
        _fileSize = file.size;
        _error = '';
        _clearResult();
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    }
  }

  void _generate() {
    try {
      final bytes = _imageBytes;
      if (bytes == null || bytes.isEmpty) {
        throw const FormatException('Escolha uma imagem primeiro.');
      }

      final material = ImageHashGenerator.fromBytes(
        imageBytes: bytes,
        saltHex: _saltHexController.text,
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

  @override
  Widget build(BuildContext context) {
    final hasImage = _imageBytes != null && _imageBytes!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ImageHash (imagem → chave)'),
        actions: [
          IconButton(
            tooltip: 'Novo salt',
            icon: const Icon(Icons.refresh),
            onPressed: _generateSalt,
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
                    'Carteira por imagem',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A mesma imagem + mesmo salt → mesma chave. Se você perder a seed gerada (texto), a única forma de recriar é usando a mesma imagem e o mesmo salt. Cuidado: compartilhar a seed equivale a compartilhar o segredo.',
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: _pickImage,
                          icon: const Icon(Icons.image_outlined),
                          label: const Text('Escolher imagem'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: hasImage ? _generate : null,
                          icon: const Icon(Icons.auto_fix_high_outlined),
                          label: const Text('Gerar'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (hasImage)
                    Text(
                      'Arquivo: ${_fileName.isEmpty ? '(sem nome)' : _fileName} — $_fileSize bytes',
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  else
                    Text(
                      'Nenhuma imagem selecionada.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _saltHexController,
                    decoration: const InputDecoration(
                      labelText: 'Salt local (HEX)',
                      prefixIcon: Icon(Icons.lock_outline),
                      helperText: 'Gerado automaticamente; troque se quiser. Guarde junto da imagem/seed.',
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F]')),
                    ],
                    onChanged: (_) => _clearResult(),
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
                                title: 'Seed (ImageHash)',
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    CopyableTextField(
                      controller: _seedController,
                      label: 'Seed (texto) — guarde para recuperar',
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
