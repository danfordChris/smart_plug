import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:smart_power/widgets/insight_card.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('InsightCard renders title + description', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF1F8A5B),
            ),
          ),
          home: const Scaffold(
            body: InsightCard(
              icon: HugeIcons.strokeRoundedFlash,
              tint: Color(0xFFD8A12B),
              title: 'Voltage stability',
              description: 'Operating around 223 V.',
              action: 'Check now',
            ),
          ),
        ),
      ),
    );
    expect(find.text('Voltage stability'), findsOneWidget);
    expect(find.text('Operating around 223 V.'), findsOneWidget);
    expect(find.text('Check now'), findsOneWidget);
  });
}
