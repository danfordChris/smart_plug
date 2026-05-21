import 'package:dio/dio.dart';

import '../config/constants.dart';
import '../models/ha_state.dart';

/// Thin client for Home Assistant's REST API.
///
/// Endpoints used (Handoff §1 / per-screen specs):
///   `GET  /api/`                                — auth + health check
///   `GET  /api/states`                          — list of all entities
///   `GET  /api/states/{entity_id}`              — single entity state
///   `POST /api/services/{domain}/{service}`     — call a service
class HaApi {
  HaApi({required this.baseUrl, required this.token, Dio? dio})
      : _dio = (dio ?? Dio())
          ..options.baseUrl = baseUrl
          ..options.connectTimeout = AppConstants.httpTimeout
          ..options.receiveTimeout = AppConstants.httpTimeout
          ..options.headers = {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          };

  final String baseUrl;
  final String token;
  final Dio _dio;

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
