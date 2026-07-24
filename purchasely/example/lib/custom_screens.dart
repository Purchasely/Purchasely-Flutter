import 'package:flutter/material.dart';
import 'package:purchasely_flutter/purchasely_flutter.dart';

class CustomScreenStep extends StatelessWidget {
  const CustomScreenStep({Key? key, required this.presentation})
      : super(key: key);

  final PLYCustomScreenPresentation presentation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffeef2ff),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Flutter BYOS screen',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text('placementId: byos'),
              Text('screenId: ${presentation.screenId ?? "—"}'),
              Text('flowId: ${presentation.flowId ?? "—"}'),
              Text(
                'connections: ${presentation.connections.map((item) => item.id).join(", ")}',
              ),
              if (presentation.metadata.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('metadata: ${presentation.metadata}'),
              ],
              const Spacer(),
              for (final connection in presentation.connections) ...[
                FilledButton(
                  onPressed: () => presentation.execute(connection),
                  child: Text(connection.id ?? '(default)'),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
