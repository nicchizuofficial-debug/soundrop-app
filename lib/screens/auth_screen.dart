import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _obscure = true; // パスワードの伏せ字表示
  String? _error;

  final ButtonStyle _denseBtn = TextButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 2),
    minimumSize: Size.zero,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_username.text.trim().isEmpty) {
      setState(() => _error = 'ログインIDを入力してください');
      return;
    }
    if (_password.text.isEmpty) {
      setState(() => _error = 'パスワードを入力してください');
      return;
    }
    if (!_isLogin && !_agreed) {
      setState(() => _error = 'ご利用には規約への同意が必要です');
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
      // 成功したID・パスワードをキーチェーン等へ保存するよう OS に伝える。
      TextInput.finishAutofillContext();
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
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('登録済みのメールアドレスに再設定用メールを送信しました')));
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
    final muted = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: AppColors.textMuted, height: 1.5);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: ConstrainedBox(
              // iPad でも入力欄が横に間延びしないよう幅を抑える。
              constraints: const BoxConstraints(maxWidth: 440),
              // iOS のキーチェーン／Android の自動入力にID・パスワードを渡す。
              child: AutofillGroup(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                      child: Image(
                        image: AssetImage('assets/icon/app_icon_custom.png'),
                        width: 96,
                        height: 96,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: GradientMask(
                        child: Text(_isLogin ? 'おかえりなさい' : 'はじめまして',
                            style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isLogin ? 'ログインIDとパスワードでログイン' : 'フォローした人のドロップだけが届きます',
                      textAlign: TextAlign.center,
                      style: muted,
                    ),
                    const SizedBox(height: 28),

                    // モード切替は入力欄の上に置き、今どちらの画面かを明確にする。
                    SegmentedButton<bool>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: false, label: Text('新規登録')),
                        ButtonSegment(value: true, label: Text('ログイン')),
                      ],
                      selected: {_isLogin},
                      onSelectionChanged: _busy
                          ? null
                          : (s) => setState(() {
                                _isLogin = s.first;
                                _error = null;
                              }),
                    ),
                    const SizedBox(height: 20),

                    if (!_isLogin) ...[
                      TextField(
                        controller: _name,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.nickname],
                        decoration: const InputDecoration(
                          labelText: '表示名',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    // ログインID（一意）。
                    TextField(
                      controller: _username,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      enableSuggestions: false,
                      autofillHints: [
                        _isLogin
                            ? AutofillHints.username
                            : AutofillHints.newUsername
                      ],
                      decoration: const InputDecoration(
                        labelText: 'ログインID（例: kenta）',
                        prefixText: '@',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (!_isLogin) ...[
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'メールアドレス（任意）',
                          helperText: 'パスワードを忘れたときの再設定に使います',
                          prefixIcon: Icon(Icons.mail_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: _password,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      autocorrect: false,
                      enableSuggestions: false,
                      autofillHints: [
                        _isLogin
                            ? AutofillHints.password
                            : AutofillHints.newPassword
                      ],
                      onSubmitted: (_) => _busy ? null : _submit(),
                      decoration: InputDecoration(
                        labelText: _isLogin ? 'パスワード' : 'パスワード（6文字以上）',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _obscure ? 'パスワードを表示' : 'パスワードを隠す',
                          icon: Icon(_obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),
                    if (_isLogin)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _busy ? null : _showForgotPasswordDialog,
                          child: const Text('パスワードをお忘れですか？'),
                        ),
                      ),
                    if (!_isLogin) ...[
                      const SizedBox(height: 8),
                      // 行全体をタップで同意を切り替えられるようにする（チェックボックスが小さいため）。
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() => _agreed = !_agreed),
                        child: Row(
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
                                  TextButton(
                                    style: _denseBtn,
                                    onPressed: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                LegalScreen.terms())),
                                    child: const Text('利用規約'),
                                  ),
                                  const Text('・',
                                      style: TextStyle(fontSize: 13)),
                                  TextButton(
                                    style: _denseBtn,
                                    onPressed: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                LegalScreen.privacy())),
                                    child: const Text('プライバシーポリシー'),
                                  ),
                                  const Text('に同意する',
                                      style: TextStyle(fontSize: 13)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    AnimatedSize(
                      duration: const Duration(milliseconds: 180),
                      child: _error == null
                          ? const SizedBox(width: double.infinity)
                          : Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: _ErrorCard(message: _error!),
                            ),
                    ),
                    const SizedBox(height: 24),
                    GradientButton(
                      label: _isLogin ? 'ログイン' : '登録して始める',
                      loading: _busy,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// フォーム下に出すエラー表示（アイコン付きの淡い赤カード）。
class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.field),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(fontSize: 13, height: 1.5)),
          ),
        ],
      ),
    );
  }
}
