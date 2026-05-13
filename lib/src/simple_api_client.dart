import 'dart:convert';
import 'dart:developer' as dev;

import 'package:http/http.dart' as http;
import 'package:simple_api_client/src/api_exception.dart';

/// {@template simple_api_client}
/// Generic HTTP client that unwraps a standard response envelope:
/// `{ "data": ..., "message": "...", "success": true }`.
///
/// The [get] and [post] methods unwrap `data` and pass it to `fromData`;
/// non-2xx responses throw an [ApiException].
///
/// Set [debug] to `true` to log every request and response via
/// `dart:developer`.
/// {@endtemplate}
class SimpleApiClient {
  /// {@macro simple_api_client}
  SimpleApiClient({
    required String baseUrl,
    this.debug = false,
    this.timeout = const Duration(seconds: 10),
    Map<String, String>? defaultHeaders,
    http.Client? httpClient,
  }) : _baseUrl = baseUrl,
       _httpClient = httpClient ?? http.Client(),
       _defaultHeaders = {
         'Content-Type': 'application/json',
         'Accept': 'application/json',
         ...?defaultHeaders,
       };

  final String _baseUrl;
  final http.Client _httpClient;
  final Map<String, String> _defaultHeaders;

  /// Per-request timeout applied to every GET / POST / multipart call.
  /// On expiry the underlying Future throws a [TimeoutException]
  /// (from `dart:async`), which implements [Exception] and is caught by
  /// callers' regular error-handling paths.
  final Duration timeout;

  /// Called whenever the server responds with 401 Unauthorized.
  /// Set this once (e.g. in your auth BLoC setup) to handle session expiry.
  void Function()? onUnauthorized;

  /// Sets the `Authorization: Bearer` header for all subsequent requests.
  void setAccessToken(String token) {
    _defaultHeaders['Authorization'] = 'Bearer $token';
  }

  /// Removes the `Authorization` header.
  void clearAccessToken() {
    _defaultHeaders.remove('Authorization');
  }

  /// When `true`, every request and response is logged via `dart:developer`.
  final bool debug;

  void _logRequest(String method, Uri uri, [Object? body]) {
    if (!debug) return;
    dev.log(
      '→ $method $uri${body != null ? '\n  body: $body' : ''}',
      name: 'SimpleApiClient',
    );
  }

  void _logResponse(http.Response res) {
    if (!debug) return;
    dev.log(
      '← ${res.statusCode} ${res.request?.url}\n  body: ${res.body}',
      name: 'SimpleApiClient',
    );
  }

  /// Issues a GET to [path] and returns the deserialized `data` field.
  Future<T> get<T>(
    String path, {
    required T Function(Object? json) fromData,
    Map<String, String>? queryParameters,
    Map<String, String>? extraHeaders,
  }) async {
    final uri = Uri.parse('$_baseUrl$path').replace(
      queryParameters: queryParameters,
    );
    _logRequest('GET', uri);
    final response = await _httpClient
        .get(
          uri,
          headers: {..._defaultHeaders, ...?extraHeaders},
        )
        .timeout(timeout);
    _logResponse(response);
    return _parse(response, fromData);
  }

  /// Issues a POST to [path] with [body] and returns the deserialized
  /// `data` field.
  Future<T> post<T>(
    String path, {
    required Object body,
    required T Function(Object? json) fromData,
    Map<String, String>? extraHeaders,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final encoded = jsonEncode(body);
    _logRequest('POST', uri, encoded);
    final response = await _httpClient
        .post(
          uri,
          headers: {..._defaultHeaders, ...?extraHeaders},
          body: encoded,
        )
        .timeout(timeout);
    _logResponse(response);
    return _parse(response, fromData);
  }

  /// Issues a multipart POST to [path] and returns the deserialized `data`
  /// field.
  ///
  /// [fields] are sent as plain form fields alongside [file].
  /// `Content-Type` is intentionally omitted from headers so that `http` can
  /// set the correct `multipart/form-data; boundary=...` value automatically.
  Future<T> postMultipart<T>(
    String path, {
    required Map<String, String> fields,
    required http.MultipartFile file,
    required T Function(Object? json) fromData,
    Map<String, String>? extraHeaders,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    _logRequest('POST (multipart)', uri, fields);
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll({
        for (final e in _defaultHeaders.entries)
          if (e.key != 'Content-Type') e.key: e.value,
        ...?extraHeaders,
      })
      ..fields.addAll(fields)
      ..files.add(file);

    final streamed = await _httpClient.send(request).timeout(timeout);
    final response = await http.Response.fromStream(streamed);
    _logResponse(response);
    return _parse(response, fromData);
  }

  T _parse<T>(http.Response response, T Function(Object? json) fromData) {
    final Map<String, dynamic> envelope;
    try {
      envelope = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Invalid response body',
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return fromData(envelope['data']);
    }

    if (response.statusCode == 401) {
      onUnauthorized?.call();
    }

    throw ApiException(
      statusCode: response.statusCode,
      message: envelope['message'] as String? ?? 'Unknown error',
    );
  }
}
