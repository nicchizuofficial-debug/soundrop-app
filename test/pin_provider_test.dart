import 'package:flutter_test/flutter_test.dart';
import 'package:sound_drop/models/pin_model.dart';
import 'package:sound_drop/models/privacy_settings.dart';
import 'package:sound_drop/models/report_model.dart';
import 'package:sound_drop/state/pin_provider.dart';

import 'fakes.dart';

// FakeAuthService の既定 uid。自分の投稿はこの ownerId にする。
const kMyUid = 'test-uid';

PinModel buildPin({
  required String id,
  required DateTime visibleAt,
  bool isOwn = false,
  bool isUnlocked = false,
  String owner = 'someone',
  double lat = 38.2601,
  double lng = 140.8824,
}) {
  return PinModel(
    id: id,
    authorName: isOwn ? 'あなた' : owner,
    ownerId: isOwn ? kMyUid : owner,
    latitude: lat,
    longitude: lng,
    audioUrl: 'assets/audio/$id.m4a',
    createdAt: DateTime.now(),
    visibleAt: visibleAt,
    isOwn: isOwn,
    isUnlocked: isUnlocked,
  );
}

/// 初期化してストリームの初回 emit を待つヘルパー。
Future<PinProvider> makeProvider({
  required List<PinModel> pins,
  int tickets = 2,
  bool storeAvailable = false,
}) async {
  final provider = PinProvider(
    dataSource: FakePinDataSource(pins),
    settingsStore: FakeSettingsStore(tickets),
    purchaseGateway: FakePurchaseGateway(storeAvailable: storeAvailable),
    authService: FakeAuthService(),
    reportSink: FakeReportSink(),
    accountDirectory: FakeAccountDirectory(),
  );
  await provider.init();
  await pumpEventQueue();
  return provider;
}

