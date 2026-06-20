import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/pin_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icons.dart';

/// クリエイター収益ダッシュボード（応援された側への還元の見える化＋出金導線）。
///
/// 手数料率は仮の既定値。実際は App Store/Google の手数料・プラン・国で変動する。
class CreatorEarningsScreen extends StatelessWidget {
  const CreatorEarningsScreen({super.key});

  // 仮の手数料率（docs/payouts.md 参照）。
  static const double storeFeeRate = 0.30; // Apple/Google
  static const double platformFeeRate = 0.10; // 運営

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('収益・受け取り')),
      body: Consumer<PinProvider>(
        builder: (context, provider, _) {
          final gross = provider.myGrossEarnings;
          final gifts = provider.myGiftsReceived;
          final net =
              (gross * (1 - storeFeeRate) * (1 - platformFeeRate)).round();

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // 受取見込みカード。
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.brand,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('受け取り見込み額',
                        style: TextStyle(color: AppColors.navy, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('¥$net',
                        style: const TextStyle(
                            color: AppColors.navy,
                            fontSize: 34,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('応援総額 ¥$gross ・ $gifts 件',
                        style: const TextStyle(
                            color: AppColors.navy, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 内訳。
              _row('応援総額（グロス）', '¥$gross'),
              _row('ストア手数料（${(storeFeeRate * 100).round()}%）',
                  '−¥${(gross * storeFeeRate).round()}'),
              _row('運営手数料（${(platformFeeRate * 100).round()}%）',
                  '−¥${(gross * (1 - storeFeeRate) * platformFeeRate).round()}'),
              const Divider(),
              _row('受け取り見込み', '¥$net', bold: true),
              const SizedBox(height: 24),

              // 出金導線（Stripe Connect オンボーディング）。
              FilledButton.icon(
                icon: const Icon(Icons.account_balance),
                label: const Text('受け取り方法を設定'),
                onPressed: () => _setupPayout(context),
              ),
              const SizedBox(height: 8),
              const Text(
                '銀行口座での受け取りには Stripe Connect での本人確認(KYC)が必要です。'
                'サーバーでの購入検証・台帳と合わせて順次提供します。',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const GradientIcon(AppIcons.support, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('応援してくれたファンに感謝を伝えましょう。',
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    fontWeight: bold ? FontWeight.w700 : FontWeight.normal)),
            Text(value,
                style: TextStyle(
                    fontWeight: bold ? FontWeight.w700 : FontWeight.normal)),
          ],
        ),
      );

  Future<void> _setupPayout(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final url = await context.read<PinProvider>().payout.onboardingUrl();
    if (url == null) {
      messenger.showSnackBar(const SnackBar(
          content: Text('出金（Stripe Connect）はバックエンド準備後に有効化されます')));
      return;
    }
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      messenger.showSnackBar(
          const SnackBar(content: Text('受け取り設定ページを開けませんでした')));
    }
  }
}
