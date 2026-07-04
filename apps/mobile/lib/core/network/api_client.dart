import 'package:dio/dio.dart';

import '../storage/secure_token_storage.dart';
import 'api_config.dart';

/// Thin wrapper around Dio that:
///  - points every request at the UniPulse backend
///  - attaches the stored access token to every request
///  - transparently refreshes the access token on a 401 and retries once
class ApiClient {
  ApiClient({SecureTokenStorage? tokenStorage})
      : _tokenStorage = tokenStorage ?? SecureTokenStorage(),
        _dio = Dio(
          BaseOptions(
            baseUrl: ApiConfig.baseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
          ),
        ),
        // Separate, interceptor-free client used only for the refresh call
        // itself, so a failing refresh can never trigger another refresh.
        _refreshDio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl)) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenStorage.readAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final isUnauthorized = error.response?.statusCode == 401;
          final alreadyRetried = error.requestOptions.extra['retried'] == true;

          if (!isUnauthorized || alreadyRetried) {
            handler.next(error);
            return;
          }

          final refreshed = await _tryRefreshToken();
          if (!refreshed) {
            handler.next(error);
            return;
          }

          try {
            final retryOptions = error.requestOptions;
            retryOptions.extra['retried'] = true;
            final newToken = await _tokenStorage.readAccessToken();
            retryOptions.headers['Authorization'] = 'Bearer $newToken';
            final response = await _dio.fetch(retryOptions);
            handler.resolve(response);
          } catch (retryError) {
            handler.next(error);
          }
        },
      ),
    );
  }

  final Dio _dio;
  final Dio _refreshDio;
  final SecureTokenStorage _tokenStorage;

  Dio get dio => _dio;

  Future<bool> _tryRefreshToken() async {
    final refreshToken = await _tokenStorage.readRefreshToken();
    if (refreshToken == null) return false;

    try {
      final response = await _refreshDio.post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final newAccessToken =
          response.data['data']['tokens']['accessToken'] as String;
      await _tokenStorage.saveAccessToken(newAccessToken);
      return true;
    } on DioException {
      await _tokenStorage.clear();
      return false;
    }
  }
}
