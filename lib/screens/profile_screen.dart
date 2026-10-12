import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/pin_model.dart';
import '../state/pin_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icons.dart';
import '../widgets/mini_waveform.dart';
import '../widgets/ui_kit.dart';
import '../widgets/user_avatar.dart';
import 'follow_list_screen.dart';
import 'map_screen.dart';
import 'profile_settings_screen.dart';
import 'settings_screen.dart';

/// プロフィール画面。自分（フォロー/フォロワー一覧つき・編集）と他人の両対応。
class ProfileScreen extends StatelessWidget {
  final String uid;
  const ProfileScreen({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return Consumer<PinProvider>(
      builder: (context, provider, _) {
        final isSelf = uid == provider.currentUid;
        final me = provider.currentUser;
        final account = provider.accountOf(uid);

        if ((isSelf && me == null) || (!isSelf && account == null)) {
          return Scaffold(
            appBar: AppBar(title: const Text('プロフィール')),
            body: EmptyState(
              icon: Icons.person_off_outlined,
              title: isSelf ? 'ログインが必要です' : 'アカウントが見つかりません',
              message: isSelf ? null : '退会したか、名前が変更された可能性があります。',
            ),
          );
        }

        final name = isSelf ? me!.displayName : account!.displayName;
        final username = isSelf ? me!.username : account!.username;
        final bio = isSelf ? me!.bio : account!.bio;
        final avatar = isSelf ? me!.avatarPath : account!.avatarPath;
        final mutual = !isSelf && provider.isMutual(uid);
        final following = !isSelf && provider.isFollowing(uid);
        final drops = isSelf ? provider.myPins : provider.pinsByOwner(uid);
        final canSeeDrops = isSelf || following;

        return Scaffold(
          appBar: AppBar(
            title: Text(isSelf ? 'マイプロフィール' : '@$username'),
            actions: [
              if (isSelf)
                IconButton(
                  tooltip: '設定',
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const SettingsScreen())),
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              // ---- ヘッダー（アバター・名前・自己紹介） ----
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Column(
                  children: [
                    UserAvatar(
                        name: name, imagePath: avatar, radius: 46, ring: true),
                    const SizedBox(height: 14),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w800)),
                        if (mutual)
                          const AppTag(
                              label: '相互フォロー',
                              color: AppColors.pink,
                              icon: Icons.sync_alt_rounded),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('@$username',
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.textMuted)),
                    if (bio.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(bio,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14, height: 1.6)),
                    ] else if (isSelf) ...[
                      const SizedBox(height: 12),
                      const Text('自己紹介はまだありません',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textMuted)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ---- 数字（自分はフォロー/フォロワーをタップで一覧へ） ----
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        StatItem(label: 'ドロップ', value: drops.length),
                        const _VDivider(),
                        if (isSelf) ...[
                          StatItem(
                            label: 'フォロー中',
                            value: provider.myFollowingCount,
                            onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const FollowListScreen(
                                        kind: FollowListKind.following))),
                          ),
                          const _VDivider(),
                        ],
                        StatItem(
                          label: 'フォロワー',
                          value: isSelf
                              ? provider.myFollowerCount
                              : provider.followerCount(uid),
                          onTap: isSelf
                              ? () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => const FollowListScreen(
                                          kind: FollowListKind.followers)))
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ---- アクション ----
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: isSelf
                    ? OutlinedButton.icon(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        label: const Text('プロフィールを編集'),
                        onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const ProfileSettingsScreen())),
                      )
                    : following
                        ? OutlinedButton.icon(
                            icon: const Icon(Icons.check_rounded, size: 20),
                            label: const Text('フォロー中'),
                            onPressed: () => provider.toggleFollow(uid),
                          )
                        : GradientButton(
                            icon: const Icon(Icons.person_add_alt_rounded),
                            label: 'フォローする',
                            onPressed: () => provider.toggleFollow(uid),
                          ),
              ),
              const SizedBox(height: 28),

              // ---- ドロップ一覧 ----
              if (!canSeeDrops)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: EmptyState(
                    icon: Icons.lock_outline_rounded,
                    title: 'フォローするとドロップを聴けます',
                    message: 'この人の公開ドロップが、\n地図と一覧に表示されるようになります。',
                  ),
                )
              else if (drops.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: EmptyState(
                    icon: AppIcons.drop,
                    title: isSelf ? 'まだドロップがありません' : '公開中のドロップはありません',
                    message: isSelf ? '地図の「ドロップ」から、\nその場所に音を残してみましょう。' : null,
                  ),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
                  child: SectionLabel(
                    'ドロップ',
                    // この人のドロップだけに絞った地図で、まとめて場所を確認できる。
                    trailing: TextButton.icon(
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: const Text('地図で見る'),
                      onPressed: () =>
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => MapScreen(
                                    filterOwnerId: uid,
                                    filterOwnerName: name,
                                  ))),
                    ),
                  ),
                ),
                for (final p in drops)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: _DropCard(uid: uid, name: name, pin: p),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _VDivider extends StatelessWidget {
  const _VDivider();
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 32, color: AppColors.outline);
}

/// タップすると、このドロップの位置を中心にした絞り込み地図へ遷移する
/// （地図側で解禁済みなら再生、未解禁なら距離表示・ワープ解禁ができる）。
class _DropCard extends StatelessWidget {
  final String uid;
  final String name;
  final PinModel pin;
  const _DropCard({required this.uid, required this.name, required this.pin});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<PinProvider>();
    final now = DateTime.now();
    final pending = !pin.isVisibleAt(now);
    final playable = provider.canPlay(pin);
    final (IconData icon, Color color, String status) = pending
        ? (AppIcons.pending, AppColors.pending, '公開待ち')
        : playable
            ? (AppIcons.unlocked, AppColors.unlocked, '聴ける')
            : (AppIcons.locked, AppColors.locked, '現地かワープで解禁');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => MapScreen(
                  filterOwnerId: uid,
                  filterOwnerName: name,
                  focusLatLng: LatLng(pin.latitude, pin.longitude),
                ))),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pin.title.isEmpty ? '無題のドロップ' : pin.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    MiniWaveform(seed: pin.id, data: pin.waveform, height: 18),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        AppTag(label: status, color: color, dot: true),
                        const SizedBox(width: 8),
                        Text(relativeTime(pin.createdAt, now: now),
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textMuted)),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
