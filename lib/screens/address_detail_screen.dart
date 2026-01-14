import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/address_model.dart';
import '../widgets/qr_code_dialog.dart';

class AddressDetailScreen extends StatelessWidget {
  final AddressModel address;

  const AddressDetailScreen({
    super.key,
    required this.address,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detalhes do Endereço'),
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          _buildInfoCard(
            context,
            'Endereço Comprimido',
            address.addressCompressed,
            Icons.account_balance_wallet,
            showQR: true,
          ),
          SizedBox(height: 12),
          _buildInfoCard(
            context,
            'Endereço Descomprimido',
            address.addressUncompressed,
            Icons.account_balance_wallet_outlined,
            showQR: true,
          ),
          SizedBox(height: 24),
          Text(
            'Chaves Privadas',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: 12),
          _buildInfoCard(
            context,
            'Chave Privada (HEX)',
            address.privateKeyHex,
            Icons.vpn_key,
          ),
          SizedBox(height: 12),
          _buildInfoCard(
            context,
            'Chave Privada (WIF)',
            address.privateKeyWif,
            Icons.vpn_key_outlined,
          ),
          SizedBox(height: 12),
          _buildInfoCard(
            context,
            'Chave Privada (WIF Comprimida)',
            address.privateKeyWifCompressed,
            Icons.vpn_key_rounded,
          ),
          SizedBox(height: 24),
          Text(
            'Chaves Públicas',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: 12),
          _buildInfoCard(
            context,
            'Chave Pública (HEX)',
            address.publicKeyHex,
            Icons.key,
          ),
          SizedBox(height: 12),
          _buildInfoCard(
            context,
            'Chave Pública (HEX Comprimida)',
            address.publicKeyHexCompressed,
            Icons.key_outlined,
          ),
          if (address.seed.isNotEmpty) ...[
            SizedBox(height: 24),
            Text(
              'Informações Adicionais',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 12),
            _buildInfoCard(
              context,
              'Seed',
              address.seed,
              Icons.grass,
            ),
          ],
          SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    bool showQR = false,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                value,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: value));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('$label copiado!'),
                          duration: Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: Icon(Icons.copy, size: 18),
                    label: Text('Copiar'),
                  ),
                ),
                if (showQR) ...[
                  SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => QRCodeDialog(
                            data: value,
                            title: label,
                          ),
                        );
                      },
                      icon: Icon(Icons.qr_code, size: 18),
                      label: Text('QR Code'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
