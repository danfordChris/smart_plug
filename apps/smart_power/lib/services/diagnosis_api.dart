import 'package:dio/dio.dart';

import '../config/constants.dart';
import '../models/diagnosis.dart';

typedef TokenRefresher = Future<String?> Function();

/// Client for the gateway's `/diagnosis` endpoint.
class DiagnosisApi {
  DiagnosisApi({
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

  Future<Diagnosis> get(String entityId) async {
    final res = await _dio.get('/diagnosis/$entityId');
    return Diagnosis.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  void dispose() => _dio.close();
}
