import 'dart:math' as math;

import 'package:btcaddress/btc_tool.dart';
import 'package:btcaddress/models/address_model.dart';
import 'package:btcaddress/screens/address_detail_screen.dart';
import 'package:btcaddress/screens/audio_key_screen.dart';
import 'package:btcaddress/screens/balance_checker_screen.dart';
import 'package:btcaddress/screens/dice_wallet_screen.dart';
import 'package:btcaddress/screens/duet_key_screen.dart';
import 'package:btcaddress/screens/hd_wallet_screen.dart';
import 'package:btcaddress/screens/history_screen.dart';
import 'package:btcaddress/screens/image_hash_screen.dart';
import 'package:btcaddress/screens/pixel_key_screen.dart';
import 'package:btcaddress/screens/puzzle_lab_screen.dart';
import 'package:btcaddress/screens/qr_mix_screen.dart';
import 'package:btcaddress/screens/shake_key_screen.dart';
import 'package:btcaddress/screens/split_key_screen.dart';
import 'package:btcaddress/screens/tap_key_screen.dart';
import 'package:btcaddress/screens/treasure_phrase_screen.dart';
import 'package:btcaddress/services/blockchain_service.dart';
import 'package:btcaddress/services/storage_service.dart';
import 'package:btcaddress/theme/app_theme.dart';
import 'package:btcaddress/widgets/copyable_textfield.dart';
import 'package:btcaddress/widgets/qr_code_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = false;
  final StorageService _storage = StorageService();

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final isDark = await _storage.getThemeMode();
    setState(() {
      _isDarkMode = isDark;
    });
  }

  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
    _storage.setThemeMode(_isDarkMode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bitcoin Address Generator',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: MyHomePage(
        isDarkMode: _isDarkMode,
        onThemeToggle: _toggleTheme,
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onThemeToggle;

  const MyHomePage({
    super.key,
    required this.isDarkMode,
    required this.onThemeToggle,
  });

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin {
  final btc = BitcoinTOOL();
  final seedController = TextEditingController();
  final hexController = TextEditingController();
  final wifController = TextEditingController();
  final p2pkhController = TextEditingController();
  final p2pkhcController = TextEditingController();
  final bech32Controller = TextEditingController();
  final taprootController = TextEditingController();
  final ripemdcController = TextEditingController();
  final ripemdController = TextEditingController();
  final pubKeyHexController = TextEditingController();
  final pubKeyHexcController = TextEditingController();
  final privKeyHexController = TextEditingController();
  final privKeyWifController = TextEditingController();
  final privKeyWifcController = TextEditingController();

  final StorageService _storage = StorageService();
  List<AddressModel> _history = [];
  bool _isLoading = false;
  String _inputMethod = 'seed'; // seed, hex, or wif
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
    _loadHistory();
  }

  @override
  void dispose() {
    _animationController.dispose();
    seedController.dispose();
    hexController.dispose();
    wifController.dispose();
    p2pkhController.dispose();
    p2pkhcController.dispose();
    bech32Controller.dispose();
    taprootController.dispose();
    ripemdcController.dispose();
    ripemdController.dispose();
    pubKeyHexController.dispose();
    pubKeyHexcController.dispose();
    privKeyHexController.dispose();
    privKeyWifController.dispose();
    privKeyWifcController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final history = await _storage.getHistory();
    setState(() {
      _history = history;
    });
  }

  void _clearOutputs() {
    setState(() {
      p2pkhController.clear();
      p2pkhcController.clear();
      bech32Controller.clear();
      taprootController.clear();
      ripemdController.clear();
      ripemdcController.clear();
      pubKeyHexController.clear();
      pubKeyHexcController.clear();
      privKeyHexController.clear();
      privKeyWifController.clear();
      privKeyWifcController.clear();
    });
  }

  void update() {
    setState(() {
      p2pkhController.text = btc.getAddress();
      p2pkhcController.text = btc.getAddress(true);
      bech32Controller.text = btc.getBech32Address();
      taprootController.text = btc.getTaprootAddress();
      ripemdController.text = btc.getRipeMd160Address();
      ripemdcController.text = btc.getRipeMd160Address(true);
      pubKeyHexController.text = btc.getPubKey();
      pubKeyHexcController.text = btc.getPubKey(compressed: true);
      privKeyHexController.text = btc.getPrivateKey();
      privKeyWifController.text = btc.getWif();
      privKeyWifcController.text = btc.getWif(true);
    });

    _animationController.forward(from: 0);
  }

  Future<void> _saveToHistory() async {
    if (p2pkhcController.text.isEmpty) return;

    final address = AddressModel(
      seed: seedController.text,
      addressCompressed: p2pkhcController.text,
      addressUncompressed: p2pkhController.text,
      addressBech32: bech32Controller.text,
      addressTaproot: taprootController.text,
      privateKeyHex: privKeyHexController.text,
      privateKeyWif: privKeyWifController.text,
      privateKeyWifCompressed: privKeyWifcController.text,
      publicKeyHex: pubKeyHexController.text,
      publicKeyHexCompressed: pubKeyHexcController.text,
      timestamp: DateTime.now(),
    );

    await _storage.saveAddress(address);
    await _loadHistory();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Endereço salvo no histórico!'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Ver',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddressDetailScreen(address: address),
                ),
              );
            },
          ),
        ),
      );
    }
  }

  Future<String> getBalance(String address) async {
    try {
      return await BlockchainService().getBalanceBtc(address);
    } catch (e) {
      return 'Erro ao consultar';
    }
  }

  void _generateRandom() {
    final random = math.Random.secure();
    final seed = List.generate(32, (_) => random.nextInt(256)).map((e) => e.toRadixString(16).padLeft(2, '0')).join();

    seedController.text = seed;
    btc.setPrivateKeyFromSeed(seed);
    update();
  }

  Future<void> _openHistory() async {
    final result = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (context) => HistoryScreen(
          history: _history,
          onClear: () async {
            await _storage.clearHistory();
            await _loadHistory();
          },
        ),
      ),
    );

    if (!mounted) return;
    if (result == null) return;
    await _loadHistory();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Histórico atualizado: $result itens.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildShortcuts(BuildContext context) {
    final items = <({IconData icon, String title, String subtitle, VoidCallback onTap})>[
      (
        icon: Icons.group_outlined,
        title: 'Dueto',
        subtitle: '2 pessoas (A+B)',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const DuetKeyScreen(),
            ),
          );
        },
      ),
      (
        icon: Icons.touch_app_outlined,
        title: 'TapKey',
        subtitle: 'Ritmo (seed + HEX)',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const TapKeyScreen(),
            ),
          );
        },
      ),
      (
        icon: Icons.call_split_outlined,
        title: 'SplitKey',
        subtitle: '2 partes (A+B)',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const SplitKeyScreen(),
            ),
          );
        },
      ),
      (
        icon: Icons.qr_code_2_outlined,
        title: 'QR-Mix',
        subtitle: 'Texto + salt',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const QrMixScreen(),
            ),
          );
        },
      ),
      (
        icon: Icons.image_outlined,
        title: 'ImageHash',
        subtitle: 'Imagem → chave',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ImageHashScreen(),
            ),
          );
        },
      ),
      (
        icon: Icons.vibration_outlined,
        title: 'ShakeKey',
        subtitle: 'Agite (sensores)',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ShakeKeyScreen(),
            ),
          );
        },
      ),
      (
        icon: Icons.audiotrack_outlined,
        title: 'AudioKey',
        subtitle: 'Áudio → chave',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AudioKeyScreen(),
            ),
          );
        },
      ),
      (
        icon: Icons.password_outlined,
        title: 'Treasure',
        subtitle: 'Frase + KDF',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const TreasurePhraseScreen(),
            ),
          );
        },
      ),
      (
        icon: Icons.account_balance_wallet_outlined,
        title: 'Saldo',
        subtitle: 'Consultar endereço',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const BalanceCheckerScreen(),
            ),
          );
        },
      ),
      (
        icon: Icons.account_tree_outlined,
        title: 'HD Wallet',
        subtitle: 'BIP39/BIP32',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const HdWalletScreen(),
            ),
          );
        },
      ),
      (
        icon: Icons.casino_outlined,
        title: 'Dice Wallet',
        subtitle: 'Entropia física',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const DiceWalletScreen(),
            ),
          );
        },
      ),
      (
        icon: Icons.grid_4x4,
        title: 'PixelKey',
        subtitle: 'Chave por pixels',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const PixelKeyScreen(),
            ),
          );
        },
      ),
      (
        icon: Icons.emoji_objects_outlined,
        title: 'Puzzle Lab',
        subtitle: 'Educacional',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const PuzzleLabScreen(),
            ),
          );
        },
      ),
      (
        icon: Icons.history,
        title: 'Histórico',
        subtitle: 'Exportar/importar',
        onTap: _openHistory,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 800
            ? 3
            : constraints.maxWidth >= 520
                ? 3
                : 2;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Atalhos',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Acesso rápido às ferramentas do app.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: crossAxisCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: [
                for (final it in items)
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: it.onTap,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                              foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                              child: Icon(it.icon),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    it.title,
                                    style: Theme.of(context).textTheme.titleMedium,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    it.subtitle,
                                    style: Theme.of(context).textTheme.bodySmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.currency_bitcoin,
                color: AppTheme.primaryColor,
              ),
              SizedBox(width: 8),
              Text('Bitcoin Address Generator'),
            ],
          ),
          actions: [
            IconButton(
              icon: AnimatedSwitcher(
                duration: Duration(milliseconds: 300),
                child: Icon(
                  widget.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                  key: ValueKey(widget.isDarkMode),
                ),
              ),
              onPressed: widget.onThemeToggle,
              tooltip: 'Alternar tema',
            ),
          ],
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator())
            : ListView(
                padding: EdgeInsets.all(16),
                children: [
                  // Header Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.account_balance_wallet,
                            size: 48,
                            color: AppTheme.primaryColor,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Gerador de Endereços Bitcoin',
                            style: Theme.of(context).textTheme.headlineMedium,
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Gere endereços Bitcoin seguros a partir de seed, hex ou WIF',
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 24),

                  _buildShortcuts(context),
                  const SizedBox(height: 24),

                  // Input Method Selector
                  Text(
                    'Método de Entrada',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SegmentedButton<String>(
                        segments: [
                          ButtonSegment(
                            value: 'seed',
                            label: Text('Seed'),
                            icon: Icon(Icons.grass),
                          ),
                          ButtonSegment(
                            value: 'hex',
                            label: Text('HEX'),
                            icon: Icon(Icons.tag),
                          ),
                          ButtonSegment(
                            value: 'wif',
                            label: Text('WIF'),
                            icon: Icon(Icons.vpn_key),
                          ),
                        ],
                        selected: {_inputMethod},
                        onSelectionChanged: (Set<String> newSelection) {
                          setState(() {
                            _inputMethod = newSelection.first;
                            seedController.clear();
                            hexController.clear();
                            wifController.clear();
                          });
                          _clearOutputs();
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: 16),

                  // Input Fields
                  if (_inputMethod == 'seed') ...[
                    TextField(
                      controller: seedController,
                      decoration: InputDecoration(
                        labelText: 'Seed (Texto ou HEX)',
                        hintText: 'Digite uma seed ou gere aleatoriamente',
                        prefixIcon: Icon(Icons.grass),
                        suffixIcon: IconButton(
                          icon: Icon(Icons.casino),
                          onPressed: _generateRandom,
                          tooltip: 'Gerar aleatório',
                        ),
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          btc.setPrivateKeyFromSeed(value);
                          update();
                        }
                      },
                    ),
                  ] else if (_inputMethod == 'hex') ...[
                    TextField(
                      controller: hexController,
                      decoration: InputDecoration(
                        labelText: 'Chave Privada (HEX)',
                        hintText: 'Digite uma chave privada em formato HEX',
                        prefixIcon: Icon(Icons.tag),
                        helperText: 'Gera automaticamente ao digitar (padding à esquerda até 64 caracteres).',
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F]')),
                      ],
                      onChanged: (value) {
                        if (value.isEmpty) {
                          _clearOutputs();
                          return;
                        }

                        if (value.length > 64) {
                          _clearOutputs();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('HEX grande demais (máx. 64 caracteres).'),
                              duration: Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }

                        final padded = value.padLeft(64, '0');
                        try {
                          btc.setPrivateKeyHex(padded);
                          update();
                        } catch (_) {
                          _clearOutputs();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('HEX inválido.'),
                              duration: Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                    ),
                  ] else ...[
                    TextField(
                      controller: wifController,
                      decoration: InputDecoration(
                        labelText: 'Chave Privada (WIF)',
                        hintText: 'Digite uma chave privada em formato WIF',
                        prefixIcon: Icon(Icons.vpn_key),
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          try {
                            btc.setPrivateKeyWithWif(value);
                            update();
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('WIF inválido'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ],

                  SizedBox(height: 24),

                  // Results Section
                  if (p2pkhcController.text.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Endereços Gerados',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        IconButton(
                          icon: Icon(Icons.save),
                          onPressed: _saveToHistory,
                          tooltip: 'Salvar no histórico',
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    FadeTransition(
                      opacity: _animationController,
                      child: Column(
                        children: [
                          // Taproot Address Card
                          Card(
                            color: Colors.deepPurple.withValues(alpha: 0.08),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.auto_awesome, color: Colors.deepPurple),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Endereço Taproot (SegWit v1 / P2TR)',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  CopyableTextField(
                                    controller: taprootController,
                                    label: 'Endereço',
                                    prefixIcon: Icons.auto_awesome,
                                    onTap: () async {
                                      setState(() => _isLoading = true);
                                      final balance = await getBalance(taprootController.text);
                                      if (!mounted) return;
                                      setState(() => _isLoading = false);
                                      if (!context.mounted) return;
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Saldo'),
                                          content: Text(balance),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx),
                                              child: const Text('OK'),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (context) => QRCodeDialog(
                                            data: taprootController.text,
                                            title: 'Endereço Taproot',
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.qr_code),
                                      label: const Text('Mostrar QR Code'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Bech32 Address Card
                          Card(
                            color: Colors.teal.withValues(alpha: 0.08),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.bolt, color: Colors.teal),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Endereço Bech32 (SegWit v0 / P2WPKH)',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  CopyableTextField(
                                    controller: bech32Controller,
                                    label: 'Endereço',
                                    prefixIcon: Icons.account_balance_wallet,
                                    onTap: () async {
                                      setState(() => _isLoading = true);
                                      final balance = await getBalance(bech32Controller.text);
                                      if (!mounted) return;
                                      setState(() => _isLoading = false);
                                      if (!context.mounted) return;
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Saldo'),
                                          content: Text(balance),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx),
                                              child: const Text('OK'),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (context) => QRCodeDialog(
                                            data: bech32Controller.text,
                                            title: 'Endereço Bech32',
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.qr_code),
                                      label: const Text('Mostrar QR Code'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Compressed Address Card
                          Card(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.verified, color: AppTheme.primaryColor),
                                      SizedBox(width: 8),
                                      Text(
                                        'Endereço Comprimido (Recomendado)',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 12),
                                  CopyableTextField(
                                    controller: p2pkhcController,
                                    label: 'Endereço',
                                    prefixIcon: Icons.account_balance_wallet,
                                    onTap: () async {
                                      setState(() => _isLoading = true);
                                      final balance = await getBalance(p2pkhcController.text);
                                      if (!mounted) return;
                                      setState(() => _isLoading = false);
                                      if (!context.mounted) return;
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: Text('Saldo'),
                                          content: Text(balance),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx),
                                              child: Text('OK'),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                  SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (context) => QRCodeDialog(
                                            data: p2pkhcController.text,
                                            title: 'Endereço Comprimido',
                                          ),
                                        );
                                      },
                                      icon: Icon(Icons.qr_code),
                                      label: Text('Mostrar QR Code'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 12),

                          // Uncompressed Address Card
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.info_outline),
                                      SizedBox(width: 8),
                                      Text(
                                        'Endereço Descomprimido (Legacy)',
                                        style: Theme.of(context).textTheme.titleMedium,
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 12),
                                  CopyableTextField(
                                    controller: p2pkhController,
                                    label: 'Endereço',
                                    prefixIcon: Icons.account_balance_wallet_outlined,
                                    onTap: () async {
                                      setState(() => _isLoading = true);
                                      final balance = await getBalance(p2pkhController.text);
                                      if (!mounted) return;
                                      setState(() => _isLoading = false);
                                      if (!context.mounted) return;
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: Text('Saldo'),
                                          content: Text(balance),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx),
                                              child: Text('OK'),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 24),

                          // Advanced Info Expandable
                          ExpansionTile(
                            title: Text('Informações Avançadas'),
                            leading: Icon(Icons.info),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  children: [
                                    CopyableTextField(
                                      controller: privKeyHexController,
                                      label: 'Chave Privada (HEX)',
                                      prefixIcon: Icons.vpn_key,
                                    ),
                                    SizedBox(height: 12),
                                    CopyableTextField(
                                      controller: privKeyWifController,
                                      label: 'Chave Privada (WIF)',
                                      prefixIcon: Icons.vpn_key_outlined,
                                    ),
                                    SizedBox(height: 12),
                                    CopyableTextField(
                                      controller: privKeyWifcController,
                                      label: 'Chave Privada (WIF Comprimida)',
                                      prefixIcon: Icons.vpn_key_rounded,
                                    ),
                                    SizedBox(height: 12),
                                    CopyableTextField(
                                      controller: pubKeyHexController,
                                      label: 'Chave Pública (HEX)',
                                      prefixIcon: Icons.key,
                                    ),
                                    SizedBox(height: 12),
                                    CopyableTextField(
                                      controller: pubKeyHexcController,
                                      label: 'Chave Pública (HEX Comprimida)',
                                      prefixIcon: Icons.key_outlined,
                                    ),
                                    SizedBox(height: 12),
                                    CopyableTextField(
                                      controller: ripemdController,
                                      label: 'RIPEMD-160',
                                      prefixIcon: Icons.fingerprint,
                                    ),
                                    SizedBox(height: 12),
                                    CopyableTextField(
                                      controller: ripemdcController,
                                      label: 'RIPEMD-160 (Comprimido)',
                                      prefixIcon: Icons.fingerprint_outlined,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  SizedBox(height: 24),

                  // Warning Card
                  Card(
                    color: Colors.orange[100],
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber, color: Colors.orange[900]),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Mantenha suas chaves privadas em segurança! Nunca as compartilhe com ninguém.',
                              style: TextStyle(
                                color: Colors.orange[900],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 80),
                ],
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _generateRandom,
          icon: Icon(Icons.casino),
          label: Text('Gerar Aleatório'),
          backgroundColor: AppTheme.primaryColor,
        ),
      ),
    );
  }
}
