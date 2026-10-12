import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/account.dart';
import '../state/pin_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/account_tile.dart';
import '../widgets/ui_kit.dart';
import 'accounts_screen.dart';

/// フォロー中／フォロワーの一覧。各行タップで相手のプロフィールへ。
enum FollowListKind { following, followers }

class FollowListScreen extends StatelessWidget {
  final FollowListKind kind;
  const FollowListScreen({super.key, required this.kind});

  @override
  Widget build(BuildContext context) {
    final isFollowing = kind == FollowListKind.following;
    return Scaffold(
      appBar: AppBar(title: Text(isFollowing ? 'フォロー中' : 'フォロワー')),
      body: Consumer<PinProvider>(
        builder: (context, provider, _) {
          final List<Account> list = isFollowing
              ? provider.followingAccounts
              : provider.followerAccounts;
          if (list.isEmpty) {
            return EmptyState(
              icon: isFollowing
                  ? Icons.person_add_alt_rounded
                  : Icons.groups_outlined,
              title: isFollowing ? 'まだ誰もフォローしていません' : 'まだフォロワーがいません',
              message: isFollowing
                  ? 'フォローした人の公開ドロップが\n地図に届くようになります。'
                  : 'ドロップを続けると、\n見つけてもらいやすくなります。',
              action: isFollowing
                  ? GradientButton(
                      icon: const Icon(Icons.search_rounded),
                      label: 'アカウントを探す',
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const AccountsScreen())),
                    )
                  : null,
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              SectionLabel('${list.length}人'),
              AccountListCard(accounts: list),
            ],
          );
        },
      ),
    );
  }
}
