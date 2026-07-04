import '../domain/app_user.dart';

enum AuthStatus {
  /// We haven't yet checked secure storage for an existing session.
  unknown,

  /// No valid session; user should see the welcome/login screen.
  unauthenticated,

  /// Firebase has sent an OTP; user is on the OTP screen.
  codeSent,

  /// A backend account exists and needs signup details before we can
  /// finish creating it (first-time user).
  signupRequired,

  /// A network/verification action is in flight.
  loading,

  /// Fully logged in with a valid backend session.
  authenticated,

  /// Something went wrong; message carries details for the UI.
  error,
}

class PendingSignupDetails {
  const PendingSignupDetails({
    required this.fullName,
    required this.rollNumber,
    required this.branch,
    required this.year,
  });

  final String fullName;
  final String rollNumber;
  final String branch;
  final int year;
}

class AuthState {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.phoneNumber,
    this.verificationId,
    this.collegeCode = 'UNIPULSE',
    this.pendingSignup,
    this.user,
    this.errorMessage,
  });

  final AuthStatus status;
  final String? phoneNumber;
  final String? verificationId;
  final String collegeCode;
  final PendingSignupDetails? pendingSignup;
  final AppUser? user;
  final String? errorMessage;

  AuthState copyWith({
    AuthStatus? status,
    String? phoneNumber,
    String? verificationId,
    String? collegeCode,
    PendingSignupDetails? pendingSignup,
    AppUser? user,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      verificationId: verificationId ?? this.verificationId,
      collegeCode: collegeCode ?? this.collegeCode,
      pendingSignup: pendingSignup ?? this.pendingSignup,
      user: user ?? this.user,
      errorMessage: errorMessage,
    );
  }
}
