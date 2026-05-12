import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/receipt.dart';

class DatabaseService {
  static late Isar _isar;

  // Panggil sekali di main()
  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [ReceiptSchema],
      directory: dir.path,
    );
  }

  // Simpan struk baru
  static Future<void> saveReceipt(Receipt receipt) async {
    await _isar.writeTxn(() async {
      await _isar.receipts.put(receipt);
    });
  }

  // Ambil semua histori (terbaru dulu)
  static Future<List<Receipt>> getAllReceipts() async {
    return _isar.receipts
        .where()
        .sortByScannedAtDesc()
        .findAll();
  }

  // Cari struk berdasarkan nama toko
  static Future<List<Receipt>> searchByStore(String query) async {
    return _isar.receipts
        .filter()
        .storeNameContains(query, caseSensitive: false)
        .findAll();
  }

  // Hapus struk
  static Future<void> deleteReceipt(int id) async {
    await _isar.writeTxn(() async {
      await _isar.receipts.delete(id);
    });
  }

  // Total pengeluaran bulan ini
  static Future<double> totalThisMonth() async {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);

    final receipts = await _isar.receipts
        .filter()
        .scannedAtGreaterThan(firstDay)
        .findAll();

    return receipts.fold<double>(0.0, (sum, r) => sum + r.grandTotal);
  }
}