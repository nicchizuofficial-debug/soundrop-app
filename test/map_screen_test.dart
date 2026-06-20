import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sound_drop/models/pin_model.dart';
import 'package:sound_drop/screens/map_screen.dart';
import 'package:sound_drop/state/pin_provider.dart';
import 'package:sound_drop/theme/app_theme.dart';
import 'package:sound_drop/widgets/map_pin.dart';

import 'fakes.dart';

/// FlutterMap の代わりに、各マーカーの child（タップ可能なピン）を縦に並べるモック。
/// MapPin（＝GestureDetectorでラップ）をタップすると実処理が発火する。
Widget mockMap(
  BuildContext context,
  List<Marker> markers,
  MapController controller,
  bool myLocationEnabled,
) {
  return ListView(children: [for (final m in markers) m.child]);
}

PinModel farLockedPin() => PinModel(
      id: 'p1',
      authorName: 'けんた',
      ownerId: 'other',
      latitude: 38.2637, // 駅から約400m（圏外）
      longitude: 140.8820,
      audioUrl: 'assets/p1.m4a',
      createdAt: DateTime.now(),
      visibleAt: DateTime.now().subtract(const Duration(hours: 1)),
    );

Future<PinProvider> readyProvider(List<PinModel> pins, {int tickets = 1}) async {
  final p = PinProvider(
    dataSource: FakePinDataSource(pins),
    settingsStore: FakeSettingsStore(tickets),
    purchaseGateway: FakePurchaseGateway(),
    authService: FakeAuthService('me'),
    reportSink: FakeReportSink(),
  );
  await p.init();
  // 注意: testWidgets は FakeAsync 環境のため pumpEventQueue() はここでは進まず
  // ハングする。ストリーム反映は pumpMap 内の tester.pump() に任せる。
  // フォロー中のみ表示されるので、対象投稿者をフォローしておく。
  await p.toggleFollow('other');
  // 駅前に現在地をセット（p1 からは圏外）。
  p.setLocationForTest(38.2601, 140.8824);
  return p;
}

/// MapScreen には常駐する継続スケジュール要素があり pumpAndSettle が
/// 収束しない（テスト環境）。固定時間 pump で進める。
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> pumpMap(WidgetTester tester, PinProvider provider) async {
  // 既定のテスト画面(800x600)はボトムシートが収まらず overflow するため、
  // スマホ相当の縦長サーフェスにする。
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    ChangeNotifierProvider<PinProvider>.value(
      value: provider,
      child: MaterialApp(
        theme: buildAppTheme(),
        home: const MapScreen(mapViewBuilder: mockMap),
      ),
    ),
  );
  await settle(tester);
}

void main() {
  testWidgets('遠いピンをタップするとワープ/歩くの選択シートが出る', (tester) async {
    final provider = await readyProvider([farLockedPin()]);
    await pumpMap(tester, provider);

    await tester.tap(find.byType(MapPin));
    await settle(tester);

    expect(find.text('🔒 鍵がかかっています').evaluate().isNotEmpty ||
        find.textContaining('鍵がかかっています').evaluate().isNotEmpty, isTrue);
    expect(find.textContaining('歩いて近づく'), findsOneWidget);
    expect(find.textContaining('ワープチケット'), findsOneWidget);
  });

  testWidgets('ワープで解禁すると再生シートになりチケットが減る', (tester) async {
    final provider = await readyProvider([farLockedPin()], tickets: 1);
    await pumpMap(tester, provider);

    expect(find.text('1'), findsOneWidget); // AppBar のチケット数

    await tester.tap(find.byType(MapPin));
    await settle(tester);
    await tester.tap(find.textContaining('ワープチケット'));
    await settle(tester);

    // 解禁後シート：応援ボタンが出る。
    expect(find.textContaining('応援を贈る'), findsOneWidget);
    expect(provider.warpTickets, 0);
  });

  testWidgets('通報すると理由選択シートが出てピンが消える', (tester) async {
    final provider = await readyProvider([farLockedPin()]);
    // すでに解禁済みにして再生シート経路に入れる。
    provider.unlockByWarpTicket('p1');
    await pumpMap(tester, provider);

    await tester.tap(find.byType(MapPin));
    await settle(tester);

    // 解禁シートの通報メニュー。
    await tester.tap(find.byIcon(Icons.more_vert));
    await settle(tester);
    await tester.tap(find.text('このピンを通報'));
    await settle(tester);

    // 理由選択シート。
    expect(find.text('通報の理由を選択'), findsOneWidget);
    await tester.tap(find.text('待ち伏せ・付きまといの恐れ'));
    await settle(tester);

    // マーカーが消える（通報で非表示）。
    expect(find.byType(MapPin), findsNothing);
  });
}
