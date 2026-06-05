import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:smart_power/screens/welcome_screen.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('Welcome screen shows brand + entry points + socials',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1F8A5B)),
          ),
          home: const WelcomeScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('SMART'), findsOneWidget);
    expect(find.text('POWER'), findsOneWidget);
    expect(find.text('Your smart energy companion'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Register Account'), findsOneWidget);
    expect(find.text('OR'), findsOneWidget);
    expect(find.text('Connect With Us'), findsOneWidget);
  });
}
