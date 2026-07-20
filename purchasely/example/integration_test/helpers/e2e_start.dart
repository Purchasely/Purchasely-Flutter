// Shared "start the SDK with retry" helper for integration_test/ suites.
//
// CI runners occasionally hit a transient network/TLS hiccup during
// Purchasely.start() (observed: "A TLS error caused the secure connection to
// fail", start() failing 3/3 on a cold-start deeplink run) that has nothing to
// do with the SDK or the suite's own setup. Retrying blindly would mask real
// regressions, so only failures that LOOK like network/TLS errors get
// retried — everything else rethrows immediately.
//
// Each suite keeps its own `Purchasely.apiKey(...)....start()` chain (with
// whatever storekitVersion / allowDeeplink / stores / per-attempt
// `.timeout(...)` it already had); wrap that chain in a closure and pass it
// here instead of awaiting it directly:
//
//   setUpAll(() async {
//     final configured = await startWithRetry(() => Purchasely.apiKey(kApiKey)
//         .runningMode(PLYRunningMode.full)
//         .logLevel(PLYLogLevel.debug)
//         .storekitVersion(PLYStorekitVersion.storeKit2)
//         .start()
//         .timeout(const Duration(seconds: 120),
//             onTimeout: () =>
//                 throw StateError('Purchasely.start() timed out after 120s')));
//     expect(configured, isTrue);
//   });

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Total attempts: the initial call + 2 retries.
const int _kMaxAttempts = 3;

/// Backoff before retry N — index 0 is the delay before attempt 2, index 1
/// before attempt 3.
const List<Duration> _kBackoff = [Duration(seconds: 2), Duration(seconds: 4)];

/// Case-insensitive substrings that mark an error as network/TLS-ish.
const List<String> _kNetworkNeedles = [
  'tls',
  'ssl',
  'handshake',
  'socket',
  'network',
  'connection',
  'timed out',
];

/// Runs the caller-provided `Purchasely.start()` chain [start], retrying up
/// to [_kMaxAttempts] times with a (2s, 4s) backoff — but ONLY when the
/// failure looks like a transient network/TLS error. Any other error
/// rethrows immediately, on the first attempt.
Future<bool> startWithRetry(Future<bool> Function() start) async {
  for (var attempt = 1; attempt <= _kMaxAttempts; attempt++) {
    try {
      return await start();
    } catch (e) {
      final motif = _networkMotif(e);
      if (motif == null || attempt == _kMaxAttempts) rethrow;
      final delay = _kBackoff[attempt - 1];
      // ignore: avoid_print
      print('startWithRetry: attempt $attempt/$_kMaxAttempts failed with a '
          'network-ish error (motif="$motif"): $e — retrying in '
          '${delay.inSeconds}s…');
      await Future<void>.delayed(delay);
    }
  }
  // Unreachable: the loop above always returns or rethrows.
  throw StateError('startWithRetry: exhausted attempts without a result');
}

/// Returns the matched keyword if [error] looks like a transient
/// network/TLS failure, or `null` if it should fail the suite immediately.
String? _networkMotif(Object error) {
  final message = _messageOf(error).toLowerCase();
  for (final needle in _kNetworkNeedles) {
    if (message.contains(needle)) return needle;
  }
  return null;
}

String _messageOf(Object error) {
  if (error is SocketException) return error.message;
  if (error is PlatformException) return error.message ?? error.toString();
  if (error is TimeoutException) return error.message ?? error.toString();
  return error.toString();
}
