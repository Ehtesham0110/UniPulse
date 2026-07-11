import 'package:dio/dio.dart';

import '../../../core/network/api_config.dart';
import '../domain/earned_certificate.dart';

class CertificateApiException implements Exception {
  CertificateApiException(this.message, {this.reason});
  final String message;
  final String? reason;
  @override
  String toString() => message;
}

class BulkGenerateSummary {
  const BulkGenerateSummary({
    required this.totalEligible,
    required this.generatedCount,
    required this.skipped,
  });

  factory BulkGenerateSummary.fromJson(Map<String, dynamic> json) => BulkGenerateSummary(
        totalEligible: json['totalEligible'] as int? ?? 0,
        generatedCount: (json['generated'] as List<dynamic>? ?? const []).length,
        skipped: (json['skipped'] as List<dynamic>? ?? const [])
            .map((s) => (s as Map<String, dynamic>)['reason'] as String? ?? 'ERROR')
            .toList(),
      );

  final int totalEligible;
  final int generatedCount;
  final List<String> skipped;
}

class CertificateApi {
  CertificateApi(this._dio);

  final Dio _dio;

  Future<List<EarnedCertificate>> fetchMyCertificates() async {
    try {
      final response = await _dio.get('/certificates/me');
      final list = response.data['data'] as List<dynamic>;
      return list.map((e) => EarnedCertificate.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<void> generate({required String registrationId, String? templateId}) async {
    try {
      await _dio.post('/certificates/generate', data: {
        'registrationId': registrationId,
        if (templateId != null) 'templateId': templateId,
      });
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<BulkGenerateSummary> bulkGenerate({required String eventId, String? templateId}) async {
    try {
      final response = await _dio.post('/certificates/bulk-generate', data: {
        'eventId': eventId,
        if (templateId != null) 'templateId': templateId,
      });
      return BulkGenerateSummary.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<void> regenerate(String certificateId) async {
    try {
      await _dio.post('/certificates/$certificateId/regenerate', data: {'confirm': true});
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  CertificateApiException _mapError(DioException error) {
    final data = error.response?.data;
    final message = data?['message'] as String? ?? 'Something went wrong. Please try again.';
    final reason = data?['details']?['reason'] as String?;
    return CertificateApiException(message, reason: reason);
  }
}

/// Builds a fully-qualified, token-authenticated URL for opening a
/// certificate PDF in an external viewer (browser / PDF app). External
/// viewers launched via `url_launcher` can't attach an Authorization
/// header, so the access token travels as a `?token=` query param instead
/// — see the matching backend fallback in `middleware/auth.js`.
String buildCertificateExternalUrl(String pdfPath, String accessToken) {
  final origin = ApiConfig.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
  final separator = pdfPath.contains('?') ? '&' : '?';
  return '$origin$pdfPath${separator}token=$accessToken';
}
