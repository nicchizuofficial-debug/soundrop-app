import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../app_config.dart';
import '../config/map_tiles.dart';
import '../models/pin_model.dart';
import '../services/purchase_service.dart';
import '../state/pin_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icons.dart';
import '../widgets/audio_player_widget.dart';
import '../widgets/map_pin.dart';
import '../widgets/mini_waveform.dart';
import '../widgets/report_sheet.dart';
import '../widgets/sound_drop_logo.dart';
import 'accounts_screen.dart';
import 'auth_screen.dart';
import 'drop_screen.dart';
import 'my_drops_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

/// 地図ビューの生成関数。テストでは地図を差し替えられる。
typedef MapViewBuilder = Widget Function(
  BuildContext context,
  List<Marker> markers,
  MapController controller,
  bool myLocationEnabled,
);

/// メイン画面。地図表示・現在地取得・時間フィルタ・距離判定・
/// マネタイズ用ボトムシート（ワープ／投げ銭）をまとめて担当する。
class MapScreen extends StatefulWidget {
  /// 地図ビューの差し替え用（既定は flutter_map）。ウィジェットテストでモック化する。
  final MapViewBuilder? mapViewBuilder;

  const MapScreen({super.key, this.mapViewBuilder});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  /// 仙台駅周辺を初期表示。
  static const _initialCenter = LatLng(38.2601, 140.8824);

  final MapController _controller = MapController();

