import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinking_fund_app/core/utils/cutoff_calculator.dart';

void main() {
  group('CutoffCalculator.compute', () {
    test('first day of month - both cutoffs later this month', () {
      final info = CutoffCalculator.compute(
        now: DateTime(2026, 6, 1),
        cutoffDay1: 13,
        cutoffDay2: 28,
      );
      expect(info.state, CutoffState.normal);
      expect(info.daysUntilNext, 12);
      expect(info.daysSincePrev, 0);
      expect(info.nextCutoffDay, 13);
      expect(info.prevCutoffDay, null);
    });

    test('two days before first cutoff - near deadline', () {
      final info = CutoffCalculator.compute(
        now: DateTime(2026, 6, 11),
        cutoffDay1: 13,
        cutoffDay2: 28,
      );
      expect(info.state, CutoffState.nearDeadline);
      expect(info.daysUntilNext, 2);
    });

    test('on first cutoff day - due today', () {
      final info = CutoffCalculator.compute(
        now: DateTime(2026, 6, 13),
        cutoffDay1: 13,
        cutoffDay2: 28,
      );
      expect(info.state, CutoffState.dueToday);
      expect(info.daysUntilNext, 0);
    });

    test('two days after first cutoff - just passed', () {
      final info = CutoffCalculator.compute(
        now: DateTime(2026, 6, 15),
        cutoffDay1: 13,
        cutoffDay2: 28,
      );
      expect(info.state, CutoffState.justPassed);
      expect(info.daysSincePrev, 2);
      expect(info.nextCutoffDay, 28);
    });

    test('one day before second cutoff - near deadline', () {
      final info = CutoffCalculator.compute(
        now: DateTime(2026, 6, 27),
        cutoffDay1: 13,
        cutoffDay2: 28,
      );
      expect(info.state, CutoffState.nearDeadline);
      expect(info.daysUntilNext, 1);
    });

    test('day after both cutoffs passed this month - just passed with prev=28', () {
      final info = CutoffCalculator.compute(
        now: DateTime(2026, 6, 29),
        cutoffDay1: 13,
        cutoffDay2: 28,
      );
      expect(info.state, CutoffState.justPassed);
      expect(info.prevCutoffDay, 28);
      expect(info.daysSincePrev, 1);
    });

    test('far past both cutoffs in month - just passed still applies', () {
      // June 30, prevCutoff=28, daysSincePrev=2, nextCutoff=July 13
      // Within 7-day overdue window => "just passed" (you missed it, pay now)
      final info = CutoffCalculator.compute(
        now: DateTime(2026, 6, 30),
        cutoffDay1: 13,
        cutoffDay2: 28,
      );
      expect(info.state, CutoffState.justPassed);
      expect(info.daysSincePrev, 2);
      expect(info.nextCutoffDay, 13);
      expect(info.daysUntilNext, 13);
    });

    test('more than 7 days past last cutoff in month - normal', () {
      // June 30, prevCutoff=20 (custom), daysSincePrev=10, > 7 => normal
      final info = CutoffCalculator.compute(
        now: DateTime(2026, 6, 30),
        cutoffDay1: 20,
        cutoffDay2: 20,
      );
      expect(info.state, CutoffState.normal);
    });

    test('handles cutoffs in unsorted order', () {
      final info = CutoffCalculator.compute(
        now: DateTime(2026, 6, 5),
        cutoffDay1: 28,
        cutoffDay2: 13,
      );
      expect(info.nextCutoffDay, 13);
    });

    test('equal cutoffs - next is the same day', () {
      final info = CutoffCalculator.compute(
        now: DateTime(2026, 6, 10),
        cutoffDay1: 13,
        cutoffDay2: 13,
      );
      expect(info.nextCutoffDay, 13);
    });

    test('handles February with day 28 cutoff', () {
      final info = CutoffCalculator.compute(
        now: DateTime(2026, 2, 28),
        cutoffDay1: 13,
        cutoffDay2: 28,
      );
      expect(info.state, CutoffState.dueToday);
    });

    test('handles February 30 - 28 was the last cutoff', () {
      // Feb has 28 days in 2026
      final info = CutoffCalculator.compute(
        now: DateTime(2026, 3, 1),
        cutoffDay1: 13,
        cutoffDay2: 28,
      );
      expect(info.nextCutoffDay, 13);
    });
  });

  group('CutoffCalculator.statusText', () {
    test('due today', () {
      const info = CutoffInfo(
        state: CutoffState.dueToday,
        daysUntilNext: 0,
        daysSincePrev: 0,
        nextCutoffDay: 13,
        prevCutoffDay: null,
      );
      expect(CutoffCalculator.statusText(info), 'Due today');
    });

    test('near deadline - 1 day', () {
      const info = CutoffInfo(
        state: CutoffState.nearDeadline,
        daysUntilNext: 1,
        daysSincePrev: 0,
        nextCutoffDay: 13,
        prevCutoffDay: null,
      );
      expect(CutoffCalculator.statusText(info), '1 day until cutoff');
    });

    test('near deadline - 3 days', () {
      const info = CutoffInfo(
        state: CutoffState.nearDeadline,
        daysUntilNext: 3,
        daysSincePrev: 0,
        nextCutoffDay: 13,
        prevCutoffDay: null,
      );
      expect(CutoffCalculator.statusText(info), '3 days until cutoff');
    });

    test('just passed - 1 day (singular)', () {
      const info = CutoffInfo(
        state: CutoffState.justPassed,
        daysUntilNext: 15,
        daysSincePrev: 1,
        nextCutoffDay: 28,
        prevCutoffDay: 13,
      );
      expect(CutoffCalculator.statusText(info), 'Overdue by 1 day');
    });

    test('just passed - 5 days (plural)', () {
      const info = CutoffInfo(
        state: CutoffState.justPassed,
        daysUntilNext: 15,
        daysSincePrev: 5,
        nextCutoffDay: 28,
        prevCutoffDay: 13,
      );
      expect(CutoffCalculator.statusText(info), 'Overdue by 5 days');
    });

    test('normal - 12 days', () {
      const info = CutoffInfo(
        state: CutoffState.normal,
        daysUntilNext: 12,
        daysSincePrev: 0,
        nextCutoffDay: 13,
        prevCutoffDay: null,
      );
      expect(CutoffCalculator.statusText(info), 'Next cutoff in 12 days');
    });
  });

  group('CutoffCalculator.statusColor', () {
    const normal = Color(0xFF000000);
    const nearDeadline = Color(0xFFFFA500);
    const dueToday = Color(0xFFFF0000);
    const error = Color(0xFF800000);

    test('normal state returns normal color', () {
      const info = CutoffInfo(
        state: CutoffState.normal,
        daysUntilNext: 12,
        daysSincePrev: 0,
        nextCutoffDay: 13,
        prevCutoffDay: null,
      );
      expect(
        CutoffCalculator.statusColor(info, normal: normal, nearDeadline: nearDeadline, dueToday: dueToday, error: error),
        normal,
      );
    });

    test('nearDeadline state returns nearDeadline color', () {
      const info = CutoffInfo(
        state: CutoffState.nearDeadline,
        daysUntilNext: 2,
        daysSincePrev: 0,
        nextCutoffDay: 13,
        prevCutoffDay: null,
      );
      expect(
        CutoffCalculator.statusColor(info, normal: normal, nearDeadline: nearDeadline, dueToday: dueToday, error: error),
        nearDeadline,
      );
    });

    test('dueToday state returns dueToday color', () {
      const info = CutoffInfo(
        state: CutoffState.dueToday,
        daysUntilNext: 0,
        daysSincePrev: 0,
        nextCutoffDay: 13,
        prevCutoffDay: null,
      );
      expect(
        CutoffCalculator.statusColor(info, normal: normal, nearDeadline: nearDeadline, dueToday: dueToday, error: error),
        dueToday,
      );
    });

    test('justPassed state returns error color', () {
      const info = CutoffInfo(
        state: CutoffState.justPassed,
        daysUntilNext: 15,
        daysSincePrev: 1,
        nextCutoffDay: 28,
        prevCutoffDay: 13,
      );
      expect(
        CutoffCalculator.statusColor(info, normal: normal, nearDeadline: nearDeadline, dueToday: dueToday, error: error),
        error,
      );
    });
  });
}
