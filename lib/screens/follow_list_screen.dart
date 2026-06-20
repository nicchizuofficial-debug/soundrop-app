import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/account.dart';
import '../state/pin_provider.dart';
import '../widgets/account_tile.dart';

/// フォロー中／フォロワーの一覧。各行タップで相手のプロフィールへ。
enum FollowListKind { following, followers }

class FollowListScreen extends StatelessWidget {
  final FollowListKind kind;
  const FollowListScreen({super.key, required this.kind});

  @override
  Widget build(BuildContext context) {
    final title = kind == FollowListKind.following ? 'フォロー中' : 'フォロワー';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Consumer<PinProvider>(
        builder: (context, provider, _) {
          final List<Account> list = kind == FollowListKind.following
              ? provider.followingAccounts
              : provider.followerAccounts;
          if (list.isEmpty) {
            return Center(
              child: Text(kind == FollowListKind.following
                  ? 'まだ誰もフォローしていません。'
                  : 'まだフォロワーがいません。'),
            );
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => AccountTile(account: list[i]),
          );
        },
      ),
    );
  }
}
