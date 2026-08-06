import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:creania/widgets/room/creania_vp_progress_bar.dart';

void main() {
  testWidgets('CreaniaVpProgressBar and Room Total Stars pill render and respond to tap', (WidgetTester tester) async {
    bool starTapped = false;
    int totalStars = 2594;

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
                    starTapped = true;
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$totalStars'),
                        const SizedBox(width: 3.5),
                        const Icon(Icons.star_rounded),
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

    // Verify Room ID text and Star count text are rendered
    expect(find.text('ID: 56754076'), findsOneWidget);
    expect(find.text('2594'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);

    // Tap on the star pill widget
    await tester.tap(find.text('2594'));
    await tester.pump();

    expect(starTapped, isTrue);
  });
}
