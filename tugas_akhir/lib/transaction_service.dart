import 'package:hive_flutter/hive_flutter.dart';
import 'models.dart';

class TransactionService {
  static Future<void> addTransaction(Transaction tx) async {
    // 🔹 Pastikan Hive sudah diinisialisasi di main.dart
    final box = await Hive.openBox('transactions');

    // 🔹 Simpan data transaksi ke Hive
    await box.add({
      'planName': tx.planName,
      'price': tx.price,
      'currency': tx.currency,
      'date': tx.date.toIso8601String(),
    });
  }

  static Future<List<Transaction>> getTransactions() async {
    final box = await Hive.openBox('transactions');
    final List<Transaction> transactions = [];

    for (var item in box.values) {
      transactions.add(
        Transaction(
          planName: item['planName'],
          price: item['price'],
          currency: item['currency'],
          date: DateTime.parse(item['date']),
        ),
      );
    }

    return transactions;
  }
}
