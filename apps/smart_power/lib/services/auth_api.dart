import 'package:dio/dio.dart';

import '../config/constants.dart';

/// Result of a successful login / refresh — the per-user session.
class AuthSession {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final String role;

  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.role,
  });

  factory AuthSession.fromJson(Map<String, dynamic> j) => AuthSession(
        accessToken: j['access_token'] as String,
        refreshToken: j['refresh_token'] as String,
        expiresIn: (j['expires_in'] as num?)?.toInt() ?? 0,
        role: j['role'] as String? ?? 'user',
      );
}

/// Result of a signup attempt.
class SignupResult {
  final String status; // "active" | "pending"
  final String role;
  final String message;

  const SignupResult({
    required this.status,
    required this.role,
    required this.message,
  });

  bool get isActive => status == 'active';

  factory SignupResult.fromJson(Map<String, dynamic> j) => SignupResult(
        status: j['status'] as String? ?? 'pending',
        role: j['role'] as String? ?? 'user',
        message: j['message'] as String? ?? '',
      );
}

/// Human-readable auth failure, surfaced on the login screen.
class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
  @override
  String toString() => message;
}

/// Client for the Plug Assistance gateway's auth + proxy endpoints.
class AuthApi {
  AuthApi({required this.baseUrl, Dio? dio})
      : _dio = (dio ?? Dio())
          ..options.baseUrl = baseUrl
          ..options.connectTimeout = AppConstants.httpTimeout
          ..options.receiveTimeout = AppConstants.httpTimeout
          ..options.headers = {'Content-Type': 'application/json'}
          // Let us read the body on 4xx so we can show the server's reason.
          ..options.validateStatus = ((status) => status != null && status < 500);

  final String baseUrl;
  final Dio _dio;

  Future<SignupResult> signup({
    required String email,
    required String password,
    String? inviteCode,
  }) async {
    final res = await _post('/auth/signup', {
      'email': email,
      'password': password,
      if (inviteCode != null && inviteCode.isNotEmpty) 'invite_code': inviteCode,
    });
    return SignupResult.fromJson(Map<String, dynamic>.from(res));
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final res = await _post('/auth/login', {
      'email': email,
      'password': password,
    });
    return AuthSession.fromJson(Map<String, dynamic>.from(res));
  }

  Future<AuthSession> refresh(String refreshToken) async {
    final res = await _post('/auth/refresh', {'refresh_token': refreshToken});
    return AuthSession.fromJson(Map<String, dynamic>.from(res));
  }

  /// Best-effort logout — revokes the refresh token server-side.
  Future<void> logout(String refreshToken) async {
    try {
      await _dio.post('/auth/logout', data: {'refresh_token': refreshToken});
    } catch (_) {
      // Logout should always succeed locally even if the server is unreachable.
    }
  }

  /// Posts JSON and returns the decoded body, mapping errors to [AuthException].
  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    late final Response res;
    try {
      res = await _dio.post(path, data: body);
    } on DioException catch (e) {
      throw AuthException(_networkMessage(e));
    }
    final code = res.statusCode ?? 0;
    if (code >= 200 && code < 300) {
      if (res.data is Map) return Map<String, dynamic>.from(res.data as Map);
      return <String, dynamic>{};
    }
    throw AuthException(_detail(res) ?? 'Request failed ($code).');
  }

  String? _detail(Response res) {
    final data = res.data;
    if (data is Map && data['detail'] is String) return data['detail'] as String;
    if (data is Map && data['detail'] is List) {
      // FastAPI validation error shape.
      final list = data['detail'] as List;
      if (list.isNotEmpty && list.first is Map) {
        return (list.first as Map)['msg']?.toString();
      }
    }
    return null;
  }

  String _networkMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'Connection timed out. Is the gateway reachable from this device?';
      case DioExceptionType.connectionError:
        return "Couldn't reach the gateway. Check the URL and your network.";
      default:
        return e.message ?? "Couldn't reach the gateway.";
    }
  }

  void dispose() => _dio.close();
}
