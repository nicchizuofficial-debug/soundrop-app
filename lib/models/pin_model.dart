import 'package:latlong2/latlong.dart';

/// 音声ドロップの1件分を表すデータモデル。
///
/// 防犯配慮のための「タイムロック（時間差公開）」と「GPSアンロック（現地解禁）」、
/// さらに個人開発でも実現可能なマネタイズ要素（ワープチケット消費・投げ銭）を
/// データレベルで保持する。
class PinModel {
  /// 一意なID（バックエンド導入時はサーバー採番を想定）。
  final String id;

  /// 投稿者の表示名。投げ銭UIのラベルなどに利用する。
  final String authorName;

  /// 投稿者のユーザーID（匿名認証のuid）。
  /// 「自分の投稿か」をマルチユーザー環境で正しく判定するために使う。
  final String ownerId;

  /// 緯度。
  final double latitude;

  /// 経度。
  final double longitude;

  /// 録音された音声ファイルのパス／URL。
  /// MVPではモックのため再生はダミー扱い。
  final String audioUrl;

  /// メモ・タイトル（任意）。
  final String title;

  /// 録音時に取得した正規化済み振幅（0..1）のダウンサンプル列。
  /// ピン詳細のミニ波形を実データで描画するために保持する。空なら装飾波形にフォールバック。
  final List<double> waveform;

  /// トリミング再生範囲（ミリ秒）。null なら全体を再生。
  /// 元ファイルは再エンコードせず、再生時に [ClippingAudioSource] で切り出す。
  final int? trimStartMs;
  final int? trimEndMs;

  /// ドロップ（録音・投稿）された日時。
  final DateTime createdAt;

  /// 地図上に「鍵付きピン」として出現してよい公開日時（タイムロック解除時刻）。
  /// これを過ぎるまでは他人の地図に一切表示しない。
  final DateTime visibleAt;

  /// 現地解禁の判定半径（メートル）。デフォルト50m。
  final double unlockRadiusInMeters;

  // ---- マネタイズ関連プロパティ ----

  /// 投げ銭（チップ）の累計金額。通貨はアプリ内ポイント or 円を想定。
  final int totalTipAmount;

  /// 応援（投げ銭）を受け取った回数。
  final int giftCount;

  /// ワープチケットによってこのピンが解禁された累計回数（分析・人気指標用）。
  final int warpUnlockCount;

  // ---- 端末ローカルな状態（永続化はバックエンド/ローカルDBを想定） ----

  /// このユーザーがすでに解禁済みかどうか。
  /// 一度GPSまたはワープで解禁したら、離れても再生可能なままにするためのフラグ。
  final bool isUnlocked;

  /// このユーザー自身が投稿したピンかどうか。
  /// 自分のドロップは公開時刻（visibleAt）前でも自分の地図には「公開待ち」として表示する。
  final bool isOwn;

  /// 運営/自動モデレーションにより非表示化されたか（通報閾値超え等）。
  /// 本番は Cloud Functions が通報数を集計してこのフラグを立てる。
  final bool hidden;

  const PinModel({
    required this.id,
    required this.authorName,
    this.ownerId = '',
    required this.latitude,
    required this.longitude,
    required this.audioUrl,
    required this.createdAt,
    required this.visibleAt,
    this.title = '',
    this.waveform = const [],
    this.trimStartMs,
    this.trimEndMs,
    this.unlockRadiusInMeters = 50,
    this.totalTipAmount = 0,
    this.giftCount = 0,
    this.warpUnlockCount = 0,
    this.isUnlocked = false,
    this.isOwn = false,
    this.hidden = false,
  });

  /// 地図上の座標。
  LatLng get position => LatLng(latitude, longitude);

  /// 音声ソースがバンドルされたアセットかどうか。
  /// false の場合は録音されたローカルファイルパスとして扱う。
  bool get isAssetAudio => audioUrl.startsWith('assets/');

  /// 現在時刻基準で「タイムロックが解除され公開対象になっているか」。
  bool isVisibleAt(DateTime now) => !now.isBefore(visibleAt);

  /// 公開までの残り時間（未公開のときのみ意味を持つ）。
  Duration remainingUntilVisible(DateTime now) => visibleAt.difference(now);

  /// 永続化用のJSON変換。DateTime はISO8601文字列で保存する。
  Map<String, dynamic> toJson() => {
        'id': id,
        'authorName': authorName,
        'ownerId': ownerId,
        'latitude': latitude,
        'longitude': longitude,
        'audioUrl': audioUrl,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'visibleAt': visibleAt.toIso8601String(),
        'waveform': waveform,
        'trimStartMs': trimStartMs,
        'trimEndMs': trimEndMs,
        'unlockRadiusInMeters': unlockRadiusInMeters,
        'totalTipAmount': totalTipAmount,
        'giftCount': giftCount,
        'warpUnlockCount': warpUnlockCount,
        'isUnlocked': isUnlocked,
        'isOwn': isOwn,
        'hidden': hidden,
      };

  /// JSON からの復元。
  factory PinModel.fromJson(Map<String, dynamic> json) => PinModel(
        id: json['id'] as String,
        authorName: json['authorName'] as String,
        ownerId: json['ownerId'] as String? ?? '',
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        audioUrl: json['audioUrl'] as String,
        title: json['title'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
        visibleAt: DateTime.parse(json['visibleAt'] as String),
        waveform: (json['waveform'] as List<dynamic>?)
                ?.map((e) => (e as num).toDouble())
                .toList() ??
            const [],
        trimStartMs: json['trimStartMs'] as int?,
        trimEndMs: json['trimEndMs'] as int?,
        unlockRadiusInMeters:
            (json['unlockRadiusInMeters'] as num?)?.toDouble() ?? 50,
        totalTipAmount: json['totalTipAmount'] as int? ?? 0,
        giftCount: json['giftCount'] as int? ?? 0,
        warpUnlockCount: json['warpUnlockCount'] as int? ?? 0,
        isUnlocked: json['isUnlocked'] as bool? ?? false,
        isOwn: json['isOwn'] as bool? ?? false,
        hidden: json['hidden'] as bool? ?? false,
      );

  /// 状態変更用のコピー。Provider/Riverpod でのイミュータブル更新に使う。
  PinModel copyWith({
    bool? isUnlocked,
    int? totalTipAmount,
    int? giftCount,
    int? warpUnlockCount,
    bool? hidden,
    String? audioUrl,
  }) {
    return PinModel(
      id: id,
      authorName: authorName,
      ownerId: ownerId,
      waveform: waveform,
      trimStartMs: trimStartMs,
      trimEndMs: trimEndMs,
      latitude: latitude,
      longitude: longitude,
      audioUrl: audioUrl ?? this.audioUrl,
      title: title,
      createdAt: createdAt,
      visibleAt: visibleAt,
      unlockRadiusInMeters: unlockRadiusInMeters,
      totalTipAmount: totalTipAmount ?? this.totalTipAmount,
      giftCount: giftCount ?? this.giftCount,
      warpUnlockCount: warpUnlockCount ?? this.warpUnlockCount,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      isOwn: isOwn,
      hidden: hidden ?? this.hidden,
    );
  }
}
