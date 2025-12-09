import 'package:flutter/material.dart';
import 'transaction_service.dart';
import 'models.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  String selectedFilter = 'all'; 
  static const mainColor = Color(0xFFC92E36);
  String userEmail = '';

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  void _loadUser() {
    final box = Hive.box('userBox');
    final user = box.get('user');
    if (user != null && mounted) {
      setState(() {
        userEmail = user['email'] ?? '';
      });
    }
  }

  String formatCurrency(double value, String currency) {
    final v = value.toStringAsFixed(currency == 'JPY' ? 0 : 2);
    String formatted = '';
    final parts = v.split('.');
    String whole = parts[0];

    int count = 0;
    for (int i = whole.length - 1; i >= 0; i--) {
      formatted = whole[i] + formatted;
      count++;
      if (count % 3 == 0 && i != 0) {
        formatted = (currency == 'IDR' ? '.' : ',') + formatted;
      }
    }

    if (parts.length > 1 && currency != 'JPY') {
      formatted += (currency == 'IDR' ? ',' : '.') + parts[1];
    }

    switch (currency) {
      case 'IDR': return '- Rp$formatted';
      case 'USD': return '- \$$formatted';
      case 'EUR': return '- €$formatted';
      case 'GBP': return '- £$formatted';
      case 'JPY': return '- ¥$formatted';
      default: return '- $currency $formatted';
    }
  }

  List<Transaction> filterTransactions(List<Transaction> transactions) {
    final now = DateTime.now();
    if (selectedFilter == 'day') {
      return transactions.where((tx) => 
        tx.date.year == now.year && tx.date.month == now.month && tx.date.day == now.day
      ).toList();
    } else if (selectedFilter == 'week') {
      return transactions.where((tx) => 
        now.difference(tx.date).inDays <= 7
      ).toList();
    } else if (selectedFilter == 'month') {
      return transactions.where((tx) => 
        tx.date.year == now.year && tx.date.month == now.month
      ).toList();
    }
    return transactions;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      
      appBar: AppBar(
        backgroundColor: mainColor,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false, 
        title: const Text(
          'Activity History',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),

      body: Column(
        children: [
          // 🔹 Filter Chips
          Container(
            width: double.infinity,
            // color: Colors.white, <--- INI YANG BIKIN ERROR TADI (HAPUS)
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white, // <--- PINDAHKAN WARNA KE SINI
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildChip('All', 'all'),
                  const SizedBox(width: 10),
                  _buildChip('Today', 'day'),
                  const SizedBox(width: 10),
                  _buildChip('Week', 'week'),
                  const SizedBox(width: 10),
                  _buildChip('Month', 'month'),
                ],
              ),
            ),
          ),

          // List Transaksi
          Expanded(
            child: FutureBuilder<List<Transaction>>(
              future: TransactionService.getTransactions(userEmail), 
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: mainColor));
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyState();
                }

                final filtered = filterTransactions(snapshot.data!);

                if (filtered.isEmpty) {
                  return _buildEmptyState(message: "No transactions found");
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final tx = filtered[index];
                    return _buildTransactionCard(tx);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, String value) {
    final isSelected = selectedFilter == value;
    return GestureDetector(
      onTap: () => setState(() => selectedFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? mainColor : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? mainColor : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade600,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionCard(Transaction tx) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.workspace_premium, color: Colors.orange, size: 24),
          ),
          const SizedBox(width: 16),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.planName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2B2B2B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('dd MMM yyyy, HH:mm').format(tx.date),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatCurrency(tx.price, tx.currency),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: mainColor,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  "Success",
                  style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold),
                ),
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({String message = "No transactions yet"}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.receipt_long_rounded, size: 60, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
          ),
        ],
      ),
    );
  }
}