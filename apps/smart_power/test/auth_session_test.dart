import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smart_power/services/auth_api.dart';
import 'package:smart_power/services/ha_api.dart';

/// Maps a request to (statusCode, body) so we can script the gateway.
typedef Responder = (int, Object) Function(RequestOptions options);

class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.responder);
  final Responder responder;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final (status, body) = responder(options);
    final text = body is String ? body : jsonEncode(body);
    return ResponseBody.fromString(
      text,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

Dio _dioWith(Responder r) => Dio()..httpClientAdapter = FakeAdapter(r);

void main() {
  group('AuthApi', () {
    test('login parses the session', () async {
      final api = AuthApi(
        baseUrl: 'http://gw.test',
        dio: _dioWith((o) => (
              200,
              {
                'access_token': 'acc',
                'refresh_token': 'ref',
                'expires_in': 1800,
                'role': 'admin',
              }
            )),
      );
      final s = await api.login(email: 'a@b.com', password: 'password123');
      expect(s.accessToken, 'acc');
      expect(s.refreshToken, 'ref');
      expect(s.role, 'admin');
    });

    test('login surfaces the server reason on 401', () async {
      final api = AuthApi(
        baseUrl: 'http://gw.test',
        dio: _dioWith((o) => (401, {'detail': 'Invalid email or password'})),
      );
      expect(
        () => api.login(email: 'a@b.com', password: 'nope12345'),
        throwsA(isA<AuthException>().having(
          (e) => e.message,
          'message',
          'Invalid email or password',
        )),
      );
    });

    test('signup returns pending status', () async {
      final api = AuthApi(
        baseUrl: 'http://gw.test',
        dio: _dioWith((o) => (
              201,
              {'id': 2, 'email': 'a@b.com', 'role': 'user', 'status': 'pending', 'message': 'waiting'}
            )),
      );
      final r = await api.signup(email: 'a@b.com', password: 'password123');
      expect(r.isActive, isFalse);
      expect(r.status, 'pending');
    });
  });

  group('HaApi 401 → refresh → retry', () {
    test('renews the token once and replays the request', () async {
      var refreshCalls = 0;
      final api = HaApi(
        baseUrl: 'http://gw.test',
        token: 'expired',
        refresher: () async {
          refreshCalls++;
          return 'fresh';
        },
        dio: _dioWith((o) {
          final auth = o.headers['Authorization'];
          if (auth == 'Bearer expired') {
            return (401, {'detail': 'token expired'});
          }
          return (
            200,
            [
              {'entity_id': 'switch.x', 'state': 'on', 'attributes': {}}
            ]
          );
        }),
      );

      final states = await api.listStates();
      expect(states, hasLength(1));
      expect(refreshCalls, 1);
    });

    test('gives up when refresh fails', () async {
      final api = HaApi(
        baseUrl: 'http://gw.test',
        token: 'expired',
        refresher: () async => null, // refresh failed → logged out
        dio: _dioWith((o) => (401, {'detail': 'token expired'})),
      );
      expect(() => api.listStates(), throwsA(isA<DioException>()));
    });
  });
}
