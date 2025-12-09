import 'package:hive_flutter/hive_flutter.dart';
import 'models.dart';

class TransactionService {
  // Simpan transaksi
  static Future<void> addTransaction(Transaction tx) async {
    final box = await Hive.openBox('transactions');

    await box.add({
      'userEmail': tx.userEmail,
      'planName': tx.planName,
      'price': tx.price,
      'currency': tx.currency,
      'date': tx.date.toIso8601String(),
    });
  }

  // Ambil transaksi (Versi Aman)
  static Future<List<Transaction>> getTransactions(String email) async {
    // Pastikan box terbuka
    final box = await Hive.openBox('transactions');
    final List<Transaction> transactions = [];

    // Loop semua data di box
    for (var item in box.values) {
      // 1. Cek apakah item valid (berbentuk Map)
      if (item is! Map) continue;

      // 2. Ambil data dengan nilai default jika null (Biar gak crash)
      final itemEmail = item['userEmail'] as String? ?? ''; // Default string kosong
      final itemPlan = item['planName'] as String? ?? 'Unknown Plan';
      final itemPrice = (item['price'] ?? 0).toDouble();
      final itemCurrency = item['currency'] as String? ?? 'IDR';
      
      // Parse tanggal dengan aman
      DateTime itemDate;
      try {
        itemDate = DateTime.parse(item['date'].toString());
      } catch (e) {
        itemDate = DateTime.now(); // Fallback jika tanggal error
      }

      // 3. Filter: Hanya masukkan jika emailnya cocok
      // (Data lama yang emailnya kosong tidak akan masuk sini, jadi aman)
      if (itemEmail == email) {
        transactions.add(
          Transaction(
            userEmail: itemEmail,
            planName: itemPlan,
            price: itemPrice,
            currency: itemCurrency,
            date: itemDate,
          ),
        );
      }
    }

    // Urutkan dari yang paling baru
    transactions.sort((a, b) => b.date.compareTo(a.date));
    
    return transactions;
  }
}