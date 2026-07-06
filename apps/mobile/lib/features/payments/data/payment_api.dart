import 'package:dio/dio.dart';

import '../domain/payment_order.dart';

class PaymentApiException implements Exception {
  PaymentApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class PaymentApi {
  PaymentApi(this._dio);

  final Dio _dio;

  Future<PaymentOrder> createOrder(String registrationId) async {
    try {
      final response = await _dio.post('/payments/orders', data: {
        'registrationId': registrationId,
      });
      return PaymentOrder.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (error) {
      throw PaymentApiException(_extractMessage(error), statusCode: error.response?.statusCode);
    }
  }

  Future<void> verifyPayment({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    try {
      await _dio.post('/payments/verify', data: {
        'razorpay_order_id': orderId,
        'razorpay_payment_id': paymentId,
        'razorpay_signature': signature,
      });
    } on DioException catch (error) {
      throw PaymentApiException(_extractMessage(error), statusCode: error.response?.statusCode);
    }
  }

  Future<void> failPayment(String paymentId) async {
    try {
      await _dio.post('/payments/$paymentId/fail');
    } on DioException {
      // Best-effort — if this fails the payment simply stays "Created" and
      // the next order-creation call will still work correctly.
    }
  }

  String _extractMessage(DioException error) {
    final backendMessage = error.response?.data?['message'] as String?;
    if (backendMessage != null && backendMessage.isNotEmpty) return backendMessage;
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout) {
      return 'Could not reach the server. Check your connection and try again.';
    }
    return 'Something went wrong with the payment. Please try again.';
  }
}
