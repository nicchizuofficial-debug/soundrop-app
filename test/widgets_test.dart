import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sound_drop/widgets/mini_waveform.dart';
import 'package:sound_drop/widgets/sound_drop_logo.dart';
import 'package:sound_drop/widgets/waveform.dart';

void main() {
  testWidgets('SoundDropLogo が例外なく描画される', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: SoundDropLogo(size: 80))),
      ),
    );
    expect(find.byType(SoundDropLogo), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Waveform は空のとき案内文、データありで描画される', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Waveform(amplitudes: [], color: Colors.pink),
        ),
      ),
    );
    expect(find.textContaining('録音すると波形'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Waveform(
            amplitudes: List.generate(20, (i) => (i % 5) / 5),
            color: Colors.pink,
            active: true,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('MiniWaveform は同じ seed で安定して描画される', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: MiniWaveform(seed: 'pin_001'))),
      ),
    );
    expect(find.byType(MiniWaveform), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
