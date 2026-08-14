import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../state/pin_provider.dart';
import '../theme/app_theme.dart';
import 'legal_screen.dart';
import 'map_screen.dart';

/// メールアドレスでのアカウント登録／ログイン画面（利用に必須）。
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();

  bool _isLogin = false; // false=新規登録, true=ログイン
  bool _busy = false;
  bool _agreed = false; // 規約・プライバシー同意（新規登録時必須）
  String? _error;

  final ButtonStyle _denseBtn = TextButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 2),
    minimumSize: Size.zero,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  Future<void> _submit() async {
    if (!_isLogin && !_agreed) {
      setState(() => _error = '利用規約とプライバシーポリシーへの同意が必要です');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final provider = context.read<PinProvider>();
    try {
      if (_isLogin) {
        await provider.signIn(
            username: _username.text, password: _password.text);
      } else {
        await provider.signUp(
          username: _username.text,
          password: _password.text,
          displayName: _name.text,
          email: _email.text,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MapScreen()),
      );
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '処理に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// ログインIDを入力してもらい、パスワード再設定メールを送る。
  Future<void> _showForgotPasswordDialog() async {
    final controller = TextEditingController(text: _username.text);
    final username = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('パスワードの再設定'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'ログインID（例: kenta）',
            prefixText: '@',
            prefixIcon: Icon(Icons.alternate_email),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('再設定メールを送る'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (username == null || username.trim().isEmpty || !mounted) return;

    try {
      await context.read<PinProvider>().sendPasswordReset(username.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('登録済みのメールアドレスに再設定用メールを送信しました')));
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('送信に失敗しました: $e')));
    }
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(
                  child: Image(
                    image: AssetImage('assets/icon/app_icon_custom.png'),
                    width: 104,
                    height: 104,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: GradientMask(
                    child: Text(_isLogin ? 'おかえりなさい' : 'アカウント登録',
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                      _isLogin
                          ? 'ログインID（@なし）とパスワードでログイン'
                          : 'フォローした人のドロップだけが届きます',
                      style: Theme.of(context).textTheme.bodySmall),
                ),
                const SizedBox(height: 24),

                if (!_isLogin)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextField(
                      controller: _name,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: '表示名',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                // ログインID（一意）。
                TextField(
                  controller: _username,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'ログインID（例: kenta）',
                    prefixText: '@',
                    prefixIcon: Icon(Icons.alternate_email),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                if (!_isLogin) ...[
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'メールアドレス（任意）',
                      prefixIcon: Icon(Icons.mail_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'パスワード（6文字以上）',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_isLogin)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      style: _denseBtn,
                      onPressed: _busy ? null : _showForgotPasswordDialog,
                      child: const Text('パスワードをお忘れですか？'),
                    ),
                  ),
                if (!_isLogin) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Checkbox(
                        value: _agreed,
                        onChanged: (v) =>
                            setState(() => _agreed = v ?? false),
                      ),
                      Expanded(
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text('', style: TextStyle(fontSize: 12)),
                            TextButton(
                              style: _denseBtn,
                              onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => LegalScreen.terms())),
                              child: const Text('利用規約'),
                            ),
                            const Text('・', style: TextStyle(fontSize: 12)),
                            TextButton(
                              style: _denseBtn,
                              onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => LegalScreen.privacy())),
                              child: const Text('プライバシーポリシー'),
                            ),
                            const Text('に同意', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      style: const TextStyle(color: Colors.redAccent)),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: _busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child:
                                CircularProgressIndicator(strokeWidth: 2))
                        : Text(_isLogin ? 'ログイン' : '登録して始める'),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _isLogin = !_isLogin;
                            _error = null;
                          }),
                  child: Text(_isLogin
                      ? 'アカウントが無い方はこちら（新規登録）'
                      : '既にアカウントをお持ちの方はこちら（ログイン）'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
