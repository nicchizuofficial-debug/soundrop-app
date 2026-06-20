import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/pin_provider.dart';
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
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'ブロック中のアカウントはありません。\n'
                  '投稿の「…」メニューからブロックできます。',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: blocked.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final b = blocked[i];
              return ListTile(
                leading: UserAvatar(name: b.name, radius: 20),
                title: Text(b.name),
                subtitle: const Text('ブロック中（投稿は非表示）'),
                trailing: OutlinedButton(
                  onPressed: () => provider.unblockAuthor(b.uid),
                  child: const Text('解除'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
