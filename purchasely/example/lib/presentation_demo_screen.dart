// Demo screen for the Purchasely Flutter presentation API.
//
// Shows the canonical flow:
//   1. Initialise the SDK via `PurchaselyBuilder.apiKey(...).start()`.
//   2. Build a presentation request via `PresentationBuilder.placement(...)`.
//   3. Display it and surface the enriched 5-field `PresentationOutcome`
//      (presentation, purchaseResult, plan, closeReason, error).
//
// Interceptor registration is exposed via the `Register interceptor` button —
// see `registerNavigateInterceptor()` below. It forwards to the native side
// through the bridge's `registerInterceptor` channel call.

import 'package:flutter/material.dart';
import 'package:purchasely_flutter/purchasely_flutter.dart';

class PresentationDemoScreen extends StatefulWidget {
  const PresentationDemoScreen({Key? key}) : super(key: key);

  @override
  State<PresentationDemoScreen> createState() => _PresentationDemoScreenState();
}

class _PresentationDemoScreenState extends State<PresentationDemoScreen> {
  String _status = 'Tap "Start SDK" to begin.';
  PresentationOutcome? _lastOutcome;
  PresentationError? _lastError;

  Future<void> _startSdk() async {
    setState(() => _status = 'Starting…');
    try {
      final ok = await PurchaselyBuilder.apiKey(
        'fcb39be4-2ba4-4db7-bde3-2a5a1e20745d',
      )
          .runningMode(RunningMode.observer)
          .logLevel(LogLevel.debug)
          .stores([PLYStore.google]).start();
      setState(() => _status = 'Started: $ok');
    } catch (e) {
      setState(() => _status = 'Start failed: $e');
    }
  }

  Future<void> _displayPresentation() async {
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
                'onLoaded — screenId=${presentation.screenId} error=$error');
          })
          .onPresented((presentation, error) {
            debugPrint('onPresented — error=$error');
          })
          .onCloseRequested(() {
            debugPrint('onCloseRequested');
          })
          .onDismissed((o) {
            debugPrint('onDismissed — outcome=$o');
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
  /// outbound URL.
  Future<void> _registerNavigateInterceptor() async {
    await PurchaselyBridge.ensureInstalled().registerInterceptor(
      PresentationActionKind.navigate,
      (info, payload) {
        if (payload is NavigatePayload) {
          debugPrint('Intercepted navigate to ${payload.url}');
        }
        return InterceptResult.notHandled;
      },
    );
    setState(() => _status = 'Navigate interceptor registered');
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
      appBar: AppBar(title: const Text('Purchasely presentation demo')),
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
                    onPressed: _startSdk, child: const Text('Start SDK')),
                ElevatedButton(
                    onPressed: _displayPresentation,
                    child: const Text('Display presentation')),
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
