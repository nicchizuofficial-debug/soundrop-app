import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_config.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'state/pin_provider.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // USE_FIREBASE=true のときのみ初期化。
  // flutterfire configure が生成した firebase_options.dart を渡すことで、
  // Gradle プラグイン設定なしで全プラットフォーム確実に初期化できる。
  if (AppConfig.useFirebase) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  runApp(const SoundDropApp());
}

class SoundDropApp extends StatelessWidget {
  const SoundDropApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      // 永続データの読込と課金の初期化を起動時に行う。
      create: (_) => PinProvider()..init(),
      child: MaterialApp(
        title: 'SounDrop',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const SplashScreen(),
      ),
    );
  }
}
