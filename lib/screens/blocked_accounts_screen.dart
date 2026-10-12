import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/pin_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';
import '../widgets/user_avatar.dart';

/// ブロック中のアカウント一覧（解除可能）。
class BlockedAccountsScreen extends StatelessWidget {
  const BlockedAccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ブロックしたアカウント')),
      body: Consumer<PinProvider>(
        builder: (context, provider, _) {
          final blocked = provider.blockedAccounts;
          if (blocked.isEmpty) {
            return const EmptyState(
              icon: Icons.shield_outlined,
              title: 'ブロック中のアカウントはありません',
              message: 'ドロップの「…」メニューから\n投稿者をブロックできます。',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              const SectionLabel('ブロック中の人の投稿は表示されません'),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var i = 0; i < blocked.length; i++) ...[
                      if (i > 0) const Divider(height: 1, indent: 72),
                      ListTile(
                        contentPadding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
                        leading: UserAvatar(name: blocked[i].name, radius: 22),
                        title: Text(blocked[i].name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: const Text('ブロック中',
                            style: TextStyle(color: AppColors.textMuted)),
                        trailing: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(72, 36),
                            shape: const StadiumBorder(),
                          ),
                          onPressed: () =>
                              provider.unblockAuthor(blocked[i].uid),
                          child: const Text('解除'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
