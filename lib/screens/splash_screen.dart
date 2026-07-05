import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/pin_provider.dart';
import '../theme/app_theme.dart';
import 'auth_screen.dart';
import 'map_screen.dart';

/// 起動スプラッシュ。ロゴをフェードイン表示しつつ、
/// 永続データ読込（[PinProvider.init]）完了を待って地図へ遷移する。
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  bool _navigated = false;
  late final DateTime _start = DateTime.now();

  @override
  void initState() {
    super.initState();
    // 読込完了とロゴ表示の最小時間（1.2秒）の両方を満たしたら遷移。
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeGo());
  }

  Future<void> _maybeGo() async {
    final provider = context.read<PinProvider>();
    while (mounted && !provider.isLoaded) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    final elapsed = DateTime.now().difference(_start);
    const minShow = Duration(milliseconds: 1200);
    if (elapsed < minShow) {
      await Future<void>.delayed(minShow - elapsed);
    }
    if (!mounted || _navigated) return;
    _navigated = true;
    // 未ログインなら登録／ログイン画面、ログイン済みなら地図へ。
    final authed = context.read<PinProvider>().isAuthenticated;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, __, ___) =>
            authed ? const MapScreen() : const AuthScreen(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
          child: child,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Center(
        child: FadeTransition(
          opacity: _ctrl,
          child: ScaleTransition(
            scale: Tween(begin: 0.8, end: 1.0).animate(
              CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // アプリアイコン（添付画像）をそのまま表示。
                // 画像の背景がスプラッシュと同じ navy なので自然に馴染む。
                Image.asset(
                  'assets/icon/app_icon_custom.png',
                  width: 160,
                  height: 160,
                  filterQuality: FilterQuality.medium,
                ),
                const SizedBox(height: 20),
                const GradientMask(
                  child: Text(
                    'SounDrop',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'その場所に、音を落とす。',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
