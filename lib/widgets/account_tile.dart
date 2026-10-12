import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/account.dart';
import '../screens/profile_screen.dart';
import '../state/pin_provider.dart';
import '../theme/app_theme.dart';
import 'ui_kit.dart';
import 'user_avatar.dart';

/// アカウント1件のタイル（タップでプロフィールへ・フォローボタン・相互バッジ）。
class AccountTile extends StatelessWidget {
  final Account account;
  const AccountTile({super.key, required this.account});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PinProvider>();
    final following = provider.isFollowing(account.uid);
    final mutual = provider.isMutual(account.uid);

    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ProfileScreen(uid: account.uid),
      )),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            UserAvatar(
                name: account.displayName,
                imagePath: account.avatarPath,
                radius: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(account.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                      if (mutual) ...[
                        const SizedBox(width: 6),
                        const AppTag(label: '相互', color: AppColors.pink),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@${account.username} ・ フォロワー ${provider.followerCount(account.uid)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted),
                  ),
                  if (account.bio.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(account.bio,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            FollowButton(
              following: following,
              onPressed: () => provider.toggleFollow(account.uid),
            ),
          ],
        ),
      ),
    );
  }
}

/// アカウント一覧（カードに収め、行間に区切り線）。
class AccountListCard extends StatelessWidget {
  final List<Account> accounts;
  const AccountListCard({super.key, required this.accounts});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < accounts.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 78),
            AccountTile(account: accounts[i]),
          ],
        ],
      ),
    );
  }
}
