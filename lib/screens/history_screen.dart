import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../models/address_model.dart';
import '../services/storage_service.dart';
import 'address_detail_screen.dart';

class HistoryScreen extends StatelessWidget {
  final List<AddressModel> history;
  final VoidCallback onClear;

  const HistoryScreen({
    super.key,
    required this.history,
    required this.onClear,
  });

  Future<void> _exportHistory(BuildContext context) async {
    final payload = jsonEncode(history.map((a) => a.toJson()).toList());
    await Clipboard.setData(ClipboardData(text: payload));

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Histórico copiado como JSON.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _shareHistory(BuildContext context) async {
    final payload = jsonEncode(history.map((a) => a.toJson()).toList());
    try {
      await Share.share(
        payload,
        subject: 'Histórico (Bag) — Endereços Bitcoin',
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: payload));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível compartilhar. JSON copiado.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _importHistory(BuildContext context) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final messenger = ScaffoldMessenger.of(context);
    bool merge = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: const Text('Importar histórico (JSON)'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: controller,
                  minLines: 6,
                  maxLines: 12,
                  decoration: const InputDecoration(
                    hintText: '[{...}, {...}]',
                    labelText: 'Cole aqui o JSON exportado',
                  ),
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    if (t.isEmpty) return 'Cole um JSON.';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mesclar com histórico atual'),
                  subtitle: const Text('Se desativado, substitui tudo.'),
                  value: merge,
                  onChanged: (v) => setLocalState(() => merge = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                final data = await Clipboard.getData(Clipboard.kTextPlain);
                final t = data?.text?.trim() ?? '';
                controller.text = t;
                if (t.isEmpty) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Clipboard vazio ou sem texto.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text('Colar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() != true) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Importar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    final text = controller.text.trim();
    try {
      dynamic decoded = jsonDecode(text);

      // Compat: aceitar payload embrulhado em um objeto.
      if (decoded is Map) {
        final map = Map<String, dynamic>.from(decoded);
        if (map['items'] is List) decoded = map['items'];
        if (map['history'] is List) decoded = map['history'];
      }

      List<AddressModel> imported;
      if (decoded is List) {
        imported = decoded.map<AddressModel>((e) {
          if (e is Map<String, dynamic>) {
            return AddressModel.fromJson(e);
          }
          if (e is Map) {
            return AddressModel.fromJson(Map<String, dynamic>.from(e));
          }
          if (e is String) {
            // Compat: lista de strings JSON individuais.
            return AddressModel.fromJson(jsonDecode(e) as Map<String, dynamic>);
          }
          throw const FormatException('Item inválido no array');
        }).toList();
      } else {
        throw const FormatException('JSON deve ser um array');
      }

      final storage = StorageService();
      final storedCount = merge ? await storage.mergeHistory(imported) : await storage.overwriteHistory(imported);
      if (!context.mounted) return;
      Navigator.pop(context, storedCount);
    } catch (e) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Falha ao importar'),
          content: Text(e.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Histórico de Endereços'),
        actions: [
          IconButton(
            tooltip: 'Compartilhar JSON',
            icon: const Icon(Icons.share_outlined),
            onPressed: history.isEmpty ? null : () => _shareHistory(context),
          ),
          IconButton(
            tooltip: 'Exportar (copiar JSON)',
            icon: const Icon(Icons.download_outlined),
            onPressed: history.isEmpty ? null : () => _exportHistory(context),
          ),
          IconButton(
            tooltip: 'Importar (colar JSON)',
            icon: const Icon(Icons.upload_outlined),
            onPressed: () => _importHistory(context),
          ),
          if (history.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_outline),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Limpar Histórico'),
                    content: Text('Deseja realmente limpar todo o histórico?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Cancelar'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          onClear();
                          Navigator.pop(context);
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: Text('Limpar'),
                      ),
                    ],
                  ),
                );
              },
              tooltip: 'Limpar histórico',
            ),
        ],
      ),
      body: history.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Nenhum endereço no histórico',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Gere endereços para vê-los aqui',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[500],
                        ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: history.length,
              itemBuilder: (context, index) {
                final address = history[index];
                return Card(
                  margin: EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: EdgeInsets.all(16),
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).primaryColor,
                      child: Icon(
                        Icons.key,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      address.addressTaproot.isNotEmpty
                          ? address.addressTaproot
                          : (address.addressBech32.isNotEmpty ? address.addressBech32 : address.addressCompressed),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 4),
                        Text(
                          'Seed: ${address.seed.isEmpty ? "N/A" : address.seed}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Text(
                          _formatDateTime(address.timestamp),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    trailing: Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddressDetailScreen(address: address),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
