// Demo screen for the Purchasely Flutter v6 API.
//
// Shows the canonical v6 flow:
//   1. Initialise the SDK via `PurchaselyBuilder.apiKey(...).start()`.
//   2. Build a presentation request via `PresentationBuilder.placement(...)`.
//   3. Display it and surface the enriched 5-field `PresentationOutcome`
//      (presentation, purchaseResult, plan, closeReason, error).
//
// Interceptor registration is exposed via the `Register interceptor` button
// — see `registerNavigateInterceptor()` below. The Dart-side bridge wiring
// for interceptors is documented in `lib/src/action_interceptor.dart` and
// forwarded to the native bridges via the `v6/registerInterceptor` channel
// call. (The Dart-side bridge dispatcher lives in a separate file and is
// added as the façade is wired end-to-end.)

import 'package:flutter/material.dart';
import 'package:purchasely_flutter/purchasely_flutter.dart';

class V6DemoScreen extends StatefulWidget {
  const V6DemoScreen({Key? key}) : super(key: key);

  @override
  State<V6DemoScreen> createState() => _V6DemoScreenState();
}

class _V6DemoScreenState extends State<V6DemoScreen> {
  String _status = 'Tap "Start v6 SDK" to begin.';
  PresentationOutcome? _lastOutcome;
  PresentationError? _lastError;

  Future<void> _startSdk() async {
    setState(() => _status = 'Starting…');
    try {
      final ok = await PurchaselyBuilder.apiKey(
        'fcb39be4-2ba4-4db7-bde3-2a5a1e20745d',
      )
          .runningMode(V6RunningMode.observer)
          .logLevel(V6LogLevel.debug)
          .stores([PLYStore.google]).start();
      setState(() => _status = 'Started: $ok');
    } catch (e) {
      setState(() => _status = 'Start failed: $e');
    }
  }

  Future<void> _displayPaywall() async {
    setState(() {
      _status = 'Displaying…';
      _lastOutcome = null;
      _lastError = null;
    });

    try {
      final outcome = await PresentationBuilder.placement('onboarding')
          .contentId('demo-content-42')
          .onLoaded((presentation, error) {
            debugPrint(
                'v6 onLoaded — screenId=${presentation.screenId} error=$error');
          })
          .onPresented((presentation, error) {
            debugPrint('v6 onPresented — error=$error');
          })
          .onCloseRequested(() {
            debugPrint('v6 onCloseRequested');
          })
          .onDismissed((o) {
            debugPrint('v6 onDismissed — outcome=$o');
          })
          .build()
          .display(const Transition.modal());

      setState(() {
        _lastOutcome = outcome;
        _status = 'Dismissed.';
      });
    } on PresentationError catch (e) {
      setState(() {
        _lastError = e;
        _status = 'Display failed.';
      });
    } catch (e) {
      setState(() => _status = 'Display crashed: $e');
    }
  }

  /// Register a typed `navigate` action interceptor that just logs the
  /// outbound URL and lets the SDK proceed. The interceptor is wired through
  /// the v6 bridge via the `v6/registerInterceptor` channel call.
  Future<void> _registerNavigateInterceptor() async {
    try {
      await PurchaselyV6Bridge.ensureInstalled().registerInterceptor(
        PresentationActionKind.navigate,
        (InterceptorInfo info, ActionPayload? payload) {
          if (payload is NavigatePayload) {
            debugPrint('v6 navigate interceptor — url=${payload.url} '
                'title=${payload.title} contentId=${info.contentId}');
          }
          // Let the SDK continue handling the navigation.
          return InterceptResult.notHandled;
        },
      );
      setState(() => _status = 'Navigate interceptor registered.');
    } catch (e) {
      setState(() => _status = 'Interceptor registration failed: $e');
    }
  }

  Widget _outcomeCard(PresentationOutcome outcome) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Outcome (5 fields)',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('presentation.screenId: ${outcome.presentation?.screenId}'),
            Text('purchaseResult: ${outcome.purchaseResult}'),
            Text('plan: ${outcome.plan}'),
            Text('closeReason: ${outcome.closeReason}'),
            Text('error: ${outcome.error}'),
          ],
        ),
      ),
    );
  }

  Widget _errorCard(PresentationError error) {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('PresentationError',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('code: ${error.code}'),
            Text('message: ${error.message}'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Purchasely v6 demo')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                    onPressed: _startSdk, child: const Text('Start v6 SDK')),
                ElevatedButton(
                    onPressed: _displayPaywall,
                    child: const Text('Display paywall')),
                ElevatedButton(
                    onPressed: _registerNavigateInterceptor,
                    child: const Text('Register interceptor')),
              ],
            ),
            const SizedBox(height: 16),
            Text(_status, style: const TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 16),
            if (_lastOutcome != null) _outcomeCard(_lastOutcome!),
            if (_lastError != null) _errorCard(_lastError!),
          ],
        ),
      ),
    );
  }
}
