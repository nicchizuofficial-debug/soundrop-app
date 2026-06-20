import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sound_drop/models/pin_model.dart';
import 'package:sound_drop/screens/my_drops_screen.dart';
import 'package:sound_drop/state/pin_provider.dart';

import 'fakes.dart';

PinModel pin({
  required String id,
  required String ownerId,
  required DateTime visibleAt,
  String author = 'someone',
  bool unlocked = false,
}) {
  return PinModel(
    id: id,
    authorName: author,
    ownerId: ownerId,
    latitude: 38.26,
    longitude: 140.88,
    audioUrl: 'assets/$id.m4a',
    createdAt: DateTime.now(),
    visibleAt: visibleAt,
    isUnlocked: unlocked,
    isOwn: ownerId == 'me',
  );
}

Future<PinProvider> readyProvider(List<PinModel> pins) async {
  final p = PinProvider(
    dataSource: FakePinDataSource(pins),
    settingsStore: FakeSettingsStore(2),
    purchaseGateway: FakePurchaseGateway(),
    authService: FakeAuthService('me'),
    reportSink: FakeReportSink(),
  );
  await p.init();
  // testWidgets は FakeAsync のため pumpEventQueue は進まない。pump に任せる。
  await p.toggleFollow('other'); // 他人の公開ピンを表示するためフォロー
  return p;
}

/// 音声プレイヤー等の継続要素で pumpAndSettle が収束しないため固定 pump。
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> pumpScreen(WidgetTester tester, PinProvider provider) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    ChangeNotifierProvider<PinProvider>.value(
      value: provider,
      child: const MaterialApp(home: MyDropsScreen()),
    ),
  );
  await settle(tester);
}

void main() {
  final past = DateTime.now().subtract(const Duration(hours: 1));

  testWidgets('タブが表示され、マイドロップ空状態が出る', (tester) async {
    final provider = await readyProvider([
      pin(id: 'pub', ownerId: 'other', author: 'けんた', visibleAt: past),
    ]);
    await pumpScreen(tester, provider);

    expect(find.text('マイドロップ'), findsOneWidget);
    expect(find.text('公開中'), findsOneWidget);
    expect(find.textContaining('まだドロップがありません'), findsOneWidget);
  });

  testWidgets('公開中タブで他人のピンと通報/ブロックメニューが出る', (tester) async {
    final provider = await readyProvider([
      pin(id: 'pub', ownerId: 'other', author: 'けんた', visibleAt: past),
    ]);
    await pumpScreen(tester, provider);

    // 公開中タブへ切替。
    await tester.tap(find.text('公開中'));
    await settle(tester);

    expect(find.textContaining('けんた'), findsOneWidget);

    // メニューを開いて通報を選ぶ。
    await tester.tap(find.byIcon(Icons.more_vert));
    await settle(tester);
    expect(find.text('このピンを通報'), findsOneWidget);
    await tester.tap(find.text('このピンを通報'));
    await settle(tester);

    // 理由選択シートで理由を選ぶ。
    expect(find.text('通報の理由を選択'), findsOneWidget);
    await tester.tap(find.text('迷惑行為・嫌がらせ'));
    await settle(tester);

    // 通報後は一覧から消える。
    expect(find.textContaining('けんた'), findsNothing);
  });

  testWidgets('自分のドロップは削除確認ダイアログが出る', (tester) async {
    final provider = await readyProvider([
      pin(id: 'mine', ownerId: 'me', author: 'あなた', visibleAt: past, unlocked: true),
    ]);
    await pumpScreen(tester, provider);

    // マイドロップタブ（初期）に自分のピンがある。
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    await tester.tap(find.byIcon(Icons.delete_outline));
    await settle(tester);

    expect(find.text('ドロップを削除'), findsOneWidget);
    await tester.tap(find.text('削除'));
    await settle(tester);

    // 削除後は空状態。
    expect(find.textContaining('まだドロップがありません'), findsOneWidget);
  });
}
