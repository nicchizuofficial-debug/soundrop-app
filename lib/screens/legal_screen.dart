import 'package:flutter/material.dart';

import '../legal/legal_texts.dart';

/// 利用規約／プライバシーポリシー表示。
class LegalScreen extends StatelessWidget {
  final String title;
  final String body;
  const LegalScreen({super.key, required this.title, required this.body});

  factory LegalScreen.terms() =>
      const LegalScreen(title: '利用規約', body: kTermsJa);
  factory LegalScreen.privacy() =>
      const LegalScreen(title: 'プライバシーポリシー', body: kPrivacyJa);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: SelectableText(body,
            style: const TextStyle(fontSize: 13, height: 1.6)),
      ),
    );
  }
}
