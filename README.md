# simple_api_client

[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]
[![License: MIT][license_badge]][license_link]

> I kept rewriting the same HTTP envelope plumbing for every Flutter app
> I built, so I extracted it into a package. Open-sourcing it in case
> someone else finds it useful.

A small HTTP client built on top of `package:http` that unwraps a standard
response envelope:

```json
{ "data": ..., "message": "...", "success": true }
```

`get`, `post`, and `postMultipart` return the unwrapped `data`. Non-2xx
responses throw `ApiException`. A 401 response triggers the optional
`onUnauthorized` callback so the host app can drive a token refresh or
sign-out flow.

## Usage

```dart
import 'package:simple_api_client/simple_api_client.dart';

final client = SimpleApiClient(
  baseUrl: 'https://api.example.com',
  debug: true,
);

final user = await client.get<Map<String, dynamic>>(
  '/users/me',
  fromData: (json) => json! as Map<String, dynamic>,
);
```

Pass your own `http.Client` to the constructor to inject a mock in tests or
a custom adapter (logging, retry, etc.) in production.

## Tests

```sh
flutter test
```

[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis
