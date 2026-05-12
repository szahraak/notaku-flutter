import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../screens/review_receipt_screen.dart';
import '../services/ocr_service_wrapper.dart';
import '../services/receipt_parser.dart' as parser;

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _ocr    = OcrServiceWrapper();
  final _picker = ImagePicker();

  bool                _isLoading = false;
  parser.ParsedReceipt? _result;

  Future<void> _scan(ImageSource source) async {
    final file = await _picker.pickImage(source: source);
    if (file == null) return;

    setState(() => _isLoading = true);

    try {
      final ocrResult = await _ocr.extractAndCorrectText(file.path);
      final rawText = ocrResult.text;
      
      print('\n=== RAW OCR OUTPUT ${ocrResult.usedCloudAI ? '(Cloud AI improved)' : '(Local only)'} ===');
      print(rawText);
      print('=== END RAW OUTPUT ===\n');
      
      final parsed  = parser.ReceiptParser.parse(rawText);
      
      print('\n=== PARSED RESULT ===');
      print('Store: ${parsed.storeName}');
      print('Subtotal: ${parsed.subtotal}');
      print('Discount: ${parsed.discount}');
      print('Service Charge: ${parsed.serviceCharge}');
      print('Tax: ${parsed.tax}');
      print('Pembulatan: ${parsed.pembulatan}');
      print('Items (${parsed.items.length}):');
      for (var item in parsed.items) {
        print('  - ${item.name} x${item.qty} = ${item.price}');
      }
      print('Grand Total: ${parsed.grandTotal}');
      print('=== END PARSED ===\n');

      setState(() => _result = parsed);
      
      // Navigate to review screen instead of direct save
      if (mounted) {
        final saved = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => ReviewReceiptScreen(parsedReceipt: parsed),
          ),
        );
        
        if (saved == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Struk berhasil disimpan!')),
          );
          setState(() => _result = null);
        }
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Struk')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _result == null
              ? _buildEmptyState()
              : _buildResult(),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'gallery',
            onPressed: () => _scan(ImageSource.gallery),
            icon: const Icon(Icons.photo_library),
            label: const Text('Galeri'),
          ),
          const SizedBox(width: 12),
          FloatingActionButton.extended(
            heroTag: 'camera',
            onPressed: () => _scan(ImageSource.camera),
            icon: const Icon(Icons.camera_alt),
            label: const Text('Kamera'),
          ),
        ],
      ),
    );
  }

  Widget _buildResult() {
    final r = _result!;
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: r.items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final item = r.items[i];
              return ListTile(
                title: Text(item.name),
                subtitle: Text('${item.qty}x  Rp ${item.price.toStringAsFixed(0)}'),
                trailing: Text(
                  'Rp ${item.subtotal.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            },
          ),
        ),
        // Footer total
        Container(
          color: Theme.of(context).colorScheme.primaryContainer,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                'Rp ${r.grandTotal.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() => const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.receipt_long, size: 80, color: Colors.grey),
        SizedBox(height: 16),
        Text('Foto atau pilih struk belanja\nuntuk mulai scan',
            textAlign: TextAlign.center),
      ],
    ),
  );

  @override
  void dispose() {
    _ocr.dispose();
    super.dispose();
  }
}