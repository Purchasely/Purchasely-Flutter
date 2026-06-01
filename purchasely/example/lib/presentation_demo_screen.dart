// Demo screen for the Purchasely Flutter presentation API.
//
// Shows the canonical flow:
//   1. Initialise the SDK via `PurchaselyBuilder.apiKey(...).start()`.
//   2. Build a presentation request via `PresentationBuilder.placement(...)`.
//   3. Display it and surface the enriched 5-field `PresentationOutcome`
//      (presentation, purchaseResult, plan, closeReason, error).
//
// Interceptor registration is exposed via the `Register interceptors` button —
// see `registerInterceptors()` below. It uses the clean public API
// `Purchasely.interceptAction(kind, handler)` and demonstrates two kinds:
//   - a `navigate` interceptor that logs the outbound URL, and
//   - a `purchase` interceptor that inspects the typed `PurchasePayload`
//     (the selected plan) and returns `InterceptResult.notHandled` so the
//     SDK keeps owning the purchase flow.

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

  /// Register two typed action interceptors via the public
  /// `Purchasely.interceptAction(kind, handler)` API:
  ///
  ///   * `navigate` — logs the outbound URL from the typed [NavigatePayload].
  ///   * `purchase` — inspects the typed [PurchasePayload] (the selected
  ///     plan) and returns [InterceptResult.notHandled] so the SDK proceeds
  ///     with its own purchase flow.
  ///
  /// Both handlers downcast the generic [ActionPayload] to the concrete
  /// payload type, showing the typed-payload pattern.
  Future<void> _registerInterceptors() async {
    await Purchasely.interceptAction(
      PresentationActionKind.navigate,
      (info, payload) {
        if (payload is NavigatePayload) {
          debugPrint('Intercepted navigate to ${payload.url}');
        }
        return InterceptResult.notHandled;
      },
    );

    await Purchasely.interceptAction(
      PresentationActionKind.purchase,
      (info, payload) {
        if (payload is PurchasePayload) {
          // The typed payload exposes the selected plan (and any offer).
          final planId = payload.plan['vendorId'] ?? payload.plan['id'];
          debugPrint('Intercepted purchase of plan $planId — letting the SDK '
              'proceed (notHandled)');
        }
        // Return notHandled so the SDK keeps owning the purchase flow.
        return InterceptResult.notHandled;
      },
    );

    setState(() => _status = 'Navigate + purchase interceptors registered');
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
                    onPressed: _registerInterceptors,
                    child: const Text('Register interceptors')),
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
