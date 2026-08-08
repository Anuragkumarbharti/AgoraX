import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:creania/widgets/voice/single_voice_ripple.dart';

void main() {
  testWidgets('SingleVoiceRipple renders and maintains zero layout impact',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 50,
            height: 50,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: SingleVoiceRipple(
                    isSpeaking: true,
                    soundLevel: 25.0,
                    baseSize: 50.0,
                  ),
                ),
                SizedBox(width: 50, height: 50),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(SingleVoiceRipple), findsOneWidget);

    final Size boxSize = tester.getSize(find.byType(SizedBox).first);
    expect(boxSize.width, 50.0);
    expect(boxSize.height, 50.0);
  });
}
