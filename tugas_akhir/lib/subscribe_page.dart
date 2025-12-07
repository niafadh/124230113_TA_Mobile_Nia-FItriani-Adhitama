import 'package:flutter/material.dart';
import 'payment_page.dart';
import 'models.dart' as models;
import 'api_service.dart';

// Model lokal untuk tampilan kartu paket
class SubscriptionPlanUI {
  final String name;
  final int months;
  final int idrPrice;
  final double discount;
  final IconData icon;

  SubscriptionPlanUI({
    required this.name,
    required this.months,
    required this.idrPrice,
    this.discount = 0,
    required this.icon,
  });
}

class SubscribePage extends StatefulWidget {
  final String userEmail; // 🔹 Butuh email dari halaman sebelumnya

  const SubscribePage({super.key, required this.userEmail});

  @override
  State<SubscribePage> createState() => _SubscribePageState();
}

class _SubscribePageState extends State<SubscribePage> {
  final ApiService _apiService = ApiService();
  
  final List<SubscriptionPlanUI> plans = [
    SubscriptionPlanUI(
      name: '1 Bulan',
      months: 1,
      idrPrice: 10000,
      discount: 0,
      icon: Icons.person,
    ),
    SubscriptionPlanUI(
      name: '3 Bulan',
      months: 3,
      idrPrice: 29000,
      discount: 0.1,
      icon: Icons.group,
    ),
    SubscriptionPlanUI(
      name: '12 Bulan',
      months: 12,
      idrPrice: 79000,
      discount: 0.1,
      icon: Icons.business,
    ),
  ];

  final List<String> _currencies = ['IDR', 'USD', 'EUR', 'GBP', 'JPY'];
  String _selectedCurrency = 'IDR';
  
  final Map<String, double> _rates = {
    'IDR': 1.0, 'USD': 1.0, 'EUR': 1.0, 'GBP': 1.0, 'JPY': 1.0,
  };
  
  bool _loadingRates = false;

  @override
  void initState() {
    super.initState();
    _fetchExchangeRates();
  }

  Future<void> _fetchExchangeRates() async {
    setState(() => _loadingRates = true);
    try {
      final usdToIdr = await _apiService.getExchangeRate('IDR');
      final usdToEur = await _apiService.getExchangeRate('EUR');
      final usdToGbp = await _apiService.getExchangeRate('GBP');
      final usdToJpy = await _apiService.getExchangeRate('JPY');
      
      if (usdToIdr > 1.0) {
        setState(() {
          _rates['IDR'] = 1.0;
          _rates['USD'] = usdToIdr;
          _rates['EUR'] = usdToIdr / usdToEur;
          _rates['GBP'] = usdToIdr / usdToGbp;
          _rates['JPY'] = usdToIdr / usdToJpy;
          _loadingRates = false;
        });
      } else {
        _useFallbackRates();
      }
    } catch (e) {
      _useFallbackRates();
    }
  }

  void _useFallbackRates() {
    setState(() {
      _rates['IDR'] = 1.0;
      _rates['USD'] = 15700.0;
      _rates['EUR'] = 17000.0;
      _rates['GBP'] = 19800.0;
      _rates['JPY'] = 105.0;
      _loadingRates = false;
    });
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
      case 'IDR': return 'Rp$formatted';
      case 'USD': return '\$$formatted';
      case 'EUR': return '€$formatted';
      case 'GBP': return '£$formatted';
      case 'JPY': return '¥$formatted';
      default: return '$currency $formatted';
    }
  }

  double convertPrice(int idrPrice) {
    return idrPrice / (_rates[_selectedCurrency] ?? 1.0);
  }

  @override
  Widget build(BuildContext context) {
    const Color mainRed = Color(0xFFC92E36);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Our Packages'),
        backgroundColor: mainRed,
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFF6F5F3),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pilih Paket Langgananmu 🔥',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'User: ${widget.userEmail}', // Tampilkan email user biar yakin
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.currency_exchange, color: mainRed, size: 22),
                  const SizedBox(width: 12),
                  const Text(
                    'Mata Uang:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  const Spacer(),
                  _loadingRates
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : DropdownButton<String>(
                          value: _selectedCurrency,
                          underline: const SizedBox(),
                          icon: const Icon(Icons.arrow_drop_down, color: mainRed),
                          style: const TextStyle(
                            color: mainRed,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          items: _currencies.map((curr) {
                            return DropdownMenuItem<String>(
                              value: curr,
                              child: Text(curr),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedCurrency = value);
                            }
                          },
                        ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: ListView.builder(
                itemCount: plans.length,
                itemBuilder: (context, i) {
                  final plan = plans[i];
                  final hasDiscount = plan.discount > 0;
                  final discountedIdr = (plan.idrPrice * (1 - plan.discount)).round();
                  
                  final originalPrice = convertPrice(plan.idrPrice);
                  final finalPrice = convertPrice(discountedIdr);

                  return Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.red.shade50,
                                child: Icon(plan.icon, color: mainRed),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    plan.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    plan.months == 1
                                        ? 'Standard'
                                        : plan.months == 3
                                            ? 'Professional'
                                            : 'Team Support',
                                    style: const TextStyle(color: Colors.black54),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (hasDiscount)
                                Text(
                                  formatCurrency(originalPrice, _selectedCurrency),
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    decoration: TextDecoration.lineThrough,
                                    decorationThickness: 2,
                                    fontSize: 13,
                                  ),
                                ),
                              Text(
                                formatCurrency(finalPrice, _selectedCurrency),
                                style: const TextStyle(
                                  color: mainRed,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              if (hasDiscount)
                                const Text(
                                  '-10%',
                                  style: TextStyle(color: Colors.green, fontSize: 12),
                                ),
                              const SizedBox(height: 6),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: mainRed,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 6,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () {
                                  // Navigasi ke Payment, bawa email user
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PaymentPage(
                                        plan: models.SubscriptionPlan(
                                          name: plan.name,
                                          months: plan.months,
                                          priceUSD: 0.0, // placeholder
                                        ),
                                        finalPrice: finalPrice,
                                        currency: _selectedCurrency,
                                        userEmail: widget.userEmail, // 🔹 OPER EMAIL
                                      ),
                                    ),
                                  );
                                },
                                child: const Text('Buy'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}