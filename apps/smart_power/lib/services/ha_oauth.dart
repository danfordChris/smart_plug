import 'package:dio/dio.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import '../config/constants.dart';

/// Tokens returned by HA's `/auth/token` endpoint.
class HaTokens {
  final String accessToken;
  final String? refreshToken;
  final DateTime expiresAt;

  const HaTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  factory HaTokens.fromJson(Map<String, dynamic> json) {
    final expiresIn = (json['expires_in'] as num?)?.toInt() ?? 1800;
    return HaTokens(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String?,
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
    );
  }
}

/// HA's authorization-code flow. Non-standard but well documented:
///   1. `GET /auth/authorize?client_id=<url>&redirect_uri=<scheme://cb>`
///      → HA shows its own login page in the system browser.
///   2. On success HA redirects to `<scheme://cb>?code=XXX`.
///   3. `POST /auth/token` { grant_type, code, client_id } → tokens.
///   4. Later: `POST /auth/token` { grant_type=refresh_token, refresh_token,
///      client_id } → fresh access token.
///
/// The user sees Plug Assistance's own login form (system browser) — they
/// type their HA password there, never inside this app.
class HaOAuth {
  HaOAuth._();

  /// Runs the full authorization-code flow and returns fresh tokens.
  /// Throws on user cancel / network failure / non-2xx.
  static Future<HaTokens> authorize(String haUrl) async {
    final base = _normalizeBase(haUrl);
    final authUri = Uri.parse('$base/auth/authorize').replace(
      queryParameters: {
        'client_id': AppConstants.oauthClientId,
        'redirect_uri': AppConstants.oauthRedirectUri,
        'response_type': 'code',
      },
    );

    final resultUrl = await FlutterWebAuth2.authenticate(
      url: authUri.toString(),
      callbackUrlScheme: AppConstants.oauthRedirectScheme,
      options: const FlutterWebAuth2Options(
        preferEphemeral: true,
      ),
    );

    final resultUri = Uri.parse(resultUrl);
    final code = resultUri.queryParameters['code'];
    final error = resultUri.queryParameters['error'];
    if (error != null) {
      throw StateError('Plug Assistance returned error: $error');
    }
    if (code == null || code.isEmpty) {
      throw StateError('No authorization code returned by Plug Assistance');
    }

    return _exchange(base, {
      'grant_type': 'authorization_code',
      'code': code,
      'client_id': AppConstants.oauthClientId,
    });
  }

  /// Exchanges a refresh token for a fresh access token. Refresh tokens
  /// stay valid until revoked from HA's profile UI.
  static Future<HaTokens> refresh(String haUrl, String refreshToken) async {
    final base = _normalizeBase(haUrl);
    return _exchange(base, {
      'grant_type': 'refresh_token',
      'refresh_token': refreshToken,
      'client_id': AppConstants.oauthClientId,
    });
  }

  static Future<HaTokens> _exchange(
    String base,
    Map<String, String> form,
  ) async {
    final dio = Dio(BaseOptions(
      connectTimeout: AppConstants.httpTimeout,
      receiveTimeout: AppConstants.httpTimeout,
      contentType: Headers.formUrlEncodedContentType,
    ));
    try {
      final res = await dio.post('$base/auth/token', data: form);
      if (res.data is! Map) {
        throw StateError('Unexpected /auth/token response shape');
      }
      return HaTokens.fromJson(Map<String, dynamic>.from(res.data as Map));
    } finally {
      dio.close();
    }
  }

  static String _normalizeBase(String url) {
    var u = url.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }
}
