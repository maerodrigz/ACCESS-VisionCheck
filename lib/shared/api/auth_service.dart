import 'package:access_mobile/shared/api/api_client.dart';
import 'package:access_mobile/shared/models/user_model.dart';

class AuthService {
  AuthService(this._api);
  final ApiClient _api;

  Future<AuthUser> login(String email, String password) async {
    final data = await _api.post('/auth/login', {
      'email': email.trim().toLowerCase(),
      'password': password,
    }) as Map<String, dynamic>;

    final token = data['token'] as String;
    final userJson = data['user'] as Map<String, dynamic>;
    final user = AuthUser.fromJson(userJson, token);
    _api.setToken(token);
    return user;
  }

  Future<RegistrationOtpSendResult> sendRegistrationOtp(String phone) async {
    final data = await _api.post('/auth/registration-otp/send', {
      'phone': phone.trim(),
    }) as Map<String, dynamic>;
    return RegistrationOtpSendResult(
      message: (data['message'] as String?) ?? 'Verification code sent.',
      devCode: data['dev_code'] as String?,
    );
  }

  Future<String> verifyRegistrationOtp({
    required String phone,
    required String code,
  }) async {
    final data = await _api.post('/auth/registration-otp/verify', {
      'phone': phone.trim(),
      'code': code.trim(),
    }) as Map<String, dynamic>;
    return data['phone_verification_token'] as String;
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String role,
    String? studentId,
    String? contactNumber,
    String? phoneVerificationToken,
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
      if (phoneVerificationToken != null && phoneVerificationToken.isNotEmpty)
        'phone_verification_token': phoneVerificationToken,
      if (adviserName != null && adviserName.isNotEmpty) 'adviser_name': adviserName,
      if (skillLevel != null && skillLevel.isNotEmpty) 'skill_level': skillLevel,
    });
  }

  Future<ForgotPasswordResult> requestPasswordReset(String email) async {
    final data = await _api.post('/auth/forgot-password', {
      'email': email.trim().toLowerCase(),
    }) as Map<String, dynamic>;
    return ForgotPasswordResult(
      message: (data['message'] as String?) ?? 'Request submitted.',
      temporaryPassword: data['temporary_password'] as String?,
      reset: data['reset'] == true,
    );
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

class ForgotPasswordResult {
  const ForgotPasswordResult({
    required this.message,
    this.temporaryPassword,
    this.reset = false,
  });

  final String message;
  final String? temporaryPassword;
  final bool reset;
}

class RegistrationOtpSendResult {
  const RegistrationOtpSendResult({required this.message, this.devCode});

  final String message;
  final String? devCode;
}

final authService = AuthService(apiClient);
