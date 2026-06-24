// Purchasely SDK — Dart-side MethodChannel/EventChannel dispatcher.
//
// Wires the presentation façade (`lib/src/presentation*.dart`,
// `lib/src/purchasely_builder.dart`, `lib/src/action_interceptor.dart`) to the
// unified native plugin (one plugin per platform).
//
// Channel contract:
//   - MethodChannel : `purchasely`                      — calls Dart → native
//   - EventChannel  : `purchasely-presentation-events`  — events native → Dart
//
// MethodChannel verbs:
//   start, preload, display, close, back,
//   registerInterceptor, removeInterceptor, removeAllInterceptors,
//   interceptorResolve
//
// EventChannel envelopes — every event carries `event` + `requestId` keys:
//   * onLoaded            : { event, requestId, presentation?, error? }
//   * onPresented         : { event, requestId, presentation?, error? }
//   * onCloseRequested    : { event, requestId }
//   * onDismissed         : { event, requestId, outcome }
//   * interceptorTriggered: { event, requestId = invocationId, kind, info, payload }
//
// Initialisation: the singletons on `PresentationActions` /
// `PresentationRequestActions` are installed lazily the first time a
// presentation entry point is invoked (cf. [PurchaselyBridge.ensureInstalled]).

import 'dart:async';

import 'package:flutter/services.dart';

import 'action_interceptor.dart';
import 'ply_transformers.dart';
import 'presentation.dart';
import 'presentation_outcome.dart';
import 'presentation_request.dart';
import 'transition.dart';

// --- Bridge singleton ------------------------------------------------------

/// Single dispatcher that owns the MethodChannel + EventChannel and keeps
/// track of in-flight presentations, request-keyed callbacks and registered
/// interceptors. Installed lazily via [ensureInstalled].
class PurchaselyBridge {
  PurchaselyBridge._({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  })  : _method = methodChannel ?? const MethodChannel('purchasely'),
        _events = eventChannel ??
            const EventChannel('purchasely-presentation-events');

  static PurchaselyBridge? _instance;
  static bool _wired = false;

  /// Idempotent install: wires the dispatcher into [PresentationActions] and
  /// [PresentationRequestActions]. Called automatically by [_install];
  /// exposed for tests that need to inject mock channels.
  static PurchaselyBridge ensureInstalled({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  }) {
    if (_instance == null || methodChannel != null || eventChannel != null) {
      _instance?._dispose();
      _instance = PurchaselyBridge._(
        methodChannel: methodChannel,
        eventChannel: eventChannel,
      );
      _wired = false;
    }
    final bridge = _instance!;
    if (!_wired) {
      PresentationActions.instance = _BridgePresentationActions(bridge);
      PresentationRequestActions.instance =
          _BridgePresentationRequestActions(bridge);
      bridge._listenEvents();
      _wired = true;
    }
    return bridge;
  }

  /// Resets the singleton (test helper).
  static void debugReset() {
    _instance?._dispose();
    _instance = null;
    _wired = false;
    PresentationActions.instance = _uninitialisedPresentation;
    PresentationRequestActions.instance = _uninitialisedRequest;
  }

  final MethodChannel _method;
  final EventChannel _events;
  StreamSubscription<dynamic>? _eventSub;

  /// Active presentation requests keyed by requestId. Holds the live
  /// `PresentationRequest` (for callback dispatch) and the `Presentation`
  /// once preload resolves (for callbacks reassigned post-preload).
  final Map<String, _RequestEntry> _entries = <String, _RequestEntry>{};

  /// Pending interceptor handlers keyed by action wire name.
  final Map<String, ActionInterceptorHandler> _interceptors =
      <String, ActionInterceptorHandler>{};

  /// Global dismiss handler for SDK-owned presentations (campaigns,
  /// deeplinks, promoted in-app purchases).
  void Function(PLYPresentationOutcome outcome)?
      _defaultPresentationDismissHandler;

  void _listenEvents() {
    _eventSub?.cancel();
    _eventSub = _events.receiveBroadcastStream().listen(
      (dynamic raw) {
        if (raw is! Map) return;
        _dispatchEvent(raw);
      },
      onError: (_) {
        // Swallow stream errors — they are surfaced via per-call futures.
      },
    );
  }

  void _dispose() {
    _eventSub?.cancel();
    _eventSub = null;
    _entries.clear();
    _interceptors.clear();
    _defaultPresentationDismissHandler = null;
  }

  // --- MethodChannel calls -------------------------------------------------

