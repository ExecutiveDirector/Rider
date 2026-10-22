import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aquagas_rider/core/services/api_service.dart';
import 'package:aquagas_rider/core/services/session_refresher.dart';
import 'package:aquagas_rider/core/services/storage_service.dart';

typedef _Handler = Future<ResponseBody> Function(RequestOptions o);

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);
  final _Handler handler;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) {
    calls++;
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Map<String, dynamic> body) =>
    ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });

DioException _offline(RequestOptions o) =>
    DioException(requestOptions: o, type: DioExceptionType.connectionError);

Dio _dioWith(_FakeAdapter a) =>
    Dio(BaseOptions(baseUrl: 'http://x'))..httpClientAdapter = a;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final storage = StorageService.instance;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await storage.clearAll();
  });

  group('SessionRefresher', () {
    test('no refresh token -> rejected', () async {
      expect(await SessionRefresher.refresh(), RefreshOutcome.rejected);
    });

    test('success saves the new access AND refresh token', () async {
      await storage.saveRefreshToken('r1');
      SessionRefresher.dioFactory = () => _dioWith(
          _FakeAdapter((o) async => _json(200, {'token': 'new', 'refreshToken': 'r2'})));
      expect(await SessionRefresher.refresh(), RefreshOutcome.renewed);
      expect(await storage.getToken(), 'new');
      expect(await storage.getRefreshToken(), 'r2');
    });

    test('older backend that returns only a token still works', () async {
      await storage.saveRefreshToken('r1');
      SessionRefresher.dioFactory =
          () => _dioWith(_FakeAdapter((o) async => _json(200, {'token': 'new'})));
      expect(await SessionRefresher.refresh(), RefreshOutcome.renewed);
      expect(await storage.getRefreshToken(), 'r1');
    });

    test('server rejects the refresh token -> rejected', () async {
      await storage.saveRefreshToken('r1');
      SessionRefresher.dioFactory = () => _dioWith(
          _FakeAdapter((o) async => _json(401, {'error': 'Session has ended'})));
      expect(await SessionRefresher.refresh(), RefreshOutcome.rejected);
    });

    test('offline or server error -> unavailable, tokens kept', () async {
      await storage.saveToken('keep');
      await storage.saveRefreshToken('r1');
      SessionRefresher.dioFactory =
          () => _dioWith(_FakeAdapter((o) async => throw _offline(o)));
      expect(await SessionRefresher.refresh(), RefreshOutcome.unavailable);
      SessionRefresher.dioFactory =
          () => _dioWith(_FakeAdapter((o) async => _json(500, {'error': 'x'})));
      expect(await SessionRefresher.refresh(), RefreshOutcome.unavailable);
      expect(await storage.getToken(), 'keep');
      expect(await storage.getRefreshToken(), 'r1');
    });

    test('simultaneous callers share a single renewal', () async {
      await storage.saveRefreshToken('r1');
      final a = _FakeAdapter((o) async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return _json(200, {'token': 'new', 'refreshToken': 'r2'});
      });
      SessionRefresher.dioFactory = () => _dioWith(a);
      final results = await Future.wait(
          [SessionRefresher.refresh(), SessionRefresher.refresh(), SessionRefresher.refresh()]);
      expect(results, everyElement(RefreshOutcome.renewed));
      expect(a.calls, 1);
    });
  });

  group('ApiService 401 handling', () {
    setUpAll(() => ApiService.instance.init());

    test('renews silently and retries the original request', () async {
      await storage.saveToken('expired');
      await storage.saveRefreshToken('r1');
      SessionRefresher.dioFactory = () => _dioWith(
          _FakeAdapter((o) async => _json(200, {'token': 'fresh', 'refreshToken': 'r2'})));
      final api = _FakeAdapter((o) async => o.headers['Authorization'] == 'Bearer fresh'
          ? _json(200, {'ok': true})
          : _json(401, {'error': 'jwt expired'}));
      ApiService.instance.dioForTest.httpClientAdapter = api;

      final res = await ApiService.instance.get('/riders/orders/active');
      expect(res.statusCode, 200);
      expect(api.calls, 2);
      expect(await storage.getToken(), 'fresh');
    });

    test('being offline during renewal does NOT log the rider out', () async {
      await storage.saveToken('expired');
      await storage.saveRefreshToken('r1');
      SessionRefresher.dioFactory =
          () => _dioWith(_FakeAdapter((o) async => throw _offline(o)));
      ApiService.instance.dioForTest.httpClientAdapter =
          _FakeAdapter((o) async => _json(401, {'error': 'jwt expired'}));

      await expectLater(ApiService.instance.get('/riders/orders/active'),
          throwsA(isA<DioException>()));
      expect(await storage.getToken(), 'expired');
      expect(await storage.getRefreshToken(), 'r1');
    });

    test('a failing retry after renewal does not log the rider out', () async {
      await storage.saveToken('expired');
      await storage.saveRefreshToken('r1');
      SessionRefresher.dioFactory = () => _dioWith(
          _FakeAdapter((o) async => _json(200, {'token': 'fresh', 'refreshToken': 'r2'})));
      ApiService.instance.dioForTest.httpClientAdapter = _FakeAdapter((o) async =>
          o.headers['Authorization'] == 'Bearer fresh'
              ? _json(500, {'error': 'server down'})
              : _json(401, {'error': 'jwt expired'}));

      await expectLater(ApiService.instance.get('/riders/orders/active'),
          throwsA(isA<DioException>()));
      expect(await storage.getToken(), 'fresh');
      expect(await storage.getRefreshToken(), 'r2');
    });

    test('a wrong-password 401 on login never triggers a renewal', () async {
      await storage.saveRefreshToken('r1');
      var renewals = 0;
      SessionRefresher.dioFactory = () => _dioWith(_FakeAdapter((o) async {
            renewals++;
            return _json(200, {'token': 't'});
          }));
      ApiService.instance.dioForTest.httpClientAdapter =
          _FakeAdapter((o) async => _json(401, {'error': 'bad credentials'}));
      await expectLater(ApiService.instance.post('/riders/login', data: {}),
          throwsA(isA<DioException>()));
      expect(renewals, 0);
    });
  });
}