void main() {
  final now = DateTime.now();
  final past = now.subtract(const Duration(hours: 1));
  final future = now.add(const Duration(hours: 3));

  test('init 後に永続データが読み込まれ isLoaded になる', () async {
    final provider = await makeProvider(
      pins: [buildPin(id: 'a', visibleAt: past)],
      tickets: 5,
    );
    expect(provider.isLoaded, isTrue);
    expect(provider.warpTickets, 5);
    expect(provider.allPins.length, 1);
  });

  test('visiblePins はフォロー中の公開済み＋自分の投稿のみ', () async {
    final provider = await makeProvider(pins: [
      buildPin(id: 'published', visibleAt: past, owner: 'a'),
      buildPin(id: 'locked_other', visibleAt: future, owner: 'a'),
      buildPin(id: 'pending_own', visibleAt: future, isOwn: true),
      buildPin(id: 'not_followed', visibleAt: past, owner: 'z'),
    ]);
    await provider.toggleFollow('a'); // a だけフォロー

    final ids = provider.visiblePins.map((p) => p.id).toSet();
    // a の公開済み + 自分の公開待ち。未フォロー(z)・未公開(a)は除外。
    expect(ids, {'published', 'pending_own'});
  });

  test('フォローしていないアカウントのドロップは表示されない', () async {
    final provider = await makeProvider(
        pins: [buildPin(id: 'x', visibleAt: past, owner: 'stranger')]);
    expect(provider.visiblePins, isEmpty);
    await provider.toggleFollow('stranger');
    expect(provider.visiblePins.map((p) => p.id), contains('x'));
  });

  group('ドロップ', () {
    test('現在地が無いと null を返す', () async {
      final provider = await makeProvider(pins: []);
      final pin = provider.dropPin(
        audioPath: '/tmp/a.m4a',
        title: 't',
        lockDuration: const Duration(hours: 3),
      );
      expect(pin, isNull);
    });

    test('現在地があればドロップでき myPins に入る', () async {
      final provider = await makeProvider(pins: []);
      provider.setLocationForTest(38.2601, 140.8824);

      final pin = provider.dropPin(
        audioPath: '/tmp/a.m4a',
        title: 'テスト',
        lockDuration: const Duration(hours: 3),
      );

      expect(pin, isNotNull);
      expect(pin!.isOwn, isTrue);
      expect(pin.isUnlocked, isTrue);
      expect(provider.myPins.map((p) => p.id), contains(pin.id));
    });
  });

  group('距離・解禁判定', () {
    test('50m圏内は解禁範囲内、遠方は範囲外', () async {
      final pin = buildPin(id: 'x', visibleAt: past);
      final provider = await makeProvider(pins: [pin]);

      // 約30m北 → 圏内
      provider.setLocationForTest(38.26037, 140.8824);
      expect(provider.isWithinUnlockRange(pin), isTrue);

      // 約400m北 → 圏外
      provider.setLocationForTest(38.2637, 140.8820);
      expect(provider.isWithinUnlockRange(pin), isFalse);
    });

    test('現在地未設定では距離 null・解禁不可', () async {
      final pin = buildPin(id: 'x', visibleAt: past);
      final provider = await makeProvider(pins: [pin]);
      expect(provider.distanceToPin(pin), isNull);
      expect(provider.canPlay(pin), isFalse);
    });
  });

  group('ワープチケット', () {
    test('消費で解禁し、枚数が減る', () async {
      final pin = buildPin(id: 'x', visibleAt: past);
      final provider = await makeProvider(pins: [pin], tickets: 1);

      final ok = provider.unlockByWarpTicket('x');
      expect(ok, isTrue);
      expect(provider.warpTickets, 0);

      final unlocked = provider.allPins.firstWhere((p) => p.id == 'x');
      expect(unlocked.isUnlocked, isTrue);
      expect(unlocked.warpUnlockCount, 1);
    });

    test('在庫0では解禁できない', () async {
      final pin = buildPin(id: 'x', visibleAt: past);
      final provider = await makeProvider(pins: [pin], tickets: 0);
      expect(provider.unlockByWarpTicket('x'), isFalse);
    });
  });

  group('課金フォールバック', () {
    test('ストア不可ならワープパックがモック配布される', () async {
      final provider = await makeProvider(pins: [], tickets: 0);
      await provider.purchaseWarpPack();
      expect(provider.warpTickets, 3);
    });

    test('ストア不可なら投げ銭がモック配布され合計に加算', () async {
      final pin = buildPin(id: 'x', visibleAt: past);
      final provider = await makeProvider(pins: [pin]);

      await provider.purchaseTip('x', 300);
      final tipped = provider.allPins.firstWhere((p) => p.id == 'x');
      expect(tipped.totalTipAmount, 300);
      expect(tipped.giftCount, 1);
    });
  });

  group('安全機能', () {
    test('ブロックした投稿者のピンは visiblePins から除外される', () async {
      // 投稿者IDを持つピンを用意。
      final pin = PinModel(
        id: 'spam',
        authorName: 'spammer',
        ownerId: 'spammer-uid',
        latitude: 38.26,
        longitude: 140.88,
        audioUrl: 'a',
        createdAt: DateTime.now(),
        visibleAt: past,
      );
      final provider = await makeProvider(pins: [pin]);
      await provider.toggleFollow('spammer-uid'); // フォローしても
      expect(provider.visiblePins.map((p) => p.id), contains('spam'));

      await provider.blockAuthor('spammer-uid'); // ブロックで除外
      expect(provider.visiblePins.map((p) => p.id), isNot(contains('spam')));
    });

    test('運営非表示(hidden)のピンは visiblePins から除外', () async {
      final hidden = PinModel(
        id: 'h',
        authorName: 'x',
        ownerId: 'other',
        latitude: 38.26,
        longitude: 140.88,
        audioUrl: 'a',
        createdAt: DateTime.now(),
        visibleAt: past,
        hidden: true,
      );
      final provider = await makeProvider(pins: [hidden]);
      await provider.toggleFollow('other');
      expect(provider.visiblePins.map((p) => p.id), isNot(contains('h')));
    });

    test('通報したピンは即時非表示になる', () async {
      final pin = buildPin(id: 'x', visibleAt: past, owner: 'someone');
      final provider = await makeProvider(pins: [pin]);
      await provider.toggleFollow('someone');
      expect(provider.visiblePins.map((p) => p.id), contains('x'));

      await provider.reportPin(pin, ReportReason.spam);
      expect(provider.visiblePins.map((p) => p.id), isNot(contains('x')));
    });

    test('通報が ReportSink に構造化レコードとして送られる', () async {
      final sink = FakeReportSink();
      final pin = buildPin(id: 'x', visibleAt: past);
      final provider = PinProvider(
        dataSource: FakePinDataSource([pin]),
        settingsStore: FakeSettingsStore(2),
        purchaseGateway: FakePurchaseGateway(),
        authService: FakeAuthService('reporter-1'),
        reportSink: sink,
      );
      await provider.init();
      await pumpEventQueue();

      await provider.reportPin(pin, ReportReason.stalking, note: 'こわい');
      expect(sink.submitted, hasLength(1));
      final r = sink.submitted.first;
      expect(r.pinId, 'x');
      expect(r.reason, ReportReason.stalking);
      expect(r.reporterId, 'reporter-1');
      expect(r.note, 'こわい');

      // 運営ステータス更新。
      await provider.updateReportStatus(r.id, ReportStatus.actioned);
      final after = await provider.loadReports();
      expect(after.first.status, ReportStatus.actioned);
    });

    test('ブロック一覧の表示と解除', () async {
      final spam = PinModel(
        id: 's',
        authorName: 'spammer',
        ownerId: 'spammer-uid',
        latitude: 38.26,
        longitude: 140.88,
        audioUrl: 'a',
        createdAt: DateTime.now(),
        visibleAt: past,
      );
      final provider = await makeProvider(pins: [spam]);
      await provider.blockAuthor('spammer-uid');
      expect(provider.blockedAccounts.map((b) => b.uid), contains('spammer-uid'));

      await provider.unblockAuthor('spammer-uid');
      expect(provider.blockedAccounts, isEmpty);
    });

    test('位置情報ぼかし設定でドロップ座標が丸められる', () async {
      final provider = await makeProvider(pins: []);
      provider.setLocationForTest(38.260123, 140.882456);
      await provider.updatePrivacy(provider.privacy
          .copyWith(locationPrecision: LocationPrecision.approximate));
      final pin = provider.dropPin(
          audioPath: 'a', title: 't', lockDuration: const Duration(hours: 1))!;
      // 小数3桁（約100m）に丸め。
      expect(pin.latitude, 38.26);
      expect(pin.longitude, 140.882);
    });

    test('自分の投稿は通報しても自分には残る（マイドロップ保護）', () async {
      final provider = await makeProvider(pins: []);
      provider.setLocationForTest(38.2601, 140.8824);
      final pin = provider.dropPin(
        audioPath: 'a',
        title: 't',
        lockDuration: const Duration(hours: 1),
      )!;
      await provider.reportPin(pin, ReportReason.other);
      expect(provider.myPins.map((p) => p.id), contains(pin.id));
    });
  });

  group('フォロー / プロフィール', () {
    test('toggleFollow でフィードと状態が切り替わる', () async {
      final provider = await makeProvider(pins: [
        buildPin(id: 'a', visibleAt: past, owner: 'acc1'),
        buildPin(id: 'b', visibleAt: past, owner: 'acc2'),
      ]);
      expect(provider.isFollowing('acc1'), isFalse);

      await provider.toggleFollow('acc1');
      expect(provider.isFollowing('acc1'), isTrue);
      expect(provider.visiblePins.map((p) => p.id), contains('a'));
      expect(provider.visiblePins.map((p) => p.id), isNot(contains('b')));

      await provider.toggleFollow('acc1');
      expect(provider.isFollowing('acc1'), isFalse);
    });

    test('フォロワー数・相互フォロー・検索', () async {
      final provider = await makeProvider(pins: []);
      // 名簿は acc1(followsBack=true, base10), acc2(false, base5)。
      expect(provider.accounts.map((a) => a.uid).toSet(), {'acc1', 'acc2'});
      expect(provider.followerCount('acc1'), 10);
      expect(provider.isMutual('acc1'), isFalse);

      await provider.toggleFollow('acc1');
      expect(provider.followerCount('acc1'), 11); // 自分の分が加算
      expect(provider.isMutual('acc1'), isTrue); // followsBack=true
      expect(provider.myFollowingCount, 1);
      expect(provider.myFollowerCount, 1); // followsBack の人数

      expect(provider.searchAccounts('two').single.uid, 'acc2');
    });

    test('updateProfile で表示名・ユーザー名が更新される', () async {
      final provider = await makeProvider(pins: []);
      await provider.updateProfile(displayName: '新しい名前', username: 'newname');
      expect(provider.currentUser?.displayName, '新しい名前');
      expect(provider.currentUser?.username, 'newname');
    });
  });

  group('保存（お気に入り）', () {
    test('toggleSaved で保存・解除でき savedPins に反映', () async {
      final pin = buildPin(id: 'x', visibleAt: past);
      final provider = await makeProvider(pins: [pin]);
      expect(provider.isSaved(pin), isFalse);

      await provider.toggleSaved('x');
      expect(provider.isSaved(pin), isTrue);
      expect(provider.savedPins.map((p) => p.id), contains('x'));

      await provider.toggleSaved('x');
      expect(provider.isSaved(pin), isFalse);
      expect(provider.savedPins, isEmpty);
    });
  });

  test('deletePin で一覧から消える', () async {
    final provider = await makeProvider(pins: [
      buildPin(id: 'a', visibleAt: past),
      buildPin(id: 'b', visibleAt: past),
    ]);
    await provider.deletePin('a');
    await pumpEventQueue();
    expect(provider.allPins.map((p) => p.id), isNot(contains('a')));
    expect(provider.allPins.map((p) => p.id), contains('b'));
  });
}
