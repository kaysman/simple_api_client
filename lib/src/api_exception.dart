/// Exception thrown when the backend returns a non-2xx response.
class ApiException implements Exception {
  /// Creates an [ApiException].
  const ApiException({
    required this.statusCode,
    required this.message,
  });

  /// HTTP status code returned by the server.
  final int statusCode;

  /// Error message from the response body.
  final String message;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
