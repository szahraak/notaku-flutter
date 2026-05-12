import 'package:isar/isar.dart';

part 'receipt.g.dart';

@collection
class Receipt {
  Id id = Isar.autoIncrement;

  late DateTime scannedAt;
  late String storeName;
  late double subtotal; // Sum of all items before charges/discounts
  late double discount; // Discount amount (usually negative)
  late double serviceCharge; // Service charge/SC
  late double tax; // Tax (PB1 or PPN, combined)
  late double pembulatan; // Rounding adjustment
  late double grandTotal; // Final total
  late String rawText;

  // Embed list of items langsung dalam dokumen
  late List<ReceiptItem> items;
  
  // Calculate breakdown
  double get afterDiscount => subtotal + discount;
  double get beforeTax => afterDiscount + serviceCharge;
  double get beforeRounding => beforeTax + tax;
}

@embedded
class ReceiptItem {
  late String name;
  late int qty;
  late double price;

  double get subtotal => qty * price;
}