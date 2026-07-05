import 'package:dio/dio.dart';

import '../domain/event_summary.dart';

class EventApiException implements Exception {
  EventApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class EventApi {
  EventApi(this._dio);

  final Dio _dio;

  Future<EventSummary> getEvent(String eventId) async {
    try {
      final response = await _dio.get('/events/$eventId');
      return EventSummary.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (error) {
      throw EventApiException(
        error.response?.data?['message'] as String? ?? 'Could not load this event.',
        statusCode: error.response?.statusCode,
      );
    }
  }
}
