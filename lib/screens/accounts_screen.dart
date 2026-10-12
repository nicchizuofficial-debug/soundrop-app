import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/pin_provider.dart';
import '../widgets/account_tile.dart';
import '../widgets/ui_kit.dart';

/// アカウントを検索してフォロー／プロフィール表示する画面。
class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searching = _query.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('アカウントを探す')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextField(
              controller: _controller,
              autocorrect: false,
              textInputAction: TextInputAction.search,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'ユーザー名・表示名で検索',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: searching
                    ? IconButton(
                        tooltip: 'クリア',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(() {
                          _controller.clear();
                          _query = '';
                        }),
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: Consumer<PinProvider>(
              builder: (context, provider, _) {
                final results = provider.searchAccounts(_query);
                if (results.isEmpty) {
                  return searching
                      ? EmptyState(
                          icon: Icons.search_off_rounded,
                          title: '「${_query.trim()}」は見つかりませんでした',
                          message: 'ログインID（@のあと）か\n表示名で検索してみてください。',
                        )
                      : const EmptyState(
                          icon: Icons.person_search_rounded,
                          title: '友だちを探してみましょう',
                          message: 'ログインIDや表示名で検索して、\nフォローした人のドロップが地図に届きます。',
                        );
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    // 未入力時は公式アカウントだけを出している（searchAccounts 参照）。
                    SectionLabel(
                        searching ? '検索結果 ${results.length}件' : 'おすすめ'),
                    AccountListCard(accounts: results),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
