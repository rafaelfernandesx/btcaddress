import 'dart:convert';

import 'package:btcaddress/bitcoin/hd_wallet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../theme/app_theme.dart';
import '../widgets/qr_code_dialog.dart';

class HdWalletScreen extends StatefulWidget {
  final String? initialMnemonic;

  const HdWalletScreen({super.key, this.initialMnemonic});

  @override
  State<HdWalletScreen> createState() => _HdWalletScreenState();
}

class _HdWalletScreenState extends State<HdWalletScreen> {
  final _mnemonicController = TextEditingController();
  final _passphraseController = TextEditingController();
  final _accountController = TextEditingController(text: '0');
  final _startIndexController = TextEditingController(text: '0');
  final _countController = TextEditingController(text: '5');
  final _watchOnlyImportController = TextEditingController();

  HdDerivationScheme _scheme = HdDerivationScheme.bip84;
  bool _testnet = false;
  bool _change = false;
  bool _showSecrets = false;
  bool _loading = false;

  String? _error;
  List<HdDerivedAddress> _derived = [];
  HdWatchOnlyExport? _watchOnly;
  HdWatchOnlyExport? _watchOnlyImported;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialMnemonic;
    if (initial != null && initial.trim().isNotEmpty) {
      _mnemonicController.text = initial.trim();
    }
  }

  @override
  void dispose() {
    _mnemonicController.dispose();
    _passphraseController.dispose();
    _accountController.dispose();
    _startIndexController.dispose();
    _countController.dispose();
    _watchOnlyImportController.dispose();
    super.dispose();
  }

  int _parseInt(TextEditingController c, {required int fallback, int min = 0, int max = 1 << 31}) {
    final v = int.tryParse(c.text.trim());
    if (v == null) return fallback;
    if (v < min) return min;
    if (v > max) return max;
    return v;
  }

  void _generateMnemonic12() {
    setState(() {
      _mnemonicController.text = HdWalletDeriver.generateMnemonic(strength: 128);
      _error = null;
      _derived = [];
      _watchOnly = null;
      _watchOnlyImported = null;
    });
  }

  void _generateMnemonic24() {
    setState(() {
      _mnemonicController.text = HdWalletDeriver.generateMnemonic(strength: 256);
      _error = null;
      _derived = [];
      _watchOnly = null;
      _watchOnlyImported = null;
    });
  }

  Future<void> _pasteMnemonic() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) return;
    setState(() {
      _mnemonicController.text = text;
      _error = null;
      _derived = [];
      _watchOnly = null;
      _watchOnlyImported = null;
    });
  }

  HdDerivationScheme? _schemeFromName(String name) {
    for (final s in HdDerivationScheme.values) {
      if (s.name == name) return s;
    }
    return null;
  }

  Future<void> _importWatchOnly() async {
    final raw = _watchOnlyImportController.text.trim();
    if (raw.isEmpty) return;

    setState(() {
      _error = null;
      _watchOnlyImported = null;
    });

    try {
      HdWatchOnlyExport export;

      if (raw.startsWith('{')) {
        final decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('JSON inválido (esperado objeto).');
        }
        export = HdWatchOnlyExport.fromJson(decoded);
      } else {
        final account = _parseInt(_accountController, fallback: 0, min: 0, max: 9999);
        final purpose = switch (_scheme) {
          HdDerivationScheme.bip44 => 44,
          HdDerivationScheme.bip84 => 84,
          HdDerivationScheme.bip86 => 86,
        };
        final coinType = _testnet ? 1 : 0;
        export = HdWatchOnlyExport(
          version: 1,
          exportedAt: DateTime.now().toIso8601String(),
          scheme: _scheme.name,
          testnet: _testnet,
          accountPath: "m/$purpose'/$coinType'/$account'",
          extendedPublicKey: raw,
        );
      }

      final parsedScheme = _schemeFromName(export.scheme);
      if (parsedScheme != null) {
        setState(() {
          _scheme = parsedScheme;
          _testnet = export.testnet;
        });
      }

      setState(() {
        _watchOnlyImported = export;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    }
  }

  Future<void> _deriveFromWatchOnly() async {
    final export = _watchOnlyImported;
    if (export == null) return;

    setState(() {
      _loading = true;
      _error = null;
      _derived = [];
      _showSecrets = false;
    });

    try {
      final start = _parseInt(_startIndexController, fallback: 0, min: 0, max: 1000000);
      final count = _parseInt(_countController, fallback: 5, min: 1, max: 50);

      final list = HdWalletDeriver.deriveBatchFromWatchOnly(
        watchOnly: export,
        change: _change ? 1 : 0,
        startIndex: start,
        count: count,
      );

      if (!mounted) return;
      setState(() {
        _derived = list;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _buildWatchOnly() async {
    final mnemonic = _mnemonicController.text;
    final passphrase = _passphraseController.text;

    setState(() {
      _loading = true;
      _error = null;
      _watchOnly = null;
    });

    try {
      final account = _parseInt(_accountController, fallback: 0, min: 0, max: 9999);
      final export = HdWalletDeriver.deriveWatchOnly(
        mnemonic: mnemonic,
        passphrase: passphrase,
        scheme: _scheme,
        testnet: _testnet,
        account: account,
      );

      if (!mounted) return;
      setState(() {
        _watchOnly = export;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _derive() async {
    final mnemonic = _mnemonicController.text;
    final passphrase = _passphraseController.text;

    setState(() {
      _loading = true;
      _error = null;
      _derived = [];
      _watchOnly = null;
    });

    try {
      final account = _parseInt(_accountController, fallback: 0, min: 0, max: 9999);
      final start = _parseInt(_startIndexController, fallback: 0, min: 0, max: 1000000);
      final count = _parseInt(_countController, fallback: 5, min: 1, max: 50);

      final list = HdWalletDeriver.deriveBatch(
        mnemonic: mnemonic,
        passphrase: passphrase,
        scheme: _scheme,
        testnet: _testnet,
        account: account,
        change: _change ? 1 : 0,
        startIndex: start,
        count: count,
      );

      if (!mounted) return;
      setState(() {
        _derived = list;
      });

      // Atualiza watch-only junto para facilitar fluxo.
      final export = HdWalletDeriver.deriveWatchOnly(
        mnemonic: mnemonic,
        passphrase: passphrase,
        scheme: _scheme,
        testnet: _testnet,
        account: account,
      );
      if (!mounted) return;
      setState(() {
        _watchOnly = export;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String _schemeLabel(HdDerivationScheme s) {
    return switch (s) {
      HdDerivationScheme.bip84 => "BIP84 (m/84'/...) — P2WPKH (bech32)",
      HdDerivationScheme.bip86 => "BIP86 (m/86'/...) — P2TR (taproot)",
      HdDerivationScheme.bip44 => "BIP44 (m/44'/...) — Legacy (P2PKH)",
    };
  }

  String _mainAddress(HdDerivedAddress a) {
    return switch (_scheme) {
      HdDerivationScheme.bip84 => a.addressBech32,
      HdDerivationScheme.bip86 => a.addressTaproot,
      HdDerivationScheme.bip44 => a.addressLegacy,
    };
  }

  String _watchOnlyTitle() {
    return switch (_scheme) {
      HdDerivationScheme.bip84 => 'zpub/vpub (watch-only)',
      HdDerivationScheme.bip86 => 'xpub/tpub (watch-only)',
      HdDerivationScheme.bip44 => 'xpub/tpub (watch-only)',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Carteira HD (BIP39/BIP32)'),
        actions: [
          IconButton(
            tooltip: 'Gerar 12 palavras',
            icon: const Icon(Icons.casino_outlined),
            onPressed: _generateMnemonic12,
          ),
          IconButton(
            tooltip: 'Gerar 24 palavras',
            icon: const Icon(Icons.casino),
            onPressed: _generateMnemonic24,
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
                    'Mnemonic (BIP39)',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _mnemonicController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: 'Cole ou gere uma mnemonic',
                      prefixIcon: const Icon(Icons.key),
                      suffixIcon: IconButton(
                        tooltip: 'Colar',
                        icon: const Icon(Icons.content_paste),
                        onPressed: _pasteMnemonic,
                      ),
                      helperText: 'Dica: não compartilhe sua mnemonic. Use apenas para fins educacionais.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passphraseController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Passphrase (opcional)',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _showSecrets,
                    onChanged: (v) => setState(() => _showSecrets = v),
                    title: const Text('Mostrar segredos (chaves privadas) na tela'),
                    subtitle: const Text('Recomendado desativado. Cuidado ao gravar/printar tela.'),
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
                    _watchOnlyTitle(),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Exporta uma chave pública estendida para acompanhamento (sem chaves privadas).',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _loading ? null : _buildWatchOnly,
                      icon: const Icon(Icons.remove_red_eye_outlined),
                      label: const Text('Gerar watch-only'),
                    ),
                  ),
                  if (_watchOnly != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _watchOnly!.accountPath,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      _watchOnly!.extendedPublicKey,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Copiar chave',
                          icon: const Icon(Icons.copy),
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: _watchOnly!.extendedPublicKey),
                            );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Copiado!'),
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          tooltip: 'QR da chave',
                          icon: const Icon(Icons.qr_code_2_outlined),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => QRCodeDialog(
                                data: _watchOnly!.extendedPublicKey,
                                title: 'Watch-only',
                              ),
                            );
                          },
                        ),
                        IconButton(
                          tooltip: 'Compartilhar chave',
                          icon: const Icon(Icons.share_outlined),
                          onPressed: () {
                            Share.share(
                              _watchOnly!.extendedPublicKey,
                              subject: 'Watch-only (${_watchOnly!.scheme})',
                            );
                          },
                        ),
                        IconButton(
                          tooltip: 'QR do JSON (watch-only)',
                          icon: const Icon(Icons.qr_code_outlined),
                          onPressed: () {
                            final payload = jsonEncode(_watchOnly!.toJson());
                            showDialog(
                              context: context,
                              builder: (_) => QRCodeDialog(
                                data: payload,
                                title: 'Export watch-only (JSON)',
                              ),
                            );
                          },
                        ),
                        IconButton(
                          tooltip: 'Compartilhar JSON (watch-only)',
                          icon: const Icon(Icons.share_rounded),
                          onPressed: () {
                            final payload = jsonEncode(_watchOnly!.toJson());
                            Share.share(
                              payload,
                              subject: 'Export watch-only (JSON)',
                            );
                          },
                        ),
                      ],
                    ),
                  ],
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
                    'Importar watch-only',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Cole um JSON watch-only ou uma chave estendida (xpub/zpub/vpub/tpub) e derive endereços sem expor segredos.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _watchOnlyImportController,
                    minLines: 2,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Watch-only (JSON ou xpub/zpub/...)',
                      prefixIcon: Icon(Icons.input_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _loading ? null : _importWatchOnly,
                          icon: const Icon(Icons.download_outlined),
                          label: const Text('Importar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: (_loading || _watchOnlyImported == null) ? null : _deriveFromWatchOnly,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Derivar (watch-only)'),
                        ),
                      ),
                    ],
                  ),
                  if (_watchOnlyImported != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _watchOnlyImported!.accountPath,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      _watchOnlyImported!.extendedPublicKey,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                    ),
                  ],
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
                    'Derivação',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<HdDerivationScheme>(
                    key: ValueKey(_scheme),
                    initialValue: _scheme,
                    items: HdDerivationScheme.values
                        .map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child: Text(_schemeLabel(s)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _scheme = v ?? _scheme),
                    decoration: const InputDecoration(
                      labelText: 'Esquema',
                      prefixIcon: Icon(Icons.account_tree_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _accountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Account',
                            prefixIcon: Icon(Icons.folder_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _startIndexController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Início',
                            prefixIcon: Icon(Icons.looks_one_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _countController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Qtde',
                            prefixIcon: Icon(Icons.format_list_numbered),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _change,
                    onChanged: (v) => setState(() => _change = v),
                    title: const Text('Change (m/.../1/...)'),
                    subtitle: const Text('Desativado = receiving (0).'),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _testnet,
                    onChanged: (v) => setState(() => _testnet = v),
                    title: const Text('Testnet'),
                    subtitle: const Text('Ative para coin_type=1 e endereços tb1/m/n/2.'),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _loading ? null : _derive,
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.play_arrow),
                      label: Text(_loading ? 'Derivando...' : 'Derivar endereços'),
                      style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryColor),
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
          if (_derived.isNotEmpty)
            Text(
              'Endereços',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          const SizedBox(height: 8),
          ..._derived.map((a) {
            final addr = _mainAddress(a);
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.path,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontFamily: 'monospace',
                          ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      addr,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Copiar endereço',
                          icon: const Icon(Icons.copy),
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: addr));
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Endereço copiado!'),
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          tooltip: 'QR Code',
                          icon: const Icon(Icons.qr_code),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => QRCodeDialog(
                                data: addr,
                                title: 'Endereço',
                              ),
                            );
                          },
                        ),
                        const Spacer(),
                        Text(
                          _testnet ? 'testnet' : 'mainnet',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ],
                    ),
                    if (_showSecrets) ...[
                      const Divider(height: 24),
                      Text('Private key (hex)', style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 4),
                      SelectableText(a.privateKeyHex, style: const TextStyle(fontFamily: 'monospace')),
                      const SizedBox(height: 8),
                      Text('WIF (compressed)', style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 4),
                      SelectableText(a.privateKeyWifCompressed, style: const TextStyle(fontFamily: 'monospace')),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
