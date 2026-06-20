import '../models/pin_model.dart';

/// ピンの永続化・同期を抽象化するデータソース。
///
/// ローカル実装（[LocalPinDataSource]）と Firebase 実装（docs/backend 参照）を
/// 差し替えられるようにし、UI/状態管理側は実装に依存しない。
abstract class PinDataSource {
  /// ピン一覧の購読。購読開始直後に現在の一覧を即時 emit する。
  /// Firebase 実装では他ユーザーの投稿変更もここに流れてくる（リアルタイム同期）。
  Stream<List<PinModel>> watchPins();

  /// ピンを作成または更新する。
  Future<void> upsertPin(PinModel pin);

  /// ピンを削除する。
  Future<void> deletePin(String id);

  /// 後始末（ストリームのクローズ等）。
  Future<void> dispose();
}