  @override
  void initState() {
    super.initState();
    // 初回フレーム後に現在地取得＋連続ログイン報酬の通知。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<PinProvider>();
      provider.updateCurrentLocation();
      final reward = provider.consumePendingReward();
      if (reward > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('🎉 7日連続ログイン達成！ワープチケットを$reward枚プレゼント')));
      }
    });
  }

  /// 時間フィルタ済みピンを flutter_map のマーカーに変換。
  List<Marker> _buildMarkers(PinProvider provider) {
    final now = DateTime.now();
    final markers = provider.visiblePins.map((pin) {
      final pending = provider.isMine(pin) && !pin.isVisibleAt(now);
      final unlocked = provider.canPlay(pin);
      final kind = pending
          ? MarkerKind.pending
          : (unlocked ? MarkerKind.unlocked : MarkerKind.locked);
      return Marker(
        point: LatLng(pin.latitude, pin.longitude),
        width: 44,
        height: 56,
        alignment: Alignment.topCenter, // 先端が座標を指す
        child: GestureDetector(
          onTap: () => _onPinTapped(pin),
          child: MapPin(kind: kind),
        ),
      );
    }).toList();

    // 現在地マーカー（青ドット）。
    final loc = provider.currentLatLng;
    if (loc != null) {
      markers.add(Marker(
        point: loc,
        width: 22,
        height: 22,
        child: const _MeDot(),
      ));
    }
    return markers;
  }

  /// 既定の地図ビュー（flutter_map + OpenStreetMap）。
  Widget _defaultMapView(
    BuildContext context,
    List<Marker> markers,
    MapController controller,
    bool myLocationEnabled,
  ) {
    final loc = context.read<PinProvider>().currentLatLng;
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: loc ?? _initialCenter,
        initialZoom: 16,
        onTap: (_, latLng) => _onMapTap(latLng),
      ),
      children: [
        // ダーク地図（MapTiler/Stadiaキーがあれば本番用、無ければCARTOにフォールバック）。
        TileLayer(
          urlTemplate: MapTiles.urlTemplate,
          subdomains: MapTiles.subdomains,
          userAgentPackageName: 'com.example.sound_drop',
        ),
        // 現在地の50m解禁圏。
        if (loc != null)
          CircleLayer(circles: [
            CircleMarker(
              point: loc,
              radius: 50,
              useRadiusInMeter: true,
              color: AppColors.blue.withOpacity(0.12),
              borderColor: AppColors.blue,
              borderStrokeWidth: 1,
            ),
          ]),
        MarkerLayer(markers: markers),
        RichAttributionWidget(attributions: [
          TextSourceAttribution(MapTiles.attribution),
        ]),
      ],
    );
  }

  /// 地図タップで現在地を移動（動作確認用）。
  void _onMapTap(LatLng latLng) {
    context
        .read<PinProvider>()
        .setManualLocation(latLng.latitude, latLng.longitude);
  }

  /// ピンタップ時の分岐。
  void _onPinTapped(PinModel pin) {
    final provider = context.read<PinProvider>();

    if (provider.canPlay(pin)) {
      // すでに解禁済み or 現地 → 再生＆投げ銭シート。
      // 現地に居るがフラグ未設定なら、ここでGPS解禁を確定させる。
      if (!pin.isUnlocked) provider.unlockByGps(pin.id);
      _showUnlockedSheet(pin.id);
    } else {
      // 50m以上離れている → 「歩く」か「ワープ」かの選択シート。
      _showLockedSheet(pin);
    }
  }

  // ---- ボトムシート：施錠中（遠方） ----

  void _showLockedSheet(PinModel pin) {
    final provider = context.read<PinProvider>();
    final distance = provider.distanceToPin(pin);
    final distanceText =
        distance == null ? '計測中…' : '約 ${distance.round()} m 先';

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const GradientIcon(AppIcons.locked, size: 44),
              const SizedBox(height: 12),
              Text(
                'このピンはまだ鍵がかかっています',
                textAlign: TextAlign.center,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                '現在地から $distanceText（解禁まで残り ${pin.unlockRadiusInMeters.round()}m 圏内へ）',
                textAlign: TextAlign.center,
                style: Theme.of(sheetContext).textTheme.bodySmall,
              ),
              const SizedBox(height: 20),

              // 案① 歩いて近づく
              OutlinedButton.icon(
                icon: const Icon(Icons.directions_walk),
                label: const Text('歩いて近づく'),
                onPressed: () => Navigator.pop(sheetContext),
              ),
              const SizedBox(height: 12),

              // 案② ワープチケットを使う（マネタイズ／消費型アイテム）
              FilledButton.icon(
                icon: const Icon(AppIcons.warpTicket),
                label: Text('ワープチケットで今すぐ解禁'
                    '（所持: ${provider.warpTickets}枚）'),
                onPressed: () => _useWarpTicket(sheetContext, pin.id),
              ),
            ],
          ),
        );
      },
    );
  }

  void _useWarpTicket(BuildContext sheetContext, String pinId) {
    final provider = context.read<PinProvider>();
    final ok = provider.unlockByWarpTicket(pinId);
    Navigator.pop(sheetContext);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ワープチケットを1枚使って解禁しました！')),
      );
      _showUnlockedSheet(pinId);
    } else {
      // チケット切れ → 購入導線（モック）へ。
      _showTicketShop();
    }
  }

  void _showTicketShop() {
    final provider = context.read<PinProvider>();
    // ストアから取れた実価格を使い、無ければ参考価格を表示。
    final price =
        provider.purchase.priceOf(PurchaseService.warpPack3Id) ?? '¥320';

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('ワープチケットが足りません',
                textAlign: TextAlign.center,
                style: Theme.of(sheetContext).textTheme.titleMedium),
            const SizedBox(height: 16),
            // β版（課金OFF）では購入導線を出さない。
            if (!AppConfig.enablePurchases)
              const Text('現在ワープチケットは購入いただけません（準備中）。\n'
                  '50m以内に近づくと解禁できます。',
                  textAlign: TextAlign.center)
            else
            FilledButton(
              onPressed: () async {
                await context.read<PinProvider>().purchaseWarpPack();
                if (sheetContext.mounted) Navigator.pop(sheetContext);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('ワープチケットを追加しました')),
                );
              },
              child: Text('3枚パックを購入（$price）'),
            ),
          ],
        ),
      ),
    );
  }

  // ---- ボトムシート：解禁済み（再生＆投げ銭） ----

  void _showUnlockedSheet(String pinId) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      // Provider の変更（投げ銭額の増加）を即時反映させたいので Consumer で包む。
      builder: (sheetContext) => Consumer<PinProvider>(
        builder: (consumerContext, provider, _) {
          final pin =
              provider.allPins.firstWhere((p) => p.id == pinId);
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(pin.title.isEmpty ? '無題のドロップ' : pin.title),
                  subtitle: Text('by ${pin.authorName}'),
                  // 他人の投稿のみフォロー操作・通報/ブロックを出す。
                  trailing: provider.isMine(pin)
                      ? null
                      : PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: (v) =>
                              _onSafetyAction(sheetContext, pin, v),
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                                value: 'profile', child: Text('プロフィールを見る')),
                            PopupMenuItem(
                                value: 'follow',
                                child: Text(provider.isFollowing(pin.ownerId)
                                    ? 'フォロー解除'
                                    : 'フォローする')),
                            const PopupMenuItem(
                                value: 'report', child: Text('このピンを通報')),
                            const PopupMenuItem(
                                value: 'block', child: Text('この投稿者をブロック')),
                          ],
                        ),
                ),
                const SizedBox(height: 8),

                // 録音時の実波形（無ければIDベースの装飾波形）。
                MiniWaveform(seed: pin.id, data: pin.waveform, height: 44),
                const SizedBox(height: 8),

                // 実音声プレイヤー（just_audio）。
                AudioPlayerWidget.fromPin(pin, key: ValueKey(pin.id)),
                const SizedBox(height: 20),

                // 応援を贈る（マネタイズ／ギフティング）。
                if (AppConfig.enableTipping) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const GradientIcon(AppIcons.support, size: 18),
                          const SizedBox(width: 6),
                          Text(
                              '${pin.totalTipAmount}円 / ${pin.giftCount}件の応援',
                              style: Theme.of(consumerContext)
                                  .textTheme
                                  .bodyMedium),
                        ],
                      ),
                      FilledButton.tonalIcon(
                        icon: const Icon(AppIcons.support),
                        label: const Text('応援を贈る'),
                        onPressed: () => _showTipOptions(pinId),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                // 解禁したドロップを保存（お気に入り）。
                OutlinedButton.icon(
                  icon: Icon(provider.isSaved(pin)
                      ? Icons.bookmark
                      : Icons.bookmark_border),
                  label: Text(provider.isSaved(pin) ? '保存済み' : 'このドロップを保存'),
                  onPressed: () => provider.toggleSaved(pin.id),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 通報・ブロックの実行。実行後はシートを閉じる（その投稿は非表示になるため）。
  Future<void> _onSafetyAction(
      BuildContext sheetContext, PinModel pin, String action) async {
    final provider = context.read<PinProvider>();
    if (action == 'profile') {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ProfileScreen(uid: pin.ownerId)));
      return;
    }
    if (action == 'follow') {
      final wasFollowing = provider.isFollowing(pin.ownerId);
      await provider.toggleFollow(pin.ownerId);
      if (mounted) {
        _snack(wasFollowing ? 'フォローを解除しました' : 'フォローしました');
      }
      return;
    }
    if (action == 'report') {
      final reason = await showReportReasonSheet(context);
      if (reason == null) return;
      await provider.reportPin(pin, reason);
      if (sheetContext.mounted) Navigator.pop(sheetContext);
      if (mounted) _snack('通報しました。表示を停止します。');
    } else if (action == 'block') {
      await provider.blockAuthor(pin.ownerId);
      if (sheetContext.mounted) Navigator.pop(sheetContext);
      if (mounted) _snack('${pin.authorName}さんをブロックしました。');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// 応援（投げ銭）の金額選択。
  void _showTipOptions(String pinId) {
    // 金額に「サウンド」になぞらえたラベルを添えて、アプリらしい応援体験に。
    // demo と同じアイコン（spark / support / star）で応援ティアを表現。
    const tiers = <(int, String, IconData)>[
      (100, 'ちいさな拍手', AppIcons.spark),
      (300, 'いいね！の声援', AppIcons.support),
      (500, '最高のサウンドに', AppIcons.star),
    ];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const GradientIcon(AppIcons.support, size: 36),
            const SizedBox(height: 8),
            Text('このサウンドに応援を贈る',
                style: Theme.of(sheetContext).textTheme.titleMedium),
            const SizedBox(height: 16),
            for (final (amount, label, icon) in tiers)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed: () async {
                      // in_app_purchase で購入。ストア不可ならモック配布される。
                      await context
                          .read<PinProvider>()
                          .purchaseTip(pinId, amount);
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$amount円の応援を贈りました')),
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GradientIcon(icon, size: 20),
                        const SizedBox(width: 8),
                        Text('$label  ¥$amount'),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Image(
              image: AssetImage('assets/icon/app_icon_custom.png'),
              width: 34,
              height: 34,
            ),
            const SizedBox(width: 8),
            const GradientMask(
              child: Text('SounDrop',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ],
        ),
        actions: [
          // 所持チケット数（タップでワープチケット購入＝v1.1の購入導線）。
          Consumer<PinProvider>(
            builder: (_, provider, __) => Center(
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _showTicketShop,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      const GradientIcon(AppIcons.warpTicket, size: 20),
                      const SizedBox(width: 4),
                      Text('${provider.warpTickets}'),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // アカウントを探す（フォロー）。
          IconButton(
            tooltip: 'アカウントを探す',
            icon: const Icon(Icons.person_search),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AccountsScreen()),
            ),
          ),
          // マイドロップ／ピン一覧の管理画面へ。
          IconButton(
            tooltip: 'ピン一覧',
            icon: const Icon(Icons.list),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MyDropsScreen()),
            ),
          ),
          // アカウントメニュー（プロフィール設定・ログアウト）。
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (v) {
              final uid = context.read<PinProvider>().currentUid;
              if (v == 'signout') _signOut();
              if (v == 'myprofile' && uid != null) {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ProfileScreen(uid: uid)));
              }
              if (v == 'settings') {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const SettingsScreen()));
              }
            },
            itemBuilder: (_) {
              final u = context.read<PinProvider>().currentUser;
              return [
                PopupMenuItem(
                    enabled: false,
                    child: Text('${u?.displayName ?? ''}\n@${u?.username ?? ''}')),
                const PopupMenuItem(
                    value: 'myprofile', child: Text('マイプロフィール')),
                const PopupMenuItem(value: 'settings', child: Text('設定')),
                const PopupMenuItem(value: 'signout', child: Text('ログアウト')),
              ];
            },
          ),
        ],
      ),
      body: Consumer<PinProvider>(
        builder: (context, provider, _) {
          // 永続データの読込中はロゴ付きローダー。
          if (!provider.isLoaded) {
            return const Center(child: SoundDropLogo(size: 96));
          }
          return Column(
            children: [
              _LocationBanner(status: provider.locationStatus),
              Expanded(
                child: Stack(
                  children: [
                    (widget.mapViewBuilder ?? _defaultMapView)(
                      context,
                      _buildMarkers(provider),
                      _controller,
                      provider.locationStatus == LocationStatus.granted,
                    ),
                    // フィードが空（フォロー先が無い/未公開のみ）のときの誘導。
                    if (provider.visiblePins.isEmpty)
                      const _EmptyFeedHint(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'locate',
            tooltip: '現在地更新',
            backgroundColor: AppColors.navyElevated,
            child: const GradientIcon(AppIcons.myLocation, size: 22),
            onPressed: () =>
                context.read<PinProvider>().updateCurrentLocation(),
          ),
          const SizedBox(height: 12),
          // ブランドグラデーションのドロップボタン。
          _GradientPillButton(
            icon: AppIcons.drop,
            label: 'ドロップ',
            onTap: _openDropScreen,
          ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    await context.read<PinProvider>().signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }

  /// 録音・ドロップ画面へ遷移。ドロップ成功後はカメラを投稿地点へ寄せる。
  Future<void> _openDropScreen() async {
    final provider = context.read<PinProvider>();
    // ドロップには現在地が必要なので、未取得なら先に取得を試みる。
    if (provider.currentLatLng == null) {
      await provider.updateCurrentLocation();
    }

    if (!mounted) return;
    final dropped = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const DropScreen()),
    );

    if (dropped == true) {
      final loc = provider.currentLatLng;
      if (loc != null) {
        _controller.move(loc, _controller.camera.zoom);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ドロップしました！公開時刻になると他の人にも表示されます。')),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

/// 現在地（青ドット）マーカー。
class _MeDot extends StatelessWidget {
  const _MeDot();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF5B8DEF),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(color: const Color(0xFF5B8DEF).withOpacity(0.4), blurRadius: 6),
        ],
      ),
    );
  }
}

/// フォロー先が無い等でフィードが空のときの誘導カード。
class _EmptyFeedHint extends StatelessWidget {
  const _EmptyFeedHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.navySurface.withOpacity(0.95),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_search, size: 40, color: AppColors.pink),
            const SizedBox(height: 12),
            const Text('フォロー中のドロップがありません',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text(
              'アカウントをフォローすると、その人の公開ドロップが地図に表示されます。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.person_add_alt),
              label: const Text('アカウントを探す'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AccountsScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 位置情報が使えないときに地図上部へ出す説明バナー。
class _LocationBanner extends StatelessWidget {
  final LocationStatus status;
  const _LocationBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    String msg;
    String action;
    switch (status) {
      case LocationStatus.serviceOff:
        msg = '位置情報サービスがオフです。';
        action = '設定を開く';
      case LocationStatus.denied:
        msg = '位置情報の許可が必要です（現地解禁・ドロップに使用）。';
        action = '許可する';
      case LocationStatus.deniedForever:
        msg = '位置情報が拒否されています。設定から許可してください。';
        action = '設定を開く';
      case LocationStatus.unknown:
      case LocationStatus.granted:
        return const SizedBox.shrink();
    }

    return Material(
      color: AppColors.navyElevated,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(
          children: [
            const Icon(Icons.location_off, color: AppColors.pink, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(msg, style: const TextStyle(fontSize: 13))),
            TextButton(
              onPressed: () {
                if (status == LocationStatus.denied) {
                  context.read<PinProvider>().updateCurrentLocation();
                } else {
                  Geolocator.openLocationSettings();
                }
              },
              child: Text(action),
            ),
          ],
        ),
      ),
    );
  }
}

/// ブランドグラデーションのピル型ボタン。
class _GradientPillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _GradientPillButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: AppColors.brand,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.blue.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: AppColors.navy),
                const SizedBox(width: 8),
                Text(label,
                    style: const TextStyle(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
