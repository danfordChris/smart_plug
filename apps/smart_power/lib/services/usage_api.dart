import 'package:dio/dio.dart';

import '../config/constants.dart';
import '../models/usage.dart';

typedef TokenRefresher = Future<String?> Function();

/// Client for the gateway's `/usage` aggregation endpoint.
class UsageApi {
  UsageApi({
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

  /// Aggregate usage across all the user's plugs for [period].
  Future<UsageSeries> fetch(UsagePeriod period, {String? entityId}) async {
    final path = entityId == null ? '/usage' : '/usage/$entityId';
    final res = await _dio.get(path, queryParameters: {'period': period.apiName});
    return UsageSeries.fromJson(Map<String, dynamic>.from(res.data as Map), period);
  }

  void dispose() => _dio.close();
}
