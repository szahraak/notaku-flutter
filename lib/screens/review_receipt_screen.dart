import 'package:flutter/material.dart';
import '../models/receipt.dart' as model;
import '../services/database_service.dart';
import '../services/receipt_parser.dart' as parser;

class ReviewReceiptScreen extends StatefulWidget {
  final parser.ParsedReceipt parsedReceipt;

  const ReviewReceiptScreen({required this.parsedReceipt, super.key});

  @override
  State<ReviewReceiptScreen> createState() => _ReviewReceiptScreenState();
}

class _ReviewReceiptScreenState extends State<ReviewReceiptScreen> {
  late List<_EditableItem> editableItems;
  late TextEditingController storeController;
  late TextEditingController discountController;
  late TextEditingController scController;
  late TextEditingController pb1Controller;
  late TextEditingController ppnController;
  late TextEditingController pembulatanController;

  @override
  void initState() {
    super.initState();
    
    // Initialize editable items
    editableItems = widget.parsedReceipt.items
        .map((item) => _EditableItem(
              name: item.name,
              qty: item.qty,
              price: item.price,
              nameController: TextEditingController(text: item.name),
              qtyController: TextEditingController(text: item.qty.toString()),
              priceController: TextEditingController(text: item.price.toStringAsFixed(0)),
            ))
        .toList();

    storeController = TextEditingController(text: widget.parsedReceipt.storeName);
    discountController = TextEditingController(
      text: widget.parsedReceipt.discount == 0 
        ? '' 
        : widget.parsedReceipt.discount.abs().toStringAsFixed(0),
    );
    scController = TextEditingController(text: widget.parsedReceipt.serviceCharge.toStringAsFixed(0));
    pb1Controller = TextEditingController(text: widget.parsedReceipt.tax.toStringAsFixed(0));
    ppnController = TextEditingController(text: '0');
    pembulatanController = TextEditingController(text: widget.parsedReceipt.pembulatan.toStringAsFixed(0));
    
    // Add listeners untuk auto-update saat nilai berubah
    discountController.addListener(() => setState(() {}));
    scController.addListener(() => setState(() {}));
    pb1Controller.addListener(() => setState(() {}));
    pembulatanController.addListener(() => setState(() {}));
    
    // Add listeners untuk item fields
    for (final item in editableItems) {
      item.qtyController.addListener(() => setState(() {}));
      item.priceController.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    storeController.dispose();
    discountController.dispose();
    scController.dispose();
    pb1Controller.dispose();
    ppnController.dispose();
    pembulatanController.dispose();
    for (final item in editableItems) {
      item.nameController.dispose();
      item.qtyController.dispose();
      item.priceController.dispose();
    }
    super.dispose();
  }

  double _calculateSubtotal() {
    return editableItems.fold<double>(
      0,
      (sum, item) {
        final qty = int.tryParse(item.qtyController.text) ?? 1;
        final price = double.tryParse(item.priceController.text) ?? 0;
        return sum + (qty * price);
      },
    );
  }

  double _calculateGrandTotal() {
    final subtotal = _calculateSubtotal();
    // Discount input sebagai positive, tapi simpan sebagai negative
    final discountInput = double.tryParse(discountController.text) ?? 0;
    final discount = -discountInput.abs();
    
    final sc = double.tryParse(scController.text) ?? 0;
    final tax = double.tryParse(pb1Controller.text) ?? 0;
    final pembulatan = double.tryParse(pembulatanController.text) ?? 0;

    return subtotal + discount + sc + tax + pembulatan;
  }

  Future<void> _saveReceipt() async {
    final subtotal = _calculateSubtotal();
    // Discount input sebagai positive, simpan sebagai negative
    final discountInput = double.tryParse(discountController.text) ?? 0;
    final discount = -discountInput.abs();
    
    final sc = double.tryParse(scController.text) ?? 0;
    final tax = double.tryParse(pb1Controller.text) ?? 0;
    final pembulatan = double.tryParse(pembulatanController.text) ?? 0;
    final grandTotal = _calculateGrandTotal();

    final receipt = model.Receipt()
      ..scannedAt = DateTime.now()
      ..storeName = storeController.text
      ..subtotal = subtotal
      ..discount = discount
      ..serviceCharge = sc
      ..tax = tax
      ..pembulatan = pembulatan
      ..grandTotal = grandTotal
      ..rawText = widget.parsedReceipt.rawText
      ..items = editableItems
          .map((item) => model.ReceiptItem()
            ..name = item.nameController.text
            ..qty = int.tryParse(item.qtyController.text) ?? 1
            ..price = double.tryParse(item.priceController.text) ?? 0)
          .toList();

    await DatabaseService.saveReceipt(receipt);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Struk berhasil disimpan!')),
      );
      Navigator.pop(context, true); // Return true to indicate save
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verifikasi Struk'),
        actions: [
          TextButton.icon(
            onPressed: _saveReceipt,
            icon: const Icon(Icons.check),
            label: const Text('Simpan'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Store Name
            _buildTextField('Nama Toko', storeController),
            const SizedBox(height: 20),

            // Items Section
            const Text(
              'Menu Items',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ..._buildItemEditors(),
            const SizedBox(height: 20),

            // Calculation Breakdown
            _buildCalculationSection(),
            const SizedBox(height: 20),

            // Metadata Section
            _buildMetadataSection(),
            const SizedBox(height: 20),

            // Grand Total
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Akhir',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Rp ${_calculateGrandTotal().toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildItemEditors() {
    return List.generate(
      editableItems.length,
      (index) {
        final item = editableItems[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Item name
                  TextField(
                    controller: item.nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Item',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Qty and Price in row
                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: TextField(
                          controller: item.qtyController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Qty',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: item.priceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Harga',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          setState(() => editableItems.removeAt(index));
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Subtotal
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Subtotal: Rp ${(int.tryParse(item.qtyController.text) ?? 1) * (double.tryParse(item.priceController.text) ?? 0).toInt()}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCalculationSection() {
    final subtotal = _calculateSubtotal();
    // Discount input sebagai positive, tapi display sebagai negative
    final discountInput = double.tryParse(discountController.text) ?? 0;
    final discount = -discountInput.abs();
    
    final sc = double.tryParse(scController.text) ?? 0;
    final tax = double.tryParse(pb1Controller.text) ?? 0;
    final pembulatan = double.tryParse(pembulatanController.text) ?? 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _buildCalculationRow('Subtotal', subtotal),
          if (discount != 0) _buildCalculationRow('Diskon', discount),
          if (sc != 0) _buildCalculationRow('Service Charge', sc),
          if (tax != 0) _buildCalculationRow('Pajak', tax),
          if (pembulatan != 0) _buildCalculationRow('Pembulatan', pembulatan),
          const Divider(),
          _buildCalculationRow(
            'Grand Total',
            subtotal + discount + sc + tax + pembulatan,
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _buildCalculationRow(String label, double value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal),
          ),
          Text(
            'Rp ${value.toStringAsFixed(0)}',
            style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataSection() {
    return ExpansionTile(
      title: const Text('Tambahan/Potongan'),
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              _buildMetadataField('Diskon', discountController),
              _buildMetadataField('Service Charge (SC)', scController),
              _buildMetadataField('Pajak', pb1Controller),
              _buildMetadataField('Pembulatan', pembulatanController),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildMetadataField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffix: const Text('Rp'),
        ),
      ),
    );
  }
}

class _EditableItem {
  final String name;
  final int qty;
  final double price;
  final TextEditingController nameController;
  final TextEditingController qtyController;
  final TextEditingController priceController;

  _EditableItem({
    required this.name,
    required this.qty,
    required this.price,
    required this.nameController,
    required this.qtyController,
    required this.priceController,
  });
}
