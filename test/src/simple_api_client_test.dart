import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:simple_api_client/simple_api_client.dart';

class _MockHttpClient extends Mock implements http.Client {}

void main() {
  group('SimpleApiClient', () {
    late _MockHttpClient httpClient;
    late SimpleApiClient apiClient;

    setUp(() {
      httpClient = _MockHttpClient();
      apiClient = SimpleApiClient(
        baseUrl: 'http://test.local',
        httpClient: httpClient,
      );
    });

    group('get', () {
      test('returns deserialized data on 200', () async {
        when(
          () => httpClient.get(
            Uri.parse('http://test.local/declaration?barcode=ABC'),
            headers: any(named: 'headers'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({
              'data': {'id': 1},
              'message': 'ok',
              'success': true,
            }),
            200,
          ),
        );

        final result = await apiClient.get<Map<String, dynamic>>(
          '/declaration',
          queryParameters: {'barcode': 'ABC'},
          fromData: (json) => json! as Map<String, dynamic>,
        );

        expect(result, equals({'id': 1}));
      });

      test('throws ApiException on 400', () async {
        when(
          () => httpClient.get(
            Uri.parse('http://test.local/declaration?barcode=BAD'),
            headers: any(named: 'headers'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({
              'data': 'invalid barcode',
              'message': 'Barcode not found',
              'success': false,
            }),
            400,
          ),
        );

        expect(
          () => apiClient.get<void>(
            '/declaration',
            queryParameters: {'barcode': 'BAD'},
            fromData: (_) {},
          ),
          throwsA(
            isA<ApiException>()
                .having((e) => e.statusCode, 'statusCode', 400)
                .having((e) => e.message, 'message', 'Barcode not found'),
          ),
        );
      });

      test('throws ApiException on invalid JSON', () async {
        when(
          () => httpClient.get(
            Uri.parse('http://test.local/ping'),
            headers: any(named: 'headers'),
          ),
        ).thenAnswer((_) async => http.Response('not json', 200));

        expect(
          () => apiClient.get<void>(
            '/ping',
            fromData: (_) {},
          ),
          throwsA(isA<ApiException>()),
        );
      });
    });

    group('post', () {
      test('returns deserialized data on 200', () async {
        when(
          () => httpClient.post(
            Uri.parse('http://test.local/declaration/confirm'),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({
              'data': {'success': true},
              'message': 'confirmed',
              'success': true,
            }),
            200,
          ),
        );

        final result = await apiClient.post<bool>(
          '/declaration/confirm',
          body: {'barcode': 'ABC', 'type': 'ASYCUDA_INFO_CONFIRM'},
          fromData: (json) {
            if (json is Map<String, dynamic>) {
              return json['success'] as bool? ?? false;
            }
            return false;
          },
        );

        expect(result, isTrue);
      });

      test('throws ApiException on 500', () async {
        when(
          () => httpClient.post(
            Uri.parse('http://test.local/declaration/confirm'),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({
              'data': 'server error',
              'message': 'Internal Server Error',
              'success': false,
            }),
            500,
          ),
        );

        expect(
          () => apiClient.post<void>(
            '/declaration/confirm',
            body: {'barcode': 'ABC', 'type': 'ASYCUDA_INFO_CONFIRM'},
            fromData: (_) {},
          ),
          throwsA(
            isA<ApiException>()
                .having((e) => e.statusCode, 'statusCode', 500),
          ),
        );
      });
    });
  });
}
