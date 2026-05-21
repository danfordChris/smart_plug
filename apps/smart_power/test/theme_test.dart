import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:smart_power/config/theme.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  test('AppRadii values match the design spec', () {
    expect(AppRadii.card, 16.0);
    expect(AppRadii.cardLarge, 20.0);
    expect(AppRadii.heroIcon, 28.0);
    expect(AppRadii.button, 24.0);
    expect(AppRadii.sheet, 28.0);
    expect(AppRadii.fab, 16.0);
  });

  test('AppSpacing scale is monotonic', () {
    expect(AppSpacing.xs, lessThan(AppSpacing.s));
    expect(AppSpacing.s, lessThan(AppSpacing.m));
    expect(AppSpacing.m, lessThan(AppSpacing.l));
    expect(AppSpacing.l, lessThan(AppSpacing.xl));
    expect(AppSpacing.xl, lessThan(AppSpacing.xxl));
  });

  test('AppColors seed matches forest green', () {
    expect(AppColors.seed, const Color(0xFF1F8A5B));
  });

  test('Motion durations stay within 200-320ms band', () {
    final motions = [
      AppMotion.cardGlyph,
      AppMotion.bigSwitchPanel,
      AppMotion.statTile,
      AppMotion.sparkline,
    ];
    for (final m in motions) {
      expect(m.inMilliseconds, inInclusiveRange(200, 320));
    }
  });
}
