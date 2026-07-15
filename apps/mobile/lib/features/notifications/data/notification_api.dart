import 'package:dio/dio.dart';

import '../domain/app_notification.dart';

class NotificationApiException implements Exception {
  NotificationApiException(this.message, {this.reason});
  final String message;
  final String? reason;
  @override
  String toString() => message;
}

class NotificationInboxPage {
  const NotificationInboxPage({
    required this.items,
    required this.total,
    required this.unreadCount,
  });

  final List<AppNotification> items;
  final int total;
  final int unreadCount;
}

class SendNotificationResult {
  const SendNotificationResult({required this.recipientCount, required this.pushAttempted, required this.pushMocked});

  final int recipientCount;
  final bool pushAttempted;
  final bool pushMocked;
}

class NotificationApi {
  NotificationApi(this._dio);

  final Dio _dio;

  Future<NotificationInboxPage> fetchMyNotifications({int page = 1, int limit = 20}) async {
    try {
      final response = await _dio.get('/notifications/me', queryParameters: {
        'page': page,
        'limit': limit,
      });
      final data = response.data['data'] as Map<String, dynamic>;
      final items = (data['items'] as List<dynamic>)
          .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
          .toList();
      return NotificationInboxPage(
        items: items,
        total: data['total'] as int? ?? items.length,
        unreadCount: data['unreadCount'] as int? ?? 0,
      );
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<void> markRead(String recipientId) async {
    try {
      await _dio.patch('/notifications/$recipientId/read');
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<void> markAllRead() async {
    try {
      await _dio.post('/notifications/read-all');
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<void> delete(String recipientId) async {
    try {
      await _dio.delete('/notifications/$recipientId');
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<SendNotificationResult> send({
    required String title,
    required String body,
    required NotificationAudience audience,
    String? imageUrl,
  }) async {
    try {
      final response = await _dio.post('/notifications', data: {
        'title': title,
        'body': body,
        'audience': audience.toJson(),
        if (imageUrl != null) 'imageUrl': imageUrl,
      });
      final data = response.data['data'] as Map<String, dynamic>;
      final push = data['push'] as Map<String, dynamic>? ?? const {};
      return SendNotificationResult(
        recipientCount: data['recipientCount'] as int? ?? 0,
        pushAttempted: push['attempted'] as bool? ?? false,
        pushMocked: push['mocked'] as bool? ?? false,
      );
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<List<SentNotification>> fetchHistory({int page = 1, int limit = 20}) async {
    try {
      final response = await _dio.get('/notifications/history', queryParameters: {
        'page': page,
        'limit': limit,
      });
      final data = response.data['data'] as Map<String, dynamic>;
      return (data['items'] as List<dynamic>)
          .map((e) => SentNotification.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  NotificationApiException _mapError(DioException error) {
    final data = error.response?.data;
    final message = data?['message'] as String? ?? 'Something went wrong. Please try again.';
    final reason = data?['details']?['reason'] as String?;
    return NotificationApiException(message, reason: reason);
  }
}
