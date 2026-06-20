import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/dummy_pins.dart';
import '../models/pin_model.dart';
import 'pin_data_source.dart';

/// SharedPreferences によるローカル実装。
///
/// 初回起動時のみデモ用ダミーピンを投入する。1端末＝1ユーザーのオフライン動作で、
/// Firebase 無しでもアプリ全体（デモ）が成立するようにするためのデフォルト実装。
class LocalPinDataSource implements PinDataSource {
  static const _pinsKey = 'pins_v1';
  static const _seededKey = 'seeded_v1';

  List<PinModel> _pins = [];
  bool _ready = false;

  late final StreamController<List<PinModel>> _controller =
      StreamController<List<PinModel>>(onListen: _handleListen);

  Future<void> _handleListen() async {
    await _ensureLoaded();
    _emit();
  }

  Future<void> _ensureLoaded() async {
    if (_ready) return;
    final prefs = await SharedPreferences.getInstance();

    if (!(prefs.getBool(_seededKey) ?? false)) {
      _pins = buildDummyPins();
      await _persist(prefs);
      await prefs.setBool(_seededKey, true);
    } else {
      final raw = prefs.getString(_pinsKey);
      _pins = (raw == null || raw.isEmpty)
          ? []
          : (jsonDecode(raw) as List<dynamic>)
              .map((e) => PinModel.fromJson(e as Map<String, dynamic>))
              .toList();
    }
    _ready = true;
  }

  Future<void> _persist([SharedPreferences? prefsArg]) async {
    final prefs = prefsArg ?? await SharedPreferences.getInstance();
    await prefs.setString(
        _pinsKey, jsonEncode(_pins.map((p) => p.toJson()).toList()));
  }

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(List.unmodifiable(_pins));
    }
  }

  @override
  Stream<List<PinModel>> watchPins() => _controller.stream;

  @override
  Future<void> upsertPin(PinModel pin) async {
    await _ensureLoaded();
    final idx = _pins.indexWhere((p) => p.id == pin.id);
    if (idx >= 0) {
      _pins[idx] = pin;
    } else {
      _pins = [..._pins, pin];
    }
    await _persist();
    _emit();
  }

  @override
  Future<void> deletePin(String id) async {
    await _ensureLoaded();
    _pins = _pins.where((p) => p.id != id).toList();
    await _persist();
    _emit();
  }

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}
