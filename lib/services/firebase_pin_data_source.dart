import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/pin_model.dart';
import 'pin_data_source.dart';

/// Firestore の `pins` コレクションでピンを同期するデータソース。
///
/// `watchPins()` が snapshots() を流すので、他ユーザーの投稿追加・削除・
/// 集計更新がリアルタイムで全端末に反映される。録音音声はローカルパスのままだと
/// 他端末で再生できないため、保存時に Firebase Storage へアップロードして
/// ダウンロードURLに置き換える。
class FirebasePinDataSource implements PinDataSource {
  FirebasePinDataSource({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _col = (firestore ?? FirebaseFirestore.instance).collection('pins'),
        _storage = storage ?? FirebaseStorage.instance;

  final CollectionReference<Map<String, dynamic>> _col;
  final FirebaseStorage _storage;

  @override
  Stream<List<PinModel>> watchPins() => _col.snapshots().map(
        (snap) => snap.docs.map((d) => PinModel.fromJson(d.data())).toList(),
      );

  @override
  Future<void> upsertPin(PinModel pin) async {
    var toSave = pin;
    // ローカルの録音ファイルなら Storage にアップロードしてURL化（初回のみ）。
    if (!pin.isAssetAudio &&
        !pin.audioUrl.startsWith('http') &&
        pin.audioUrl.isNotEmpty) {
      final file = File(pin.audioUrl);
      if (await file.exists()) {
        final ref = _storage.ref('drops/${pin.ownerId}/${pin.id}.m4a');
        // Content-Type を明示。録音は AAC/m4a。
        // 未指定だと octet-stream 等になり Storage ルール(audio/.*)に弾かれる。
        await ref.putFile(
          file,
          SettableMetadata(contentType: 'audio/mp4'),
        );
        final url = await ref.getDownloadURL();
        toSave = pin.copyWith(audioUrl: url);
      }
    }
    // isUnlocked / isOwn は「読み手ごと」の状態なので共有ドキュメントには持たせない。
    // （持たせると他ユーザーにも解禁済みとして見えてしまう。解禁は端末側で管理）
    final data = toSave.toJson()
      ..['isUnlocked'] = false
      ..['isOwn'] = false;
    await _col.doc(toSave.id).set(data);
  }

  @override
  Future<void> deletePin(String id) async {
    await _col.doc(id).delete();
    // 音声も削除（存在しなくてもエラーにしない）。
    try {
      await _storage.ref('drops').child(id).delete();
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {}
}
