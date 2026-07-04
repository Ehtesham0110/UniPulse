import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';
import '../../../core/storage/secure_token_storage.dart';
import '../data/auth_api.dart';
import 'auth_state.dart';

final secureTokenStorageProvider = Provider<SecureTokenStorage>((ref) {
  return SecureTokenStorage();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(tokenStorage: ref.watch(secureTokenStorageProvider));
});

/// Bare Dio (no auth interceptor) used only for the login/refresh calls
/// that happen before we have a session.
final _bareDioProvider = Provider<Dio>((ref) {
  return Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
});

final authApiProvider = Provider<AuthApi>((ref) {
  return AuthApi(ref.watch(_bareDioProvider));
});

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(
    authApi: ref.watch(authApiProvider),
    tokenStorage: ref.watch(secureTokenStorageProvider),
    firebaseAuth: FirebaseAuth.instance,
  );
});

class AuthController extends StateNotifier<AuthState> {
  AuthController({
    required AuthApi authApi,
    required SecureTokenStorage tokenStorage,
    required FirebaseAuth firebaseAuth,
  })  : _authApi = authApi,
        _tokenStorage = tokenStorage,
        _firebaseAuth = firebaseAuth,
        super(const AuthState());

  final AuthApi _authApi;
  final SecureTokenStorage _tokenStorage;
  final FirebaseAuth _firebaseAuth;

  /// The most recently verified Firebase ID token. Kept in memory (never
  /// persisted) so that when the backend responds "signup required" we can
  /// finish account creation without forcing the user through OTP again.
  String? _verifiedIdToken;

  /// Called once on app start (from the splash screen). Checks whether we
  /// already have a valid session so the user doesn't have to log in again.
  Future<void> tryAutoLogin() async {
    state = state.copyWith(status: AuthStatus.loading);
    final accessToken = await _tokenStorage.readAccessToken();
    if (accessToken == null) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return;
    }

    try {
      final user = await _authApi.fetchCurrentUser();
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
    } catch (_) {
      // ApiClient will have already tried a token refresh internally; if
      // we're still here, the session is truly invalid.
      await _tokenStorage.clear();
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  /// Step 1 of login/signup: send an OTP to the given phone number via
  /// Firebase. [phoneNumber] must be in E.164 format, e.g. +919876543210.
  Future<void> sendOtp({
    required String phoneNumber,
    required String collegeCode,
    PendingSignupDetails? pendingSignup,
  }) async {
    state = state.copyWith(
      status: AuthStatus.loading,
      phoneNumber: phoneNumber,
      collegeCode: collegeCode,
      pendingSignup: pendingSignup,
      errorMessage: null,
    );

    try {
      await _firebaseAuth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (credential) async {
          // Android auto-retrieval: sign in immediately without asking
          // the user to type the OTP.
          await _finishLogin(credential);
        },
        verificationFailed: (error) {
          state = state.copyWith(
            status: AuthStatus.error,
            errorMessage: error.message ?? 'Phone verification failed.',
          );
        },
        codeSent: (verificationId, resendToken) {
          state = state.copyWith(
            status: AuthStatus.codeSent,
            verificationId: verificationId,
          );
        },
        codeAutoRetrievalTimeout: (verificationId) {
          if (state.status == AuthStatus.codeSent) {
            state = state.copyWith(verificationId: verificationId);
          }
        },
      );
    } on FirebaseAuthException catch (error) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: error.message ?? 'Could not send OTP. Please try again.',
      );
    }
  }

  /// Step 2 of login/signup: verify the 6-digit OTP the user typed in.
  Future<void> verifyOtp(String smsCode) async {
    final verificationId = state.verificationId;
    if (verificationId == null) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Session expired. Please request a new OTP.',
      );
      return;
    }

    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);

    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );

    try {
      await _finishLogin(credential);
    } on FirebaseAuthException catch (error) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: error.message ?? 'Incorrect OTP. Please try again.',
      );
    }
  }

  Future<void> _finishLogin(PhoneAuthCredential credential) async {
    final userCredential = await _firebaseAuth.signInWithCredential(credential);
    final idToken = await userCredential.user?.getIdToken();
    if (idToken == null) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Could not verify your identity. Please try again.',
      );
      return;
    }

    _verifiedIdToken = idToken;
    await _submitLogin(idToken, state.pendingSignup);
  }

  /// Called from the signup form after a "signup required" response, using
  /// the already-verified Firebase ID token (no new OTP needed).
  Future<void> completeSignup(PendingSignupDetails details) async {
    final idToken = _verifiedIdToken;
    if (idToken == null) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Your session expired. Please verify your phone number again.',
      );
      return;
    }
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    await _submitLogin(idToken, details);
  }

  Future<void> _submitLogin(String idToken, PendingSignupDetails? pending) async {
    try {
      final result = await _authApi.firebaseLogin(
        idToken: idToken,
        collegeCode: state.collegeCode,
        fullName: pending?.fullName,
        rollNumber: pending?.rollNumber,
        branch: pending?.branch,
        year: pending?.year,
      );

      await _tokenStorage.saveTokens(
        accessToken: result.tokens.accessToken,
        refreshToken: result.tokens.refreshToken,
      );

      _verifiedIdToken = null;
      state = state.copyWith(status: AuthStatus.authenticated, user: result.user);
    } on SignupRequiredException {
      state = state.copyWith(status: AuthStatus.signupRequired);
    } on AuthApiException catch (error) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: error.message);
    }
  }

  Future<void> logout() async {
    await _firebaseAuth.signOut();
    await _tokenStorage.clear();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void clearError() {
    if (state.status == AuthStatus.error) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }
}
