import 'package:dio/dio.dart';

import '../domain/event_summary.dart';

class EventApiException implements Exception {
  EventApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

/// Query parameters for listing events. Used as a Riverpod family key, so
/// it implements value equality.
class EventListQuery {
  const EventListQuery({this.category, this.search, this.startDate, this.endDate});

  final String? category;
  final String? search;
  final String? startDate;
  final String? endDate;

  @override
  bool operator ==(Object other) =>
      other is EventListQuery &&
      other.category == category &&
      other.search == search &&
      other.startDate == startDate &&
      other.endDate == endDate;

  @override
  int get hashCode => Object.hash(category, search, startDate, endDate);
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

  Future<List<EventSummary>> listEvents(EventListQuery query) async {
    try {
      final response = await _dio.get('/events', queryParameters: {
        if (query.category != null) 'category': query.category,
        if (query.search != null && query.search!.trim().isNotEmpty) 'search': query.search!.trim(),
        if (query.startDate != null) 'startDate': query.startDate,
        if (query.endDate != null) 'endDate': query.endDate,
        'limit': 100,
      });
      final list = response.data['data'] as List<dynamic>;
      return list.map((e) => EventSummary.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (error) {
      throw EventApiException(
        error.response?.data?['message'] as String? ?? 'Could not load events.',
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<bool> toggleBookmark(String eventId) async {
    try {
      final response = await _dio.post('/events/$eventId/bookmark');
      return response.data['data']['isBookmarked'] as bool;
    } on DioException catch (error) {
      throw EventApiException(
        error.response?.data?['message'] as String? ?? 'Could not update bookmark.',
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<EventSummary> createEvent(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/events', data: data);
      return EventSummary.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (error) {
      throw EventApiException(
        error.response?.data?['message'] as String? ?? 'Could not create event.',
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<EventSummary> updateEvent(String eventId, Map<String, dynamic> data) async {
    try {
      final response = await _dio.patch('/events/$eventId', data: data);
      return EventSummary.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (error) {
      throw EventApiException(
        error.response?.data?['message'] as String? ?? 'Could not update event.',
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<void> deleteEvent(String eventId) async {
    try {
      await _dio.delete('/events/$eventId');
    } on DioException catch (error) {
      throw EventApiException(
        error.response?.data?['message'] as String? ?? 'Could not delete event.',
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<EventSummary> approveEvent(String eventId) async {
    try {
      final response = await _dio.post('/events/$eventId/approve');
      return EventSummary.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (error) {
      throw EventApiException(
        error.response?.data?['message'] as String? ?? 'Could not publish event.',
        statusCode: error.response?.statusCode,
      );
    }
  }
}