  Future<Presentation> _preload(PresentationRequest request) async {
    _registerRequest(request);
    try {
      final raw = await _method.invokeMethod<dynamic>(
        'preload',
        _argsForRequest(request),
      );
      final loaded = _presentationFromRaw(raw, request);
      final entry = _entries[request.requestId];
      entry?.presentation = loaded;
      return loaded;
    } on PlatformException catch (e) {
      throw PresentationError(
          code: e.code, message: e.message, details: e.details);
    }
  }

  Future<PLYPresentationOutcome> _displayRequest(
    PresentationRequest request,
    Transition? transition,
  ) async {
    _registerRequest(request);
    final entry = _entries[request.requestId]!;
    // Native bridges resolve the Dart-side display Future via the onDismissed
    // event — not via the MethodChannel response. The MethodChannel `display`
    // returns immediately with `true` once the SDK accepted the display call.
    final completer = Completer<PLYPresentationOutcome>();
    entry.dismissCompleter = completer;
    try {
      await _method.invokeMethod<dynamic>(
        'display',
        <String, Object?>{
          ..._argsForRequest(request),
          if (transition != null) 'transition': transition.toMap(),
        },
      );
    } on PlatformException catch (e) {
      final err = PresentationError(
          code: e.code, message: e.message, details: e.details);
      // If the native side rejected the display synchronously, surface the
      // error on the Future *and* clear the pending dismiss completer so a
      // stray onDismissed event doesn't double-complete.
      entry.dismissCompleter = null;
      _entries.remove(request.requestId);
      if (!completer.isCompleted) {
        completer.complete(PLYPresentationOutcome(
          presentation: entry.presentation,
          error: err,
        ));
      }
    }
    return completer.future;
  }

  Future<PLYPresentationOutcome> _displayPresentation(
    Presentation presentation,
    Transition? transition,
  ) async {
    // For a presentation that originated from a preload, the request is
    // already registered. After a prior dismiss the entry was dropped by
    // `_handleOnDismissed`, so a re-display() must re-register it (keyed by the
    // same requestId) from the presentation handle — otherwise the dismiss
    // completer would have nowhere to live and the returned future would hang.
    final entry = _entries.putIfAbsent(
      presentation.requestId,
      () => _RequestEntry(null, presentation: presentation),
    );
    entry.presentation = presentation;
    final completer = Completer<PLYPresentationOutcome>();
    entry.dismissCompleter = completer;
    try {
      await _method.invokeMethod<dynamic>(
        'display',
        <String, Object?>{
          'requestId': presentation.requestId,
          if (transition != null) 'transition': transition.toMap(),
        },
      );
    } on PlatformException catch (e) {
      final err = PresentationError(
          code: e.code, message: e.message, details: e.details);
      // The native side rejected the display synchronously: clear the pending
      // dismiss completer and drop the entry so a stray onDismissed can't
      // double-complete, then surface the error on the Future.
      entry.dismissCompleter = null;
      _entries.remove(presentation.requestId);
      if (!completer.isCompleted) {
        completer.complete(PLYPresentationOutcome(
          presentation: presentation,
          error: err,
        ));
      }
    }
    return completer.future;
  }

  Future<void> _close(Presentation presentation) async {
    await _method.invokeMethod<dynamic>(
      'close',
      <String, Object?>{'requestId': presentation.requestId},
    );
  }

  Future<void> _back(Presentation presentation) async {
    await _method.invokeMethod<dynamic>(
      'back',
      <String, Object?>{'requestId': presentation.requestId},
    );
  }

  // --- Interceptor API ----------------------------------------------------

  Future<void> registerInterceptor(
    PresentationActionKind kind,
    ActionInterceptorHandler handler,
  ) async {
    _interceptors[kind.wire] = handler;
    await _method.invokeMethod<dynamic>(
      'registerInterceptor',
      <String, Object?>{'kind': kind.wire},
    );
  }

  Future<void> removeActionInterceptor(PresentationActionKind kind) async {
    _interceptors.remove(kind.wire);
    await _method.invokeMethod<dynamic>(
      'removeInterceptor',
      <String, Object?>{'kind': kind.wire},
    );
  }

  Future<void> removeAllActionInterceptors() async {
    _interceptors.clear();
    await _method.invokeMethod<dynamic>('removeAllInterceptors');
  }

  Future<void> setDefaultPresentationDismissHandler(
    void Function(PLYPresentationOutcome outcome) handler,
  ) async {
    await _method.invokeMethod<dynamic>('setDefaultPresentationDismissHandler');
    _defaultPresentationDismissHandler = handler;
  }

  Future<void> _resolveInterceptor(
      String invocationId, InterceptResult result) async {
    await _method.invokeMethod<dynamic>(
      'interceptorResolve',
      <String, Object?>{
        'invocationId': invocationId,
        'result': result.wire,
      },
    );
  }

