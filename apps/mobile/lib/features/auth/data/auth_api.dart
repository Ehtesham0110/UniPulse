import 'package:dio/dio.dart';

import '../domain/app_user.dart';

class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  factory AuthTokens.fromJson(Map<String, dynamic> json) => AuthTokens(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
      );

  final String accessToken;
  final String refreshToken;
}

class LoginResult {
  const LoginResult({required this.user, required this.tokens, required this.isNewUser});

  final AppUser user;
  final AuthTokens tokens;
  final bool isNewUser;
}

/// Thrown when the backend tells us a brand-new phone number needs signup
/// details (full name, roll number, branch, year) before an account can be
/// created.
class SignupRequiredException implements Exception {
  const SignupRequiredException();
}

class AuthApiException implements Exception {
  AuthApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Talks to the /auth/* endpoints. Deliberately uses its own bare Dio
/// instance (not the interceptor-wrapped ApiClient) for the login call,
/// since there is no access token yet at that point.
class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  Future<LoginResult> firebaseLogin({
    required String idToken,
    required String collegeCode,
    String? fullName,
    String? rollNumber,
    String? branch,
    int? year,
  }) async {
    try {
      final response = await _dio.post('/auth/firebase-login', data: {
        'idToken': idToken,
        'collegeCode': collegeCode,
        if (fullName != null) 'fullName': fullName,
        if (rollNumber != null) 'rollNumber': rollNumber,
        if (branch != null) 'branch': branch,
        if (year != null) 'year': year,
      });

      final data = response.data['data'] as Map<String, dynamic>;
      return LoginResult(
        user: AppUser.fromJson(data['user'] as Map<String, dynamic>),
        tokens: AuthTokens.fromJson(data['tokens'] as Map<String, dynamic>),
        isNewUser: data['isNewUser'] as bool? ?? false,
      );
    } on DioException catch (error) {
      if (error.response?.statusCode == 422 &&
          error.response?.data?['details']?['reason'] == 'SIGNUP_REQUIRED') {
        throw const SignupRequiredException();
      }
      throw AuthApiException(
        error.response?.data?['message'] as String? ?? 'Login failed. Please try again.',
      );
    }
  }

  Future<AppUser> fetchCurrentUser() async {
    final response = await _dio.get('/auth/me');
    return AppUser.fromJson(response.data['data']['user'] as Map<String, dynamic>);
  }
}
