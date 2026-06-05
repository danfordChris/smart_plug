import 'package:dio/dio.dart';

import '../config/constants.dart';
import '../models/ha_state.dart';

/// Returns a fresh access token, or null if the session can't be renewed.
typedef TokenRefresher = Future<String?> Function();

/// Thin client for the Plug Assistance gateway's HA-shaped REST API.
///
/// `baseUrl` points at the gateway and `token` is the user's access token; the
/// gateway forwards to Home Assistant. On a 401 (expired access token) the
/// optional [refresher] is invoked once to renew the token and the request is
/// retried transparently.
///
/// Endpoints used (mirror Home Assistant's REST API):
///   `GET  /api/`                                — auth + health check
///   `GET  /api/states`                          — list of all entities
///   `GET  /api/states/{entity_id}`              — single entity state
///   `POST /api/services/{domain}/{service}`     — call a service
class HaApi {
  HaApi({
    required this.baseUrl,
    required this.token,
    this.refresher,
    Dio? dio,
  }) : _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = baseUrl
      ..connectTimeout = AppConstants.httpTimeout
      ..receiveTimeout = AppConstants.httpTimeout
      ..headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };
    if (refresher != null) {
      _dio.interceptors.add(InterceptorsWrapper(onError: _onAuthError));
    }
  }

  final String baseUrl;
  final String token;
  final TokenRefresher? refresher;
  final Dio _dio;

  /// On 401, renew the access token once and replay the original request.
  Future<void> _onAuthError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final opts = err.requestOptions;
    final alreadyRetried = opts.extra['retried'] == true;
    if (err.response?.statusCode == 401 &&
        refresher != null &&
        !alreadyRetried) {
      final newToken = await refresher!();
      if (newToken != null) {
        opts.extra['retried'] = true;
        opts.headers['Authorization'] = 'Bearer $newToken';
        _dio.options.headers['Authorization'] = 'Bearer $newToken';
        try {
          return handler.resolve(await _dio.fetch(opts));
        } on DioException catch (retryErr) {
          return handler.next(retryErr);
        }
      }
    }
    handler.next(err);
  }

  /// Lightweight health check used by the Setup screen "Test connection"
  /// button. Returns the HA version string on success, throws otherwise.
  Future<HaInfo> testConnection() async {
    final res = await _dio.get('/api/');
    if (res.statusCode == 200 && res.data is Map) {
      final data = Map<String, dynamic>.from(res.data as Map);
      return HaInfo(
        message: data['message'] as String? ?? 'API running',
        // Older HA puts version in attribute / config endpoint; fall back to
        // calling /api/config when needed.
      );
    }
    throw DioException(
      requestOptions: res.requestOptions,
      response: res,
      message: 'Unexpected response: ${res.statusCode}',
    );
  }

  /// Fetches /api/config for version + components list. Used to populate
  /// the Setup success card. Optional; failures are swallowed.
  Future<Map<String, dynamic>?> getConfig() async {
    try {
      final res = await _dio.get('/api/config');
      if (res.data is Map) {
        return Map<String, dynamic>.from(res.data as Map);
      }
    } catch (_) {
      // ignore
    }
    return null;
  }

  /// Returns ALL entity states. Caller filters by domain (`switch.*`) and
  /// matching sensors (`sensor.<id>_{power,voltage,current,energy}`).
  Future<List<HaStateResponse>> listStates() async {
    final res = await _dio.get('/api/states');
    if (res.data is List) {
      return (res.data as List)
          .whereType<Map>()
          .map((m) => HaStateResponse.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    }
    return const [];
  }

  /// Fetches a single entity state.
  Future<HaStateResponse> getState(String entityId) async {
    final res = await _dio.get('/api/states/$entityId');
    return HaStateResponse.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  /// Service call helper: `POST /api/services/{domain}/{service}`.
  Future<void> callService(
    String domain,
    String service, {
    required String entityId,
  }) async {
    await _dio.post(
      '/api/services/$domain/$service',
      data: {'entity_id': entityId},
    );
  }

  Future<void> turnOn(String entityId) =>
      callService('switch', 'turn_on', entityId: entityId);

  Future<void> turnOff(String entityId) =>
      callService('switch', 'turn_off', entityId: entityId);

  void dispose() {
    _dio.close();
  }
}

/// Minimal payload returned by the Setup screen test step.
class HaInfo {
  final String message;
  const HaInfo({required this.message});
}
