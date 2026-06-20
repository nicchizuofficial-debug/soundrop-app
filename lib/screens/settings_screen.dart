import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/privacy_settings.dart';
import '../state/pin_provider.dart';
import '../theme/app_theme.dart';
import '../app_config.dart';
import 'auth_screen.dart';
import 'blocked_accounts_screen.dart';
import 'creator_earnings_screen.dart';
import 'legal_screen.dart';
import 'profile_settings_screen.dart';

/// 設定画面（X等を参考にしたプライバシー・安全設定）。
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: Consumer<PinProvider>(
        builder: (context, provider, _) {
          final p = provider.privacy;
          final user = provider.currentUser;

          return ListView(
            children: [
              _header('アカウント'),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('プロフィール'),
                subtitle: Text('@${user?.username ?? ''}・${user?.email ?? ''}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const ProfileSettingsScreen())),
              ),
              ListTile(
                leading: const Icon(Icons.local_fire_department_outlined),
                title: const Text('連続ログイン'),
                subtitle: const Text('7日ごとにワープチケット1枚プレゼント'),
                trailing: Text('${provider.loginStreak}日',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.lock_outline),
                title: const Text('非公開アカウント'),
                subtitle: const Text('フォローを承認制にする'),
                value: p.protectedAccount,
                onChanged: (v) => provider
                    .updatePrivacy(p.copyWith(protectedAccount: v)),
              ),

              _header('プライバシーと安全'),
              ListTile(
                leading: const Icon(Icons.block),
                title: const Text('ブロックしたアカウント'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${provider.blockedAccounts.length}',
                        style: Theme.of(context).textTheme.bodySmall),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const BlockedAccountsScreen())),
              ),
              const _SubHeader('ドロップの公開範囲'),
              RadioListTile<DropVisibility>(
                title: const Text('フォロワーに公開'),
                value: DropVisibility.followers,
                groupValue: p.visibility,
                onChanged: (v) =>
                    provider.updatePrivacy(p.copyWith(visibility: v)),
              ),
              RadioListTile<DropVisibility>(
                title: const Text('相互フォローのみ'),
                value: DropVisibility.mutual,
                groupValue: p.visibility,
                onChanged: (v) =>
                    provider.updatePrivacy(p.copyWith(visibility: v)),
              ),
              const _SubHeader('見つけやすさ'),
              SwitchListTile(
                title: const Text('ユーザー名で検索を許可'),
                value: p.findableByUsername,
                onChanged: (v) => provider
                    .updatePrivacy(p.copyWith(findableByUsername: v)),
              ),
              SwitchListTile(
                title: const Text('メールアドレスで検索を許可'),
                value: p.findableByEmail,
                onChanged: (v) =>
                    provider.updatePrivacy(p.copyWith(findableByEmail: v)),
              ),
              const _SubHeader('位置情報（防犯）'),
              RadioListTile<LocationPrecision>(
                title: const Text('正確な位置'),
                subtitle: const Text('現地でぴったり解禁できる'),
                value: LocationPrecision.exact,
                groupValue: p.locationPrecision,
                onChanged: (v) =>
                    provider.updatePrivacy(p.copyWith(locationPrecision: v)),
              ),
              RadioListTile<LocationPrecision>(
                title: const Text('おおよその位置（約100mぼかし）'),
                subtitle: const Text('自宅などの特定を防ぐ'),
                value: LocationPrecision.approximate,
                groupValue: p.locationPrecision,
                onChanged: (v) =>
                    provider.updatePrivacy(p.copyWith(locationPrecision: v)),
              ),

              if (AppConfig.enableTipping) ...[
                _header('クリエイター'),
                ListTile(
                  leading: const Icon(Icons.payments_outlined),
                  title: const Text('収益・受け取り'),
                  subtitle: const Text('応援の総額・受け取り見込み・出金設定'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const CreatorEarningsScreen())),
                ),
              ],

              _header('情報'),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('利用規約'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => LegalScreen.terms())),
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('プライバシーポリシー'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => LegalScreen.privacy())),
              ),

              _header('その他'),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text('ログアウト',
                    style: TextStyle(color: Colors.redAccent)),
                onTap: () => _logout(context),
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
                title: const Text('アカウントを削除',
                    style: TextStyle(color: Colors.redAccent)),
                subtitle: const Text('投稿・フォロー等のデータを完全に削除します'),
                onTap: () => _deleteAccount(context),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _header(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
        child: Text(text,
            style: const TextStyle(
                color: AppColors.pink,
                fontWeight: FontWeight.w700,
                fontSize: 13)),
      );

  Future<void> _logout(BuildContext context) async {
    await context.read<PinProvider>().signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('アカウントを削除'),
        content: const Text(
            'アカウントと、あなたの投稿・フォロー等のデータを完全に削除します。\n'
            'この操作は取り消せません。続行しますか？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('キャンセル')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(d, true),
            child: const Text('削除する'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;
    await context.read<PinProvider>().deleteAccount();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }
}

class _SubHeader extends StatelessWidget {
  final String text;
  const _SubHeader(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
        child: Text(text, style: Theme.of(context).textTheme.bodySmall),
      );
}
