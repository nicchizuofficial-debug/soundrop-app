import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/pin_provider.dart';
import '../widgets/account_tile.dart';

/// アカウントを検索してフォロー／プロフィール表示する画面。
class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('アカウントを探す')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'ユーザー名・表示名で検索（例: kenta）',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: Consumer<PinProvider>(
              builder: (context, provider, _) {
                final results = provider.searchAccounts(_query);
                if (results.isEmpty) {
                  return const Center(child: Text('該当するアカウントがありません。'));
                }
                return ListView.separated(
                  itemCount: results.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => AccountTile(account: results[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
