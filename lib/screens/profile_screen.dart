import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/pin_model.dart';
import '../state/pin_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/audio_player_widget.dart';
import '../widgets/mini_waveform.dart';
import '../widgets/user_avatar.dart';
import 'auth_screen.dart';
import 'follow_list_screen.dart';
import 'profile_settings_screen.dart';

/// プロフィール画面。自分（フォロー/フォロワー一覧つき・編集）と他人の両対応。
class ProfileScreen extends StatelessWidget {
  final String uid;
  const ProfileScreen({super.key, required this.uid});

  Future<void> _logout(BuildContext context) async {
    await context.read<PinProvider>().signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('プロフィール')),
      body: Consumer<PinProvider>(
        builder: (context, provider, _) {
          final isSelf = uid == provider.currentUid;
          final me = provider.currentUser;
          final account = provider.accountOf(uid);

          if (isSelf && me == null) {
            return const Center(child: Text('ログインが必要です。'));
          }
          if (!isSelf && account == null) {
            return const Center(child: Text('アカウントが見つかりません。'));
          }

          final name = isSelf ? me!.displayName : account!.displayName;
          final username = isSelf ? me!.username : account!.username;
          final bio = isSelf ? me!.bio : account!.bio;
          final avatar = isSelf ? me!.avatarPath : account!.avatarPath;
          final mutual = !isSelf && provider.isMutual(uid);
          final following = !isSelf && provider.isFollowing(uid);
          final drops =
              isSelf ? provider.myPins : provider.pinsByOwner(uid);

          return ListView(
            children: [
              const SizedBox(height: 16),
              Center(
                child: UserAvatar(name: name, imagePath: avatar, radius: 40),
              ),
              const SizedBox(height: 10),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(name, style: Theme.of(context).textTheme.titleLarge),
                    if (mutual) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.pink.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('相互フォロー',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.pink,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ],
                ),
              ),
              Center(
                  child: Text('@$username',
                      style: Theme.of(context).textTheme.bodySmall)),
              if (bio.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Text(bio, textAlign: TextAlign.center),
                ),
              const SizedBox(height: 16),

              // カウント（自分はフォロー/フォロワーをタップで一覧へ）。
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isSelf)
                    _Stat(
                      label: 'フォロー中',
                      value: provider.myFollowingCount,
                      onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const FollowListScreen(
                                  kind: FollowListKind.following))),
                    ),
                  if (isSelf) const SizedBox(width: 28),
                  _Stat(
                    label: 'フォロワー',
                    value: isSelf
                        ? provider.myFollowerCount
                        : provider.followerCount(uid),
                    onTap: isSelf
                        ? () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const FollowListScreen(
                                kind: FollowListKind.followers)))
                        : null,
                  ),
                  const SizedBox(width: 28),
                  _Stat(label: 'ドロップ', value: drops.length),
                ],
              ),
              const SizedBox(height: 16),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: isSelf
                    ? Column(
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.edit),
                            label: const Text('プロフィールを編集'),
                            onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const ProfileSettingsScreen())),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            icon: const Icon(Icons.logout,
                                color: Colors.redAccent),
                            label: const Text('ログアウト',
                                style: TextStyle(color: Colors.redAccent)),
                            onPressed: () => _logout(context),
                          ),
                        ],
                      )
                    : (following
                        ? OutlinedButton(
                            onPressed: () => provider.toggleFollow(uid),
                            child: const Text('フォロー中'),
                          )
                        : FilledButton(
                            onPressed: () => provider.toggleFollow(uid),
                            child: const Text('フォローする'),
                          )),
              ),
              const Divider(height: 32),

              if (!isSelf && !following)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('フォローすると、この人の公開ドロップを地図と一覧で聴けます。',
                      textAlign: TextAlign.center),
                )
              else if (drops.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(isSelf ? 'まだドロップがありません。' : '公開中のドロップはありません。',
                      textAlign: TextAlign.center),
                )
              else
                ...drops.map((p) => _DropTile(pin: p)),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  final VoidCallback? onTap;
  const _Stat({required this.label, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    final col = Column(
      children: [
        Text('$value',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
    if (onTap == null) return col;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(padding: const EdgeInsets.all(6), child: col),
    );
  }
}

class _DropTile extends StatelessWidget {
  final PinModel pin;
  const _DropTile({required this.pin});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<PinProvider>();
    final playable = provider.canPlay(pin);
    return ListTile(
      leading: Icon(playable ? Icons.graphic_eq : Icons.lock,
          color: playable ? const Color(0xFF2BB3A3) : const Color(0xFF6B72C9)),
      title: Text(pin.title.isEmpty ? '無題のドロップ' : pin.title),
      subtitle: Text(playable ? '解禁済み' : '現地（50m）またはワープで解禁'),
      onTap: () {
        if (!playable) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('現地に近づくかワープチケットで解禁してください')));
          return;
        }
        showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (sheetContext) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(pin.title.isEmpty ? '無題のドロップ' : pin.title,
                    style: Theme.of(sheetContext).textTheme.titleMedium),
                const SizedBox(height: 8),
                MiniWaveform(seed: pin.id, data: pin.waveform, height: 40),
                const SizedBox(height: 8),
                AudioPlayerWidget.fromPin(pin, key: ValueKey(pin.id)),
              ],
            ),
          ),
        );
      },
    );
  }
}
