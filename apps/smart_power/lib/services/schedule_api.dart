import 'package:dio/dio.dart';

import '../config/constants.dart';
import '../models/schedule.dart';

/// Returns a fresh access token, or null if the session can't be renewed.
typedef TokenRefresher = Future<String?> Function();

/// Client for the gateway's `/schedules` CRUD API. Schedules run server-side,
/// so they fire even when the app is closed. Shares the same base URL + bearer
/// token + 401-refresh pattern as [HaApi].
class ScheduleApi {
  ScheduleApi({
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

  Future<List<Schedule>> list() async {
    final res = await _dio.get('/schedules');
    if (res.data is List) {
      return (res.data as List)
          .whereType<Map>()
          .map((m) => Schedule.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    }
    return const [];
  }

  Future<Schedule> create({
    required String entityId,
    required String action,
    required String timeHhmm,
    required String days,
    bool enabled = true,
    String label = '',
  }) async {
    final res = await _dio.post('/schedules', data: {
      'entity_id': entityId,
      'action': action,
      'time_hhmm': timeHhmm,
      'days': days,
      'enabled': enabled,
      'label': label,
    });
    return Schedule.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<Schedule> update(
    int id, {
    String? action,
    String? timeHhmm,
    String? days,
    bool? enabled,
    String? label,
  }) async {
    final body = <String, dynamic>{};
    if (action != null) body['action'] = action;
    if (timeHhmm != null) body['time_hhmm'] = timeHhmm;
    if (days != null) body['days'] = days;
    if (enabled != null) body['enabled'] = enabled;
    if (label != null) body['label'] = label;
    final res = await _dio.patch('/schedules/$id', data: body);
    return Schedule.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<void> delete(int id) async {
    await _dio.delete('/schedules/$id');
  }

  void dispose() => _dio.close();
}
