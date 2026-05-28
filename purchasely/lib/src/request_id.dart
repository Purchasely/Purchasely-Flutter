// Purchasely SDK v6 — Stable request identifier generator.
//
// Cross-platform contract uses a `requestId` for every `PresentationRequest`
// so events and lifecycle calls can be routed back from native to Dart.

import 'dart:math';

final _rand = Random.secure();

/// Returns a 128-bit hex identifier suitable for cross-isolate routing.
String nextRequestId() {
  final buf = StringBuffer('ply_');
  for (var i = 0; i < 4; i++) {
    buf.write(_rand.nextInt(0xFFFFFFFF).toRadixString(16).padLeft(8, '0'));
  }
  return buf.toString();
}
