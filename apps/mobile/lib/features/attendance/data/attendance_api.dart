import 'package:dio/dio.dart';

import '../domain/scanned_attendee.dart';

/// Thrown for any failed attendance action. `reason` mirrors the
/// backend's `details.reason` code (INVALID_QR, ALREADY_CHECKED_IN,
/// CANCELLED, PAYMENT_PENDING, WRONG_EVENT, EVENT_ENDED,
/// ALREADY_CHECKED_OUT, NOT_CHECKED_IN) so the UI can show a specific
/// warning style instead of a generic error.
class AttendanceApiException implements Exception {
  AttendanceApiException(this.message, {this.reason});
  final String message;
  final String? reason;
  @override
  String toString() => message;
}

class AttendanceApi {
  AttendanceApi(this._dio);

  final Dio _dio;

  Future<ScannedAttendee> validate({required String qrToken, String? eventId}) async {
    try {
      final response = await _dio.post('/attendance/validate', data: {
        'qrToken': qrToken,
        if (eventId != null) 'eventId': eventId,
      });
      return ScannedAttendee.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<ScannedAttendee> checkIn({
    required String qrToken,
    String? eventId,
    String? scannerDevice,
  }) async {
    try {
      final response = await _dio.post('/attendance/check-in', data: {
        'qrToken': qrToken,
        if (eventId != null) 'eventId': eventId,
        if (scannerDevice != null) 'scannerDevice': scannerDevice,
      });
      return ScannedAttendee.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<ScannedAttendee> checkOut({
    required String qrToken,
    String? eventId,
    String? scannerDevice,
  }) async {
    try {
      final response = await _dio.post('/attendance/check-out', data: {
        'qrToken': qrToken,
        if (eventId != null) 'eventId': eventId,
        if (scannerDevice != null) 'scannerDevice': scannerDevice,
      });
      return ScannedAttendee.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  AttendanceApiException _mapError(DioException error) {
    final data = error.response?.data;
    final message = data?['message'] as String? ?? 'Something went wrong. Please try again.';
    final reason = data?['details']?['reason'] as String?;
    return AttendanceApiException(message, reason: reason);
  }
}
