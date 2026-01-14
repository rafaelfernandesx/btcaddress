import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CopyableTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData? prefixIcon;
  final VoidCallback? onTap;

  const CopyableTextField({
    super.key,
    required this.controller,
    required this.label,
    this.prefixIcon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onTap != null)
              IconButton(
                icon: Icon(Icons.search),
                onPressed: onTap,
                tooltip: 'Consultar saldo',
              ),
            IconButton(
              icon: Icon(Icons.copy),
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  Clipboard.setData(ClipboardData(text: controller.text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Copiado para a área de transferência!'),
                      duration: Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              tooltip: 'Copiar',
            ),
          ],
        ),
      ),
      readOnly: true,
      maxLines: null,
    );
  }
}
