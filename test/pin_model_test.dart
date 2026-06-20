import 'package:flutter_test/flutter_test.dart';
import 'package:sound_drop/models/pin_model.dart';

PinModel _pin({
  String id = 'p1',
  required DateTime createdAt,
  required DateTime visibleAt,
  String audioUrl = 'assets/audio/sample1.m4a',
}) {
  return PinModel(
    id: id,
    authorName: 'tester',
    latitude: 38.2601,
    longitude: 140.8824,
    audioUrl: audioUrl,
    createdAt: createdAt,
    visibleAt: visibleAt,
  );
}

void main() {
  final now = DateTime(2026, 6, 6, 12);

  group('タイムロック判定', () {
    test('公開時刻を過ぎていれば表示対象', () {
      final pin = _pin(
        createdAt: now.subtract(const Duration(hours: 3)),
        visibleAt: now.subtract(const Duration(minutes: 1)),
      );
      expect(pin.isVisibleAt(now), isTrue);
    });

    test('公開時刻前は非表示', () {
      final pin = _pin(
        createdAt: now,
        visibleAt: now.add(const Duration(hours: 3)),
      );
      expect(pin.isVisibleAt(now), isFalse);
      expect(pin.remainingUntilVisible(now), const Duration(hours: 3));
    });
  });

  group('音声ソース判定', () {
    test('assets/ 始まりはアセット', () {
      final pin = _pin(
          createdAt: now, visibleAt: now, audioUrl: 'assets/audio/a.m4a');
      expect(pin.isAssetAudio, isTrue);
    });

    test('ファイルパスはアセットではない', () {
      final pin = _pin(
          createdAt: now, visibleAt: now, audioUrl: '/data/user/drop_1.m4a');
      expect(pin.isAssetAudio, isFalse);
    });
  });

  group('JSON シリアライズ', () {
    test('round trip で全フィールドが保持される', () {
      final pin = PinModel(
        id: 'p9',
        authorName: 'みさき',
        title: 'タイトル',
        latitude: 38.26,
        longitude: 140.88,
        audioUrl: '/data/drop_9.m4a',
        createdAt: now,
        visibleAt: now.add(const Duration(hours: 1)),
        totalTipAmount: 500,
        giftCount: 2,
        warpUnlockCount: 3,
        isUnlocked: true,
        isOwn: true,
      );
      final restored = PinModel.fromJson(pin.toJson());

      expect(restored.id, pin.id);
      expect(restored.authorName, pin.authorName);
      expect(restored.title, pin.title);
      expect(restored.latitude, pin.latitude);
      expect(restored.longitude, pin.longitude);
      expect(restored.audioUrl, pin.audioUrl);
      expect(restored.createdAt, pin.createdAt);
      expect(restored.visibleAt, pin.visibleAt);
      expect(restored.totalTipAmount, 500);
      expect(restored.giftCount, 2);
      expect(restored.warpUnlockCount, 3);
      expect(restored.isUnlocked, isTrue);
      expect(restored.isOwn, isTrue);
    });
  });

  group('copyWith', () {
    test('指定フィールドのみ更新し isOwn を保つ', () {
      final pin = _pin(createdAt: now, visibleAt: now).copyWith();
      final tipped = pin.copyWith(totalTipAmount: 100, giftCount: 1);
      expect(tipped.totalTipAmount, 100);
      expect(tipped.giftCount, 1);
      expect(tipped.id, pin.id);
    });
  });
}
