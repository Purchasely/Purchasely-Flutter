// Purchasely Flutter example app — v6 API.
//
// Demonstrates the canonical v6 flow:
//   1. Initialise the SDK via `PurchaselyBuilder.apiKey(...).start()`.
//   2. Showcase a few "kept-v5" helpers that still live on the static
//      `Purchasely` class (user login, a user attribute, restore).
//   3. Navigate to `V6DemoScreen` to display a paywall via
//      `PresentationBuilder` and register a v6 action interceptor.

import 'package:flutter/material.dart';

import 'package:purchasely_flutter/purchasely_flutter.dart';

import 'v6_demo_screen.dart';

/// Placeholder API key — replace with your own from the Purchasely console.
const String _apiKey = 'fcb39be4-2ba4-4db7-bde3-2a5a1e20745d';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  String _status = 'Initialising…';

  @override
  void initState() {
    super.initState();
    initPurchaselySdk();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPurchaselySdk() async {
    try {
      // v6 initialisation via the fluent builder.
      final bool configured = await PurchaselyBuilder.apiKey(_apiKey)
          .runningMode(V6RunningMode.full)
          .logLevel(V6LogLevel.debug)
          .stores([PLYStore.google]).start();

      if (!configured) {
        _setStatus('Purchasely SDK not configured');
        return;
      }

      // Kept-v5 helpers — these still live on the static `Purchasely` class
      // and remain usable after a v6 init.
      await Purchasely.userLogin('MY_USER_ID');
      await Purchasely.setUserAttributeWithString('favorite_color', 'blue');
      await Purchasely.setLanguage('en');

      _setStatus('SDK ready (configured: $configured).');
    } catch (e) {
      _setStatus('Init failed: $e');
    }
  }

  void _setStatus(String value) {
    if (!mounted) return;
    setState(() => _status = value);
  }

  Future<void> restoreAllProducts() async {
    _setStatus('Restoring purchases…');
    try {
      final bool restored = await Purchasely.restoreAllProducts();
      _setStatus('Restore complete (restored: $restored).');
    } catch (e) {
      _setStatus('Restore failed: $e');
    }
  }

  void _openV6Demo() {
    navigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (_) => const V6DemoScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      home: Scaffold(
        appBar: AppBar(title: const Text('Purchasely Flutter Sample')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                ),
                onPressed: _openV6Demo,
                child: const Text('Open v6 demo'),
              ),
              ElevatedButton(
                onPressed: restoreAllProducts,
                child: const Text('Restore purchases'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
