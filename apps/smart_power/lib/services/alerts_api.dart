import 'package:dio/dio.dart';

import '../config/constants.dart';
import '../models/alert.dart';

typedef TokenRefresher = Future<String?> Function();

/// Client for the gateway's `/alerts` feed.
class AlertsApi {
  AlertsApi({
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

  Future<List<AppAlert>> list({int limit = 50}) async {
    final res = await _dio.get('/alerts', queryParameters: {'limit': limit});
    if (res.data is List) {
      return (res.data as List)
          .whereType<Map>()
          .map((m) => AppAlert.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    }
    return const [];
  }

  Future<int> unreadCount() async {
    final res = await _dio.get('/alerts/unread_count');
    if (res.data is Map) {
      return (res.data['count'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }

  Future<void> markAllRead() => _dio.post('/alerts/read');

  Future<void> clear() => _dio.delete('/alerts');

  void dispose() => _dio.close();
}
