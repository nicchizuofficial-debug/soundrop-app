import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../state/pin_provider.dart';
import '../widgets/user_avatar.dart';

/// 自分のプロフィール設定（表示名・ユーザー名・自己紹介の編集）。
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
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, maxWidth: 600, imageQuality: 85);
    if (picked != null) setState(() => _avatarPath = picked.path);
  }

  Future<void> _save() async {
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('更新に失敗しました: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
    final provider = context.watch<PinProvider>();
    final u = provider.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('プロフィール設定')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Stack(
              children: [
                UserAvatar(
                  name: _name.text.isEmpty ? (u?.displayName ?? '?') : _name.text,
                  imagePath: _avatarPath,
                  radius: 40,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Material(
                    color: Theme.of(context).colorScheme.primary,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _pickImage,
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.camera_alt, size: 16, color: Colors.black),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: TextButton(
                onPressed: _pickImage, child: const Text('画像を変更')),
          ),
          const SizedBox(height: 4),
          Center(child: Text(u?.email ?? '')),
          const SizedBox(height: 16),
          // フォロー数 / フォロワー数。
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Stat(label: 'フォロー', value: provider.myFollowingCount),
              const SizedBox(width: 32),
              _Stat(label: 'フォロワー', value: provider.myFollowerCount),
            ],
          ),
          const Divider(height: 32),
          TextField(
            controller: _name,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: '表示名',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _username,
            decoration: const InputDecoration(
              labelText: 'ユーザー名（@なしで入力）',
              prefixText: '@',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bio,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: '自己紹介',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('保存'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$value',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
