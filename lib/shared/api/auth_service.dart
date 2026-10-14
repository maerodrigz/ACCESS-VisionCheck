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

  Future<String> sendRegistrationOtp(String phone) async {
    final data = await _api.post('/auth/registration-otp/send', {
      'phone': phone.trim(),
    }) as Map<String, dynamic>;
    return (data['message'] as String?) ?? 'Verification code sent.';
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

  void logout() => _api.setToken(null);
}

final authService = AuthService(apiClient);
