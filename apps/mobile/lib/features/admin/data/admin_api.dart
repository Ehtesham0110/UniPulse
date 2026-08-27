import 'package:dio/dio.dart';

import '../domain/admin_member.dart';

class AdminApiException implements Exception {
  AdminApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class AdminApi {
  AdminApi(this._dio);

  final Dio _dio;

  Future<List<AdminMember>> listAdmins() async {
    try {
      final response = await _dio.get('/admins');
      final list = response.data['data'] as List<dynamic>;
      return list.map((e) => AdminMember.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (error) {
      throw AdminApiException(
        error.response?.data?['message'] as String? ?? 'Could not load admin team list.',
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<AdminMember> inviteAdmin({
    required String phone,
    String? fullName,
    String? role,
  }) async {
    try {
      final response = await _dio.post('/admins/invite', data: {
        'phone': phone,
        if (fullName != null) 'fullName': fullName,
        if (role != null) 'role': role,
      });
      return AdminMember.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (error) {
      throw AdminApiException(
        error.response?.data?['message'] as String? ?? 'Could not invite admin.',
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<AdminMember> updateRole({
    required String userId,
    required String role,
  }) async {
    try {
      final response = await _dio.patch('/admins/$userId/role', data: {'role': role});
      return AdminMember.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (error) {
      throw AdminApiException(
        error.response?.data?['message'] as String? ?? 'Could not update admin role.',
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<void> removeAdmin(String userId) async {
    try {
      await _dio.delete('/admins/$userId');
    } on DioException catch (error) {
      throw AdminApiException(
        error.response?.data?['message'] as String? ?? 'Could not remove admin.',
        statusCode: error.response?.statusCode,
      );
    }
  }
}