  // --- Event dispatch ------------------------------------------------------

  void _dispatchEvent(Map<dynamic, dynamic> envelope) {
    final eventName = envelope['event'] as String?;
    final requestId = envelope['requestId'] as String?;
    if (eventName == null) return;

    switch (eventName) {
      case 'onLoaded':
        _handleOnLoaded(requestId, envelope);
        break;
      case 'onPresented':
        _handleOnPresented(requestId, envelope);
        break;
      case 'onCloseRequested':
        _handleOnCloseRequested(requestId);
        break;
      case 'onDismissed':
        _handleOnDismissed(requestId, envelope);
        break;
      case 'onDefaultPresentationDismissed':
        _handleOnDefaultPresentationDismissed(envelope);
        break;
      case 'interceptorTriggered':
        _handleInterceptorTriggered(envelope);
        break;
    }
  }

  void _handleOnLoaded(String? requestId, Map<dynamic, dynamic> envelope) {
    if (requestId == null) return;
    final entry = _entries[requestId];
    // onLoaded only fires for the preload path, where the entry still carries
    // the originating request.
    final request = entry?.request;
    if (request == null) return;
    final error = _errorFromMap(envelope['error']);
    final pMap = envelope['presentation'];
    Presentation? presentation;
    if (pMap is Map) {
      presentation = _presentationFromRaw(pMap, request);
      entry!.presentation = presentation;
    }
    if (presentation != null) {
      request.onLoaded?.call(presentation, error);
    } else if (error != null) {
      // Surface load failures via onPresented(null, error).
      request.onPresented?.call(null, error);
    }
  }

  void _handleOnPresented(String? requestId, Map<dynamic, dynamic> envelope) {
    if (requestId == null) return;
    final entry = _entries[requestId];
    if (entry == null) return;
    final pMap = envelope['presentation'];
    final request = entry.request;
    // Re-parse only when we still have the originating request (preload path);
    // on a re-display the entry has no request, so reuse the existing handle
    // which already carries the host's (possibly reassigned) callbacks.
    final presentation = (pMap is Map && request != null)
        ? _presentationFromRaw(pMap, request)
        : entry.presentation;
    if (presentation != null) {
      entry.presentation = presentation;
    }
    final error = _errorFromMap(envelope['error']);
    // Fire the presentation-level handler first (mutable, may have been reassigned),
    // then fall back to the request-level handler if the presentation didn't override.
    final handler = presentation?.onPresented ?? request?.onPresented;
    handler?.call(presentation, error);
  }

  void _handleOnCloseRequested(String? requestId) {
    if (requestId == null) return;
    final entry = _entries[requestId];
    if (entry == null) return;
    final handler =
        entry.presentation?.onCloseRequested ?? entry.request?.onCloseRequested;
    handler?.call();
  }

