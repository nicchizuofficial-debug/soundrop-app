import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../state/pin_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/user_avatar.dart';

/// 自分のプロフィール設定（表示名・ユーザー名・自己紹介・画像の編集）。
class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  late final TextEditingController _name;
  late final TextEditingController _username;
  late final TextEditingController _bio;
  String _avatarPath = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final u = context.read<PinProvider>().currentUser;
    _name = TextEditingController(text: u?.displayName ?? '');
    _username = TextEditingController(text: u?.username ?? '');
    _bio = TextEditingController(text: u?.bio ?? '');
    _avatarPath = u?.avatarPath ?? '';
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 600, imageQuality: 85);
    if (picked != null) setState(() => _avatarPath = picked.path);
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await context.read<PinProvider>().updateProfile(
            displayName: _name.text,
            username: _username.text,
            bio: _bio.text,
            avatarPath: _avatarPath,
          );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('プロフィールを更新しました')));
        Navigator.pop(context);
      }
    } on AuthException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('更新に失敗しました。通信環境を確認して、もう一度お試しください。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _bio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final u = context.watch<PinProvider>().currentUser;
    final email = u?.email ?? '';
    // 未入力で登録したアカウントは内部用の仮アドレスなので表示しない。
    final showEmail = email.isNotEmpty && !email.endsWith('@sounddrop.app');

    return Scaffold(
      appBar: AppBar(title: const Text('プロフィールを編集')),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: GradientButton(
          label: '保存する',
          loading: _busy,
          onPressed: _save,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Center(
            child: GestureDetector(
              onTap: _pickImage,
              child: Stack(
                children: [
                  UserAvatar(
                    name: _name.text.isEmpty
                        ? (u?.displayName ?? '?')
                        : _name.text,
                    imagePath: _avatarPath,
                    radius: 48,
                    ring: true,
                  ),
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        gradient: AppColors.brand,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.navy, width: 3),
                      ),
                      child: const Icon(Icons.photo_camera_rounded,
                          size: 16, color: AppColors.navy),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Center(
            child:
                TextButton(onPressed: _pickImage, child: const Text('写真を変更')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            maxLength: 30,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: '表示名',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _username,
            maxLength: 20,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'ログインID',
              helperText: '変更すると、次回から新しいIDでログインします',
              helperMaxLines: 2,
              prefixText: '@',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _bio,
            minLines: 3,
            maxLines: 5,
            maxLength: 160,
            decoration: const InputDecoration(
              labelText: '自己紹介',
              alignLabelWithHint: true,
              prefixIcon: Padding(
                padding: EdgeInsets.only(bottom: 52),
                child: Icon(Icons.notes_rounded),
              ),
            ),
          ),
          if (showEmail) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.mail_outline,
                    size: 18, color: AppColors.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('登録メール: $email',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textMuted)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
