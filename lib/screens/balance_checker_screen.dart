import 'package:btcaddress/services/blockchain_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BalanceCheckerScreen extends StatefulWidget {
  const BalanceCheckerScreen({super.key});

  @override
  State<BalanceCheckerScreen> createState() => _BalanceCheckerScreenState();
}

class _BalanceCheckerScreenState extends State<BalanceCheckerScreen> {
  final _addressController = TextEditingController();
  final _service = BlockchainService();

  bool _loading = false;
  String? _result;

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) return;

    setState(() {
      _loading = true;
      _result = null;
    });

    try {
      final balance = await _service.getBalanceBtc(address);
      if (!mounted) return;
      setState(() {
        _result = balance;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _result = 'Erro ao consultar';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;

    _addressController.text = text;
    _addressController.selection = TextSelection.fromPosition(
      TextPosition(offset: _addressController.text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Consultar saldo'),
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
                    'Endereço Bitcoin',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _addressController,
                    decoration: InputDecoration(
                      labelText: 'Cole ou digite o endereço',
                      prefixIcon: const Icon(Icons.account_balance_wallet),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: _pasteFromClipboard,
                            tooltip: 'Colar',
                            icon: const Icon(Icons.content_paste),
                          ),
                          IconButton(
                            onPressed: () {
                              _addressController.clear();
                              setState(() {
                                _result = null;
                              });
                            },
                            tooltip: 'Limpar',
                            icon: const Icon(Icons.clear),
                          ),
                        ],
                      ),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _check(),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _check,
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search),
                      label: Text(_loading ? 'Consultando...' : 'Consultar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_result != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.currency_bitcoin),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Saldo',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            _result!,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copiar resultado',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _result!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Copiado!'),
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy),
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
