import 'package:flutter/material.dart';
import 'transaction_service.dart';
import 'models.dart';
import 'package:intl/intl.dart';
import 'home_page.dart'; // pastikan file ini ada

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  String selectedFilter = 'day'; // default tampilan hari ini
  static const mainColor = Color(0xFFB71C1C);

  List<Transaction> filterTransactions(List<Transaction> transactions) {
    final now = DateTime.now();

    if (selectedFilter == 'day') {
      return transactions.where((tx) {
        return tx.date.year == now.year &&
            tx.date.month == now.month &&
            tx.date.day == now.day;
      }).toList();
    } else if (selectedFilter == 'week') {
      return transactions.where((tx) {
        return now.difference(tx.date).inDays <= 7;
      }).toList();
    } else {
      // month
      return transactions.where((tx) {
        return now.difference(tx.date).inDays <= 30;
      }).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: mainColor,
        elevation: 0,
        title: const Text(
          'Riwayat Transaksi',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const HomePage()),
            );
          },
        ),
      ),
      body: Column(
        children: [
          // 🔹 Tombol Filter (Day / Week / Month)
          Container(
            color: mainColor.withOpacity(0.1),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildFilterButton('Day', 'day'),
                _buildFilterButton('Week', 'week'),
                _buildFilterButton('Month', 'month'),
              ],
            ),
          ),

          // 🔹 Daftar Transaksi
          Expanded(
            child: FutureBuilder<List<Transaction>>(
              future: TransactionService.getTransactions(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: mainColor));
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text(
                      'Belum ada transaksi',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  );
                }

                final filtered = filterTransactions(snapshot.data!);

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      'Tidak ada transaksi di periode ini',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final tx = filtered[index];
                    return Card(
                      elevation: 3,
                      shadowColor: mainColor.withOpacity(0.3),
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: mainColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.receipt_long, color: mainColor),
                        ),
                        title: Text(
                          tx.planName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black87),
                        ),
                        subtitle: Text(
                          DateFormat('dd MMM yyyy – HH:mm').format(tx.date),
                          style: const TextStyle(color: Colors.black54),
                        ),
                        trailing: Text(
                          '${tx.price.toStringAsFixed(2)} ${tx.currency}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: mainColor),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 🔸 Widget Tombol Filter
  Widget _buildFilterButton(String label, String value) {
    final isSelected = selectedFilter == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedFilter = value;
          });
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? mainColor : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: mainColor),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : mainColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
