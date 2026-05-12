import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../models/receipt.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Histori Scan')),
      body: FutureBuilder<List<Receipt>>(
        future: DatabaseService.getAllReceipts(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final list = snap.data!;
          if (list.isEmpty) return const Center(child: Text('Belum ada struk tersimpan'));

          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (_, i) {
              final r = list[i];
              return ListTile(
                leading: const Icon(Icons.receipt),
                title: Text(r.storeName),
                subtitle: Text(
                  '${r.scannedAt.day}/${r.scannedAt.month}/${r.scannedAt.year}'
                  ' · ${r.items.length} item',
                ),
                trailing: Text(
                  'Rp ${r.grandTotal.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onTap: () => _showDetail(context, r),
              );
            },
          );
        },
      ),
    );
  }

  void _showDetail(BuildContext context, Receipt r) {
    showModalBottomSheet(
      context: context,
      builder: (_) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(r.storeName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...r.items.map((item) => ListTile(
            dense: true,
            title: Text(item.name),
            trailing: Text('Rp ${item.subtotal.toStringAsFixed(0)}'),
          )),
          const Divider(),
          ListTile(
            title: const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
            trailing: Text('Rp ${r.grandTotal.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}