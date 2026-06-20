import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/account.dart';
import '../screens/profile_screen.dart';
import '../state/pin_provider.dart';
import '../theme/app_theme.dart';
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

    return ListTile(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ProfileScreen(uid: account.uid),
      )),
      leading: UserAvatar(
          name: account.displayName, imagePath: account.avatarPath, radius: 20),
      title: Row(
        children: [
          Flexible(
              child: Text(account.displayName,
                  overflow: TextOverflow.ellipsis)),
          if (mutual)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.pink.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('相互',
                    style: TextStyle(
                        fontSize: 10,
                        color: AppColors.pink,
                        fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
      subtitle: Text(
          '@${account.username} ・ フォロワー ${provider.followerCount(account.uid)}'),
      trailing: following
          ? OutlinedButton(
              onPressed: () => provider.toggleFollow(account.uid),
              child: const Text('フォロー中'),
            )
          : FilledButton(
              onPressed: () => provider.toggleFollow(account.uid),
              child: const Text('フォロー'),
            ),
    );
  }
}
