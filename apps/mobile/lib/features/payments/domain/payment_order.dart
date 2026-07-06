class PaymentOrder {
  const PaymentOrder({
    required this.paymentId,
    required this.orderId,
    required this.amount,
    required this.currency,
    required this.keyId,
    required this.registrationId,
  });

  factory PaymentOrder.fromJson(Map<String, dynamic> json) => PaymentOrder(
        paymentId: json['paymentId'] as String,
        orderId: json['orderId'] as String,
        amount: (json['amount'] as num).toInt(),
        currency: json['currency'] as String? ?? 'INR',
        keyId: json['keyId'] as String? ?? '',
        registrationId: json['registrationId'] as String,
      );

  final String paymentId;
  final String orderId;
  final int amount; // rupees
  final String currency;
  final String keyId;
  final String registrationId;
}
