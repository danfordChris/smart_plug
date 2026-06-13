import 'package:dio/dio.dart';

import '../config/constants.dart';
import '../models/device_config.dart';

typedef TokenRefresher = Future<String?> Function();

/// Client for the gateway's `/device-config` API (rename/type + auto-off).
class DeviceConfigApi {
  DeviceConfigApi({
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

  Future<void> _onAuthError(DioException err, ErrorInterceptorHandler handler) async {
    final opts = err.requestOptions;
    if (err.response?.statusCode == 401 &&
        refresher != null &&
        opts.extra['retried'] != true) {
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

  Future<List<DeviceConfig>> list() async {
    final res = await _dio.get('/device-config');
    if (res.data is List) {
      return (res.data as List)
          .whereType<Map>()
          .map((m) => DeviceConfig.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    }
    return const [];
  }

  Future<DeviceConfig> get(String entityId) async {
    final res = await _dio.get('/device-config/$entityId');
    return DeviceConfig.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<DeviceConfig> update(
    String entityId, {
    String? displayName,
    String? applianceType,
    bool? autoOffEnabled,
    int? autoOffIdleMinutes,
    double? autoOffThresholdW,
    String? powerEntityId,
    bool? alertsEnabled,
  }) async {
    final body = <String, dynamic>{};
    if (displayName != null) body['display_name'] = displayName;
    if (applianceType != null) body['appliance_type'] = applianceType;
    if (autoOffEnabled != null) body['auto_off_enabled'] = autoOffEnabled;
    if (autoOffIdleMinutes != null) body['auto_off_idle_minutes'] = autoOffIdleMinutes;
    if (autoOffThresholdW != null) body['auto_off_threshold_w'] = autoOffThresholdW;
    if (powerEntityId != null) body['power_entity_id'] = powerEntityId;
    if (alertsEnabled != null) body['alerts_enabled'] = alertsEnabled;
    final res = await _dio.put('/device-config/$entityId', data: body);
    return DeviceConfig.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  void dispose() => _dio.close();
}
