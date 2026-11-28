import 'dart:math';

final _random = Random.secure();

/// 32 hex characters: within the backend's 8–64 `[A-Za-z0-9_-]`.
String newIdempotencyKey() => [
  for (var i = 0; i < 16; i++)
    _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
].join();
