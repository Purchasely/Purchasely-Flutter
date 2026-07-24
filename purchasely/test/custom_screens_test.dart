import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchasely_flutter/purchasely_flutter.dart';
// PurchaselyBridge (debugReset) is a test-only entry point — not exported publicly.
import 'package:purchasely_flutter/src/bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const mainChannel = MethodChannel('purchasely');
  const customChannel = MethodChannel('purchasely-custom-screen');
  late TestDefaultBinaryMessenger messenger;
  late List<MethodCall> mainCalls;
  late List<MethodCall> customCalls;

  setUp(() {
    messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    mainCalls = <MethodCall>[];
    customCalls = <MethodCall>[];
    messenger.setMockMethodCallHandler(mainChannel, (call) async {
      mainCalls.add(call);
      return true;
    });
    messenger.setMockMethodCallHandler(customChannel, (call) async {
      customCalls.add(call);
      return true;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(mainChannel, null);
    messenger.setMockMethodCallHandler(customChannel, null);
    PurchaselyBridge.debugReset();
  });

  test('registration forwards entrypoint configuration and removal', () async {
    await Purchasely.setCustomScreenProvider(
      entrypoint: 'customEntry',
      libraryUri: 'package:example/custom.dart',
    );
    await Purchasely.removeCustomScreenProvider();

    expect(mainCalls[0].method, 'setCustomScreenProvider');
    expect(mainCalls[0].arguments, <String, Object?>{
      'entrypoint': 'customEntry',
      'libraryUri': 'package:example/custom.dart',
    });
    expect(mainCalls[1].method, 'removeCustomScreenProvider');
  });

  test('presentation round trip preserves connections and metadata', () {
    final presentation = PLYPresentation.fromMap(<String, Object?>{
      'requestId': 'request-1',
      'screenId': 'custom-step',
      'type': 3,
      'metadata': <String, Object?>{'headline': 'Welcome', 'count': 2},
      'connections': <Map<String, Object?>>[
        <String, Object?>{'id': 'next', 'isDefault': true},
        <String, Object?>{'id': 'skip', 'isDefault': false},
      ],
    });

    expect(presentation.type, PLYPresentationType.client);
    expect(presentation.metadata['headline'], 'Welcome');
    expect(presentation.connections, hasLength(2));
    expect(presentation.connections.first.id, 'next');
    expect(presentation.connections.first.isDefault, isTrue);

    final reparsed = PLYPresentation.fromMap(presentation.toMap());
    expect(reparsed.connections.first.id, 'next');
    expect(reparsed.connections.first.isDefault, isTrue);
    expect(reparsed.metadata['count'], 2);
  });

  test('custom presentation routes exact id for execute back and close',
      () async {
    final presentation = PLYCustomScreenPresentation.fromMap(
      <String, Object?>{
        'customScreenId': 'ply_cs_7',
        'screenId': 'custom-step',
        'type': 3,
        'connections': <Map<String, Object?>>[
          <String, Object?>{'id': 'next', 'isDefault': true},
        ],
      },
    );

    await presentation.execute(presentation.connections.single);
    await presentation.execute();
    await presentation.back();
    await presentation.close();

    expect(customCalls.map((call) => call.method), <String>[
      'customScreenExecuteConnection',
      'customScreenExecuteConnection',
      'customScreenBack',
      'customScreenClose',
    ]);
    expect(customCalls[0].arguments, <String, Object?>{
      'customScreenId': 'ply_cs_7',
      'connectionId': 'next',
    });
    expect(customCalls[1].arguments, <String, Object?>{
      'customScreenId': 'ply_cs_7',
      'connectionId': null,
    });
  });

  test('custom presentation rejects payload without scoped native id', () {
    expect(
      () => PLYCustomScreenPresentation.fromMap(
        <String, Object?>{'screenId': 'custom-step'},
      ),
      throwsFormatException,
    );
  });
}
