import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sound_drop/models/pin_model.dart';
import 'package:sound_drop/models/report_model.dart';
import 'package:sound_drop/screens/moderation_screen.dart';
import 'package:sound_drop/state/pin_provider.dart';

import 'fakes.dart';

void main() {
  testWidgets('通報が一覧表示され、ステータスを更新できる', (tester) async {
    final sink = FakeReportSink();
    final pin = PinModel(
      id: 'p1',
      authorName: 'けんた',
      ownerId: 'other',
      latitude: 38.26,
      longitude: 140.88,
      audioUrl: 'a',
      createdAt: DateTime.now(),
      visibleAt: DateTime.now().subtract(const Duration(hours: 1)),
    );
    final provider = PinProvider(
      dataSource: FakePinDataSource([pin]),
      settingsStore: FakeSettingsStore(2),
      purchaseGateway: FakePurchaseGateway(),
      authService: FakeAuthService('me'),
      reportSink: sink,
    );
    await provider.init();
    await provider.reportPin(pin, ReportReason.stalking);

    await tester.pumpWidget(
      ChangeNotifierProvider<PinProvider>.value(
        value: provider,
        child: const MaterialApp(home: ModerationScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // タイル本文に理由ラベルが出る（フィルタチップは "(件数)" 付きなので別物）。
    expect(find.text('待ち伏せ・付きまといの恐れ'), findsOneWidget);
    // 「未対応」はヘッダ・フィルタ・バッジに複数出る。
    expect(find.text('未対応'), findsWidgets);

    // メニューから却下に変更。
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('却下する'));
    await tester.pumpAndSettle();

    expect(sink.submitted.first.status, ReportStatus.dismissed);
  });

  testWidgets('件数バッジとフィルタが表示される', (tester) async {
    final sink = FakeReportSink();
    final pin = PinModel(
      id: 'p1',
      authorName: 'けんた',
      ownerId: 'other',
      latitude: 38.26,
      longitude: 140.88,
      audioUrl: 'a',
      createdAt: DateTime.now(),
      visibleAt: DateTime.now().subtract(const Duration(hours: 1)),
    );
    final provider = PinProvider(
      dataSource: FakePinDataSource([pin]),
      settingsStore: FakeSettingsStore(2),
      purchaseGateway: FakePurchaseGateway(),
      authService: FakeAuthService('me'),
      reportSink: sink,
    );
    await provider.init();
    await provider.reportPin(pin, ReportReason.spam);

    await tester.pumpWidget(
      ChangeNotifierProvider<PinProvider>.value(
        value: provider,
        child: const MaterialApp(home: ModerationScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('全 1 件'), findsOneWidget);
    expect(find.text('すべて (1)'), findsWidgets); // ステータス＆理由のフィルタ行
  });

  testWidgets('通報タイルをタップで詳細ダイアログ（位置・操作）が出る', (tester) async {
    final sink = FakeReportSink();
    final pin = PinModel(
      id: 'p1',
      authorName: 'けんた',
      ownerId: 'other',
      latitude: 38.26010,
      longitude: 140.88240,
      audioUrl: 'assets/p1.m4a',
      createdAt: DateTime.now(),
      visibleAt: DateTime.now().subtract(const Duration(hours: 1)),
    );
    final provider = PinProvider(
      dataSource: FakePinDataSource([pin]),
      settingsStore: FakeSettingsStore(2),
      purchaseGateway: FakePurchaseGateway(),
      authService: FakeAuthService('me'),
      reportSink: sink,
    );
    await provider.init();
    await provider.reportPin(pin, ReportReason.harassment);

    await tester.pumpWidget(
      ChangeNotifierProvider<PinProvider>.value(
        value: provider,
        child: const MaterialApp(home: ModerationScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();

    expect(find.textContaining('38.26010'), findsOneWidget); // 位置プレビュー
    expect(find.text('投稿を削除'), findsOneWidget);

    // 削除を実行 → ピンが消えて対応済になる。
    await tester.tap(find.text('投稿を削除'));
    await tester.pumpAndSettle();
    expect(sink.submitted.first.status, ReportStatus.actioned);
  });

  testWidgets('複数選択して一括で対応済にできる', (tester) async {
    final sink = FakeReportSink();
    final pin = PinModel(
      id: 'p1',
      authorName: 'けんた',
      ownerId: 'other',
      latitude: 38.26,
      longitude: 140.88,
      audioUrl: 'assets/p1.m4a',
      createdAt: DateTime.now(),
      visibleAt: DateTime.now().subtract(const Duration(hours: 1)),
    );
    final provider = PinProvider(
      dataSource: FakePinDataSource([pin]),
      settingsStore: FakeSettingsStore(2),
      purchaseGateway: FakePurchaseGateway(),
      authService: FakeAuthService('me'),
      reportSink: sink,
    );
    await provider.init();
    await provider.reportPin(pin, ReportReason.spam);

    await tester.pumpWidget(
      ChangeNotifierProvider<PinProvider>.value(
        value: provider,
        child: const MaterialApp(home: ModerationScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // 選択モードに入り、タイルを選択。
    await tester.tap(find.byIcon(Icons.checklist_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();

    // 一括「対応済」。
    await tester.tap(find.text('対応済'));
    await tester.pumpAndSettle();

    expect(sink.submitted.first.status, ReportStatus.actioned);
  });

  testWidgets('通報が無ければ空表示', (tester) async {
    final provider = PinProvider(
      dataSource: FakePinDataSource([]),
      settingsStore: FakeSettingsStore(2),
      purchaseGateway: FakePurchaseGateway(),
      authService: FakeAuthService('me'),
      reportSink: FakeReportSink(),
    );
    await provider.init();

    await tester.pumpWidget(
      ChangeNotifierProvider<PinProvider>.value(
        value: provider,
        child: const MaterialApp(home: ModerationScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('該当する通報はありません。'), findsOneWidget);
  });
}
