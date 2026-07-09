import 'package:dio/dio.dart';

import '../domain/registration_models.dart';

/// Thrown for any failed registration action, carrying a message that's
/// already safe and meaningful to show directly in the UI (duplicate
/// registration, event full, invalid team size, registration closed, etc.)
class RegistrationApiException implements Exception {
  RegistrationApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

/// Result of a successful POST /registrations call.
class NewRegistration {
  const NewRegistration({required this.registrationId, required this.status, required this.qrToken});

  final String registrationId;
  final String status; // 'Confirmed' | 'Pending Payment'
  final String qrToken;

  bool get needsPayment => status == 'Pending Payment';
}

class RegistrationApi {
  RegistrationApi(this._dio);

  final Dio _dio;

  Future<NewRegistration> register({
    required String eventId,
    String? teamName,
    List<TeamMemberInput>? members,
  }) async {
    try {
      final response = await _dio.post('/registrations', data: {
        'eventId': eventId,
        if (teamName != null) 'teamName': teamName,
        if (members != null) 'members': members.map((m) => m.toJson()).toList(),
      });
      final data = response.data['data'] as Map<String, dynamic>;
      final registration = data['registration'] as Map<String, dynamic>;
      return NewRegistration(
        registrationId: registration['_id'] as String,
        status: registration['status'] as String? ?? 'Confirmed',
        qrToken: data['qrToken'] as String? ?? '',
      );
    } on DioException catch (error) {
      throw RegistrationApiException(
        _extractMessage(error),
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<List<MyRegistration>> fetchMyRegistrations() async {
    try {
      final response = await _dio.get('/registrations/me');
      final list = response.data['data'] as List<dynamic>;
      return list
          .map((item) => MyRegistration.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (error) {
      throw RegistrationApiException(_extractMessage(error));
    }
  }

  Future<void> cancel(String registrationId) async {
    try {
      await _dio.patch('/registrations/$registrationId/cancel');
    } on DioException catch (error) {
      throw RegistrationApiException(_extractMessage(error));
    }
  }

  /// Fetches the (deterministic, regenerable) QR token for a registration
  /// so it can be displayed in My Events. Only succeeds for registrations
  /// that are actually checkable-in (Confirmed/Attended/Completed) — the
  /// backend returns 409 for Pending Payment or Cancelled registrations.
  Future<String> fetchQrToken(String registrationId) async {
    try {
      final response = await _dio.get('/registrations/$registrationId/qr');
      return response.data['data']['qrToken'] as String;
    } on DioException catch (error) {
      throw RegistrationApiException(_extractMessage(error), statusCode: error.response?.statusCode);
    }
  }

  String _extractMessage(DioException error) {
    final backendMessage = error.response?.data?['message'] as String?;
    if (backendMessage != null && backendMessage.isNotEmpty) return backendMessage;
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout) {
      return 'Could not reach the server. Check your connection and try again.';
    }
    return 'Something went wrong. Please try again.';
  }
}
