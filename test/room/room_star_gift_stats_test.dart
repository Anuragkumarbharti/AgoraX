import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:creania/widgets/room/creania_vp_progress_bar.dart';
import 'package:creania/widgets/gems/gem_widgets.dart';

void main() {
  testWidgets('CreaniaVpProgressBar and Room Total Gems pill render and respond to tap', (WidgetTester tester) async {
    bool gemTapped = false;
    int totalGems = 2594;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: const CreaniaVpProgressBar(
                  roomId: '56754076',
                  roomName: 'sukoon ❤️',
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 32),
                child: GestureDetector(
                  onTap: () {
                    gemTapped = true;
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$totalGems'),
                        const SizedBox(width: 3.5),
                        const GemIcon(size: 14),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Verify Room ID text and Gem count text are rendered
    expect(find.text('ID: 56754076'), findsOneWidget);
    expect(find.text('2594'), findsOneWidget);
    expect(find.byType(GemIcon), findsOneWidget);

    // Tap on the gem pill widget
    await tester.tap(find.text('2594'));
    await tester.pump();

    expect(gemTapped, isTrue);
  });
}
