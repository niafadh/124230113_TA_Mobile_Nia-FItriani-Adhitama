import 'package:flutter/material.dart';
import 'models.dart';
import 'transaction_service.dart';
import 'notification_service.dart';
import 'home_page.dart'; // Pastikan import ini ada
import 'premium_helper.dart';

class PaymentPage extends StatelessWidget {
  final SubscriptionPlan plan;
  final double finalPrice;
  final String currency;
  final String userEmail; 

  const PaymentPage({
    super.key,
    required this.plan,
    required this.finalPrice,
    required this.currency,
    required this.userEmail, 
  });

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
      case 'IDR': return 'Rp$formatted';
      case 'USD': return '\$$formatted';
      case 'EUR': return '€$formatted';
      case 'GBP': return '£$formatted';
      case 'JPY': return '¥$formatted';
      default: return '$currency $formatted';
    }
  }

  @override
  Widget build(BuildContext context) {
    final mainColor = Colors.red.shade800;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Detail Pembayaran'),
        backgroundColor: mainColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: mainColor.withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ringkasan Pembelian',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: mainColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _infoRow('Akun', userEmail),
                  _infoRow('Paket', plan.name),
                  _infoRow('Durasi', '${plan.months} bulan'),
                  _infoRow('Total', formatCurrency(finalPrice, currency),
                      isHighlight: true),
                ],
              ),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.payment, color: Colors.white),
                label: const Text(
                  'Bayar Sekarang',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: mainColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () async {
                  try {
                    // 1. Simpan Transaksi
                    await TransactionService.addTransaction(
                      Transaction(
                        userEmail: userEmail, 
                        planName: plan.name,
                        price: finalPrice,
                        currency: currency,
                        date: DateTime.now(),
                      ),
                    );

                    // 2. Aktifkan Premium
                    await PremiumHelper.activatePremium(userEmail, plan.months);

                    // 3. Notifikasi
                    await NotificationService.showSuccessNotification(
                      title: 'Pembayaran Berhasil 🎉',
                      body: 'Premium ${plan.name} aktif untuk $userEmail!',
                    );

                    if (context.mounted) {
                      // 🔹 PERBAIKAN DISINI:
                      // Arahkan ke HomePage dengan index 3 (Profile)
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const HomePage(initialIndex: 3)), // 👈 Ke Tab Profile
                        (route) => false,
                      );
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Gagal memproses pembayaran: $e'),
                        backgroundColor: Colors.red.shade800,
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
              color: isHighlight ? Colors.red.shade800 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}