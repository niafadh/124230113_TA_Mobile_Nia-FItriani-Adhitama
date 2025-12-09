class SubscriptionPlan {
  final String name;
  final int months;
  final double priceUSD;

  SubscriptionPlan({
    required this.name,
    required this.months,
    required this.priceUSD,
  });
}

class Transaction {
  final String userEmail; // 👈 Pastikan ini ada
  final String planName;
  final double price;
  final String currency;
  final DateTime date;

  Transaction({
    required this.userEmail, // 👈 Ini juga wajib
    required this.planName,
    required this.price,
    required this.currency,
    required this.date,
  });
}