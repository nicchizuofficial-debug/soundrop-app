import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/privacy_settings.dart';
import '../models/app_user.dart';
import '../state/pin_provider.dart';
import '../theme/app_theme.dart';
import '../app_config.dart';
import 'auth_screen.dart';
import 'blocked_accounts_screen.dart';
import 'creator_earnings_screen.dart';
import 'legal_screen.dart';
import 'profile_settings_screen.dart';
import '../widgets/ui_kit.dart';
import '../widgets/user_avatar.dart';

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
            padding: const EdgeInsets.only(top: 8, bottom: 32),
            children: [
              // ---- アカウント（プロフィールへの入口をカード化） ----
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    contentPadding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
                    leading: UserAvatar(
                      name: user?.displayName ?? '',
                      imagePath: user?.avatarPath ?? '',
                      radius: 24,
                      ring: true,
                    ),
                    title: Text(user?.displayName ?? '',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    subtitle: Text('@${user?.username ?? ''}',
                        style: const TextStyle(color: AppColors.textMuted)),
                    trailing: const Text('編集',
                        style: TextStyle(
                            color: AppColors.blue,
                            fontWeight: FontWeight.w700)),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const ProfileSettingsScreen())),
                  ),
                ),
              ),

              SectionCard(
                title: 'アカウント',
                children: [
                  ListTile(
                    leading: const Icon(Icons.local_fire_department_outlined),
                    title: const Text('連続ログイン'),
                    subtitle: const Text('7日続けるとワープチケット1枚'),
                    trailing: AppTag(
                        label: '${provider.loginStreak}日',
                        color: AppColors.pending),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.lock_outline),
                    title: const Text('非公開アカウント'),
                    subtitle: const Text('フォローを承認制にする'),
                    value: p.protectedAccount,
                    onChanged: (v) =>
                        provider.updatePrivacy(p.copyWith(protectedAccount: v)),
                  ),
                ],
              ),

              SectionCard(
                title: 'ドロップの公開範囲',
                children: [
                  _RadioRow<DropVisibility>(
                    icon: Icons.groups_outlined,
                    title: 'フォロワーに公開',
                    value: DropVisibility.followers,
                    group: p.visibility,
                    onChanged: (v) =>
                        provider.updatePrivacy(p.copyWith(visibility: v)),
                  ),
                  _RadioRow<DropVisibility>(
                    icon: Icons.sync_alt_rounded,
                    title: '相互フォローのみ',
                    value: DropVisibility.mutual,
                    group: p.visibility,
                    onChanged: (v) =>
                        provider.updatePrivacy(p.copyWith(visibility: v)),
                  ),
                ],
              ),

              SectionCard(
                title: '位置情報（防犯）',
                children: [
                  _RadioRow<LocationPrecision>(
                    icon: Icons.my_location_rounded,
                    title: '正確な位置',
                    subtitle: '現地でぴったり解禁できる',
                    value: LocationPrecision.exact,
                    group: p.locationPrecision,
                    onChanged: (v) => provider
                        .updatePrivacy(p.copyWith(locationPrecision: v)),
                  ),
                  _RadioRow<LocationPrecision>(
                    icon: Icons.blur_on_rounded,
                    title: 'おおよその位置',
                    subtitle: '約100mぼかして自宅の特定を防ぐ',
                    value: LocationPrecision.approximate,
                    group: p.locationPrecision,
                    onChanged: (v) => provider
                        .updatePrivacy(p.copyWith(locationPrecision: v)),
                  ),
                ],
              ),

              SectionCard(
                title: 'プライバシーと安全',
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.alternate_email),
                    title: const Text('ユーザー名で検索を許可'),
                    value: p.findableByUsername,
                    onChanged: (v) => provider
                        .updatePrivacy(p.copyWith(findableByUsername: v)),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.mail_outline),
                    title: const Text('メールアドレスで検索を許可'),
                    value: p.findableByEmail,
                    onChanged: (v) =>
                        provider.updatePrivacy(p.copyWith(findableByEmail: v)),
                  ),
                  ListTile(
                    leading: const Icon(Icons.block),
                    title: const Text('ブロックしたアカウント'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${provider.blockedAccounts.length}',
                            style: const TextStyle(color: AppColors.textMuted)),
                        const Icon(Icons.chevron_right_rounded,
                            color: AppColors.textMuted),
                      ],
                    ),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const BlockedAccountsScreen())),
                  ),
                ],
              ),

              if (AppConfig.enableTipping)
                SectionCard(
                  title: 'クリエイター',
                  children: [
                    ListTile(
                      leading: const Icon(Icons.payments_outlined),
                      title: const Text('収益・受け取り'),
                      subtitle: const Text('応援の総額・受け取り見込み・出金設定'),
                      trailing: const Icon(Icons.chevron_right_rounded,
                          color: AppColors.textMuted),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const CreatorEarningsScreen())),
                    ),
                  ],
                ),

              SectionCard(
                title: '情報',
                children: [
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('利用規約'),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textMuted),
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => LegalScreen.terms())),
                  ),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('プライバシーポリシー'),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textMuted),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => LegalScreen.privacy())),
                  ),
                ],
              ),

              SectionCard(
                children: [
                  ListTile(
                    leading: const Icon(Icons.logout, color: AppColors.danger),
                    title: const Text('ログアウト',
                        style: TextStyle(color: AppColors.danger)),
                    onTap: () => _logout(context),
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_forever_outlined,
                        color: AppColors.danger),
                    title: const Text('アカウントを削除',
                        style: TextStyle(color: AppColors.danger)),
                    subtitle: const Text('投稿・フォロー等のデータを完全に削除します'),
                    onTap: () => _deleteAccount(context),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    await context.read<PinProvider>().signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final password = await showDialog<String>(
      context: context,
      builder: (_) => const _DeleteAccountDialog(),
    );
    if (password == null || !context.mounted) return;

    // 削除処理中は操作できないようにローディングを出す。
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
    String? error;
    try {
      await context.read<PinProvider>().deleteAccount(password: password);
    } on AuthException catch (e) {
      error = e.message;
    } catch (_) {
      error = '削除に失敗しました。通信環境を確認して、もう一度お試しください。';
    }
    if (!context.mounted) return;
    Navigator.of(context).pop(); // ローディングを閉じる
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }
}

/// 退会確認ダイアログ。本人確認のためパスワードを入力してもらう。
/// 「削除する」でパスワード文字列、キャンセルで null を返す。
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('アカウントを削除'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('アカウントと、あなたの投稿・フォロー等のデータを完全に削除します。\n'
              'この操作は取り消せません。'),
          const SizedBox(height: 16),
          TextField(
            controller: _password,
            obscureText: true,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '確認のためパスワードを入力',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
          onPressed: _password.text.isEmpty
              ? null
              : () => Navigator.pop(context, _password.text),
          child: const Text('削除する'),
        ),
      ],
    );
  }
}

/// アイコン付きのラジオ行（SectionCard 内で ListTile と揃える）。
class _RadioRow<T> extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final T value;
  final T group;
  final ValueChanged<T?> onChanged;

  const _RadioRow({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.group,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == group;
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        child: selected
            ? const Icon(Icons.check_circle_rounded,
                key: ValueKey(true), color: AppColors.blue)
            : const Icon(Icons.circle_outlined,
                key: ValueKey(false), color: AppColors.outline),
      ),
      onTap: () => onChanged(value),
    );
  }
}