  void _handleOnDismissed(String? requestId, Map<dynamic, dynamic> envelope) {
    if (requestId == null) return;
    final entry = _entries[requestId];
    if (entry == null) return;
    final outcome =
        _outcomeFromMap(envelope['outcome'], fallback: entry.presentation);
    final handler =
        entry.presentation?.onDismissed ?? entry.request?.onDismissed;
    handler?.call(outcome);
    final completer = entry.dismissCompleter;
    entry.dismissCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete(outcome);
    }
    // Once dismissed, drop the entry. A subsequent re-display() re-registers
    // through `_displayPresentation`.
    _entries.remove(requestId);
  }

  void _handleOnDefaultPresentationDismissed(Map<dynamic, dynamic> envelope) {
    final handler = _defaultPresentationDismissHandler;
    if (handler == null) return;
    handler(_outcomeFromMap(envelope['outcome']));
  }

  void _handleInterceptorTriggered(Map<dynamic, dynamic> envelope) {
    final invocationId = envelope['requestId'] as String?;
    final kindWire = envelope['kind'] as String?;
    if (invocationId == null || kindWire == null) return;
    final kind = PresentationActionKindWire.fromWire(kindWire);
    if (kind == null) {
      _resolveInterceptor(invocationId, InterceptResult.notHandled);
      return;
    }
    final handler = _interceptors[kind.wire];
    if (handler == null) {
      _resolveInterceptor(invocationId, InterceptResult.notHandled);
      return;
    }
    final info = InterceptorInfo.fromMap(envelope['info'] as Map?);
    final payload = actionPayloadFromMap(kind, envelope['payload'] as Map?);
    Future<InterceptResult> run() async {
      try {
        return await Future.value(handler(info, payload));
      } catch (_) {
        return InterceptResult.failed;
      }
    }

    run().then((result) => _resolveInterceptor(invocationId, result));
  }

  // --- Helpers -------------------------------------------------------------

  Map<String, Object?> _argsForRequest(PresentationRequest request) {
    return Map<String, Object?>.from(request.toMap());
  }

  void _registerRequest(PresentationRequest request) {
    _entries.putIfAbsent(
      request.requestId,
      () => _RequestEntry(request),
    );
  }

  Presentation _presentationFromRaw(dynamic raw, PresentationRequest request) {
    final map = <dynamic, dynamic>{};
    if (raw is Map) map.addAll(raw);
    map['requestId'] = request.requestId;
    final p = Presentation.fromMap(map);
    // Seed the mutable callbacks from the originating request so the host app
    // gets a usable Presentation handle out of preload() even if it never
    // reassigns them. They can still be overridden post-preload.
    p.onPresented = request.onPresented;
    p.onCloseRequested = request.onCloseRequested;
    p.onDismissed = request.onDismissed;
    return p;
  }

  PLYPresentationOutcome _outcomeFromMap(dynamic raw,
      {Presentation? fallback}) {
    if (raw is! Map) {
      return PLYPresentationOutcome(presentation: fallback);
    }
    final pMap = raw['presentation'];
    Presentation? presentation;
    if (pMap is Map) {
      final m = <dynamic, dynamic>{}..addAll(pMap);
      m['requestId'] = fallback?.requestId ?? (pMap['requestId'] ?? '');
      presentation = Presentation.fromMap(m);
    } else {
      presentation = fallback;
    }
    // Parse the plan with the exact same transformer used for
    // PurchasePayload.plan (action_interceptor.dart) so the outcome's plan is a
    // fully-typed PLYPlan.
    final planRaw = raw['plan'];
    final plan = plyPlanFromMap(planRaw is Map ? planRaw : null);
    return PLYPresentationOutcome(
      presentation: presentation,
      purchaseResult:
          purchaseResultFromString(raw['purchaseResult'] as String?),
      plan: plan,
      closeReason: closeReasonFromString(raw['closeReason'] as String?),
      error: _errorFromMap(raw['error']),
    );
  }

  PresentationError? _errorFromMap(dynamic raw) {
    if (raw is! Map) return null;
    return PresentationError(
      code: raw['code'] as String?,
      message: raw['message'] as String?,
      details: raw['details'],
    );
  }
}

// --- Per-request bookkeeping ----------------------------------------------

class _RequestEntry {
  _RequestEntry(this.request, {this.presentation});

  /// The originating request. Null when the entry was (re-)created from a
  /// [Presentation] handle on a re-display, after the original request entry
  /// was dropped by [PurchaselyBridge._handleOnDismissed].
  final PresentationRequest? request;
  Presentation? presentation;
  Completer<PLYPresentationOutcome>? dismissCompleter;
}

// --- Action implementations -----------------------------------------------

class _BridgePresentationActions extends PresentationActions {
  _BridgePresentationActions(this._bridge);
  final PurchaselyBridge _bridge;

  @override
  Future<PLYPresentationOutcome> display(
          Presentation presentation, Transition? transition) =>
      _bridge._displayPresentation(presentation, transition);

  @override
  Future<void> close(Presentation presentation) => _bridge._close(presentation);

  @override
  Future<void> back(Presentation presentation) => _bridge._back(presentation);
}

class _BridgePresentationRequestActions extends PresentationRequestActions {
  _BridgePresentationRequestActions(this._bridge);
  final PurchaselyBridge _bridge;

  @override
  Future<Presentation> preload(PresentationRequest request) =>
      _bridge._preload(request);

  @override
  Future<PLYPresentationOutcome> display(
          PresentationRequest request, Transition? transition) =>
      _bridge._displayRequest(request, transition);
}

// --- Sentinels reused by `debugReset` -------------------------------------

final PresentationActions _uninitialisedPresentation =
    _UninitialisedPresentationActions();
final PresentationRequestActions _uninitialisedRequest =
    _UninitialisedRequestActions();

class _UninitialisedPresentationActions extends PresentationActions {
  StateError _err() => StateError(
      'Purchasely bridge not initialised — call any presentation entry point first.');
  @override
  Future<PLYPresentationOutcome> display(_, __) => throw _err();
  @override
  Future<void> close(_) => throw _err();
  @override
  Future<void> back(_) => throw _err();
}

class _UninitialisedRequestActions extends PresentationRequestActions {
  StateError _err() => StateError(
      'Purchasely bridge not initialised — call any presentation entry point first.');
  @override
  Future<Presentation> preload(_) => throw _err();
  @override
  Future<PLYPresentationOutcome> display(_, __) => throw _err();
}
