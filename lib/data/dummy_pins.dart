import '../models/pin_model.dart';

/// デモ用ダミーデータ。
///
/// テスト基準座標は仙台駅周辺（緯度: 38.2601, 経度: 140.8824）。
/// 「公開済み（visibleAt が過去）」と「未公開（visibleAt が未来）」を混在させ、
/// 時間フィルタリングの動作を確認できるようにしている。
List<PinModel> buildDummyPins() {
  final now = DateTime.now();

  return [
    // ① 公開済み：3時間前にドロップ、すでに公開時刻を過ぎている。
    //    仙台駅前。GPSアンロック / ワープチケットの対象になる。
    PinModel(
      id: 'pin_001',
      authorName: 'けんた',
      ownerId: 'demo_kenta',
      title: '駅前で見つけた最高の場所',
      latitude: 38.2601,
      longitude: 140.8824,
      audioUrl: 'assets/audio/sample1.m4a',
      createdAt: now.subtract(const Duration(hours: 3)),
      visibleAt: now.subtract(const Duration(minutes: 1)), // 公開済み
      totalTipAmount: 1500,
      giftCount: 5,
      warpUnlockCount: 12,
    ),

    // ② 公開済み：駅から少し北（約400m）。遠方扱いになりやすくワープ導線の確認に最適。
    PinModel(
      id: 'pin_002',
      authorName: 'みさき',
      ownerId: 'demo_misaki',
      title: 'ここだけの内緒話',
      latitude: 38.2637,
      longitude: 140.8820,
      audioUrl: 'assets/audio/sample2.m4a',
      createdAt: now.subtract(const Duration(hours: 5)),
      visibleAt: now.subtract(const Duration(hours: 2)), // 公開済み
      totalTipAmount: 300,
      giftCount: 1,
      warpUnlockCount: 3,
    ),

    // ③ 未公開：たった今ドロップ、3時間後に公開予定。地図には出ないはず。
    PinModel(
      id: 'pin_003',
      authorName: 'ゆうと',
      ownerId: 'demo_yuto',
      title: '3時間後に会おう',
      latitude: 38.2590,
      longitude: 140.8850,
      audioUrl: 'assets/audio/sample3.m4a',
      createdAt: now,
      visibleAt: now.add(const Duration(hours: 3)), // 未公開（タイムロック中）
    ),
  ];
}
