import 'package:access_mobile/shared/api/api_client.dart';
import 'package:access_mobile/shared/models/user_model.dart';

class AuthService {
  AuthService(this._api);
  final ApiClient _api;

  Future<AuthUser> login(String email, String password) async {
    final data = await _api.postLogin('/auth/login', {
      'email': email.trim().toLowerCase(),
      'password': password,
    }) as Map<String, dynamic>;

    final token = data['token'] as String;
    final userJson = data['user'] as Map<String, dynamic>;
    final user = AuthUser.fromJson(userJson, token);
    _api.setToken(token);
    return user;
  }

  Future<RegistrationOtpSendResult> sendRegistrationOtp({
    required String email,
    String? name,
  }) async {
    final data = await _api.post('/auth/registration-otp/send', {
      'email': email.trim().toLowerCase(),
      if (name != null && name.isNotEmpty) 'name': name.trim(),
    }) as Map<String, dynamic>;
    return RegistrationOtpSendResult(
      message: (data['message'] as String?) ?? 'Verification code sent.',
      devCode: data['dev_code'] as String?,
    );
  }

  Future<String> verifyRegistrationOtp({
    required String email,
    required String code,
  }) async {
    final data = await _api.post('/auth/registration-otp/verify', {
      'email': email.trim().toLowerCase(),
      'code': code.trim(),
    }) as Map<String, dynamic>;
    return data['email_verification_token'] as String;
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String role,
    String? studentId,
    String? contactNumber,
    String? emailVerificationToken,
    String? adviserName,
    String? skillLevel,
  }) async {
    await _api.post('/auth/register', {
      'name': name,
      'email': email.trim().toLowerCase(),
      'password': password,
      'role': role,
      if (studentId != null && studentId.isNotEmpty) 'student_id': studentId,
      if (contactNumber != null && contactNumber.isNotEmpty) 'contact_number': contactNumber,
      if (emailVerificationToken != null && emailVerificationToken.isNotEmpty)
        'email_verification_token': emailVerificationToken,
      if (adviserName != null && adviserName.isNotEmpty) 'adviser_name': adviserName,
      if (skillLevel != null && skillLevel.isNotEmpty) 'skill_level': skillLevel,
    });
  }

  Future<ForgotPasswordSendResult> sendForgotPasswordOtp(String email) async {
    final data = await _api.post('/auth/forgot-password/send', {
      'email': email.trim().toLowerCase(),
    }) as Map<String, dynamic>;
    return ForgotPasswordSendResult(
      message: (data['message'] as String?) ?? 'If an account exists, a code was sent.',
      devCode: data['dev_code'] as String?,
    );
  }

  Future<String> completeForgotPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final data = await _api.post('/auth/forgot-password/complete', {
      'email': email.trim().toLowerCase(),
      'code': code.trim(),
      'new_password': newPassword,
    }) as Map<String, dynamic>;
    return (data['message'] as String?) ?? 'Password updated.';
  }

  Future<void> logout() async {
    try {
      await _api.post('/auth/logout', {});
    } catch (_) {
      // Token may already be invalid; still clear local session.
    }
    _api.setToken(null);
  }
}

class ForgotPasswordSendResult {
  const ForgotPasswordSendResult({required this.message, this.devCode});

  final String message;
  final String? devCode;
}

class RegistrationOtpSendResult {
  const RegistrationOtpSendResult({required this.message, this.devCode});

  final String message;
  final String? devCode;
}

final authService = AuthService(apiClient);
