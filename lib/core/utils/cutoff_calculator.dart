import 'package:flutter/material.dart';

enum CutoffState { dueToday, nearDeadline, justPassed, normal }

class CutoffInfo {
  final CutoffState state;
  final int daysUntilNext;
  final int daysSincePrev;
  final int nextCutoffDay;
  final int? prevCutoffDay;

  const CutoffInfo({
    required this.state,
    required this.daysUntilNext,
    required this.daysSincePrev,
    required this.nextCutoffDay,
    required this.prevCutoffDay,
  });
}

class CutoffCalculator {
  static const int nearWindowDays = 3;
  static const int overdueWindowDays = 7;

  static List<int> sortedCutoffs(int day1, int day2) {
    return [day1, day2]..sort();
  }

  static CutoffInfo compute({
    required DateTime now,
    required int cutoffDay1,
    required int cutoffDay2,
  }) {
    final cutoffs = sortedCutoffs(cutoffDay1, cutoffDay2);
    final today = now.day;

    int? nextCutoff;
    int? prevCutoff;
    for (final c in cutoffs) {
      if (c >= today) {
        nextCutoff = c;
        break;
      }
      prevCutoff = c;
    }

    final int daysUntilNext;
    final int nextCutoffDay;
    if (nextCutoff == null) {
      // All cutoffs for this month have passed. Next cutoff is in the
      // following month on the earliest cutoff day.
      nextCutoffDay = cutoffs.first;
      final nextMonth = DateTime(now.year, now.month + 1, nextCutoffDay);
      daysUntilNext = nextMonth.difference(DateTime(now.year, now.month, today)).inDays;
    } else {
      nextCutoffDay = nextCutoff;
      daysUntilNext = nextCutoff - today;
    }

    final daysSincePrev = prevCutoff != null ? today - prevCutoff : 0;

    final CutoffState state;
    if (daysUntilNext == 0) {
      state = CutoffState.dueToday;
    } else if (daysSincePrev > 0 && daysSincePrev <= overdueWindowDays) {
      state = CutoffState.justPassed;
    } else if (daysUntilNext <= nearWindowDays) {
      state = CutoffState.nearDeadline;
    } else {
      state = CutoffState.normal;
    }

    return CutoffInfo(
      state: state,
      daysUntilNext: daysUntilNext,
      daysSincePrev: daysSincePrev,
      nextCutoffDay: nextCutoffDay,
      prevCutoffDay: prevCutoff,
    );
  }

  static String statusText(CutoffInfo info) {
    switch (info.state) {
      case CutoffState.dueToday:
        return 'Due today';
      case CutoffState.nearDeadline:
        return _daysLabel(info.daysUntilNext, 'until cutoff');
      case CutoffState.justPassed:
        return 'Overdue by ${_daysLabel(info.daysSincePrev, '')}'.trim();
      case CutoffState.normal:
        return 'Next cutoff in ${_daysLabel(info.daysUntilNext, 'days')}';
    }
  }

  static Color statusColor(CutoffInfo info, {
    required Color normal,
    required Color nearDeadline,
    required Color dueToday,
    required Color error,
  }) {
    switch (info.state) {
      case CutoffState.dueToday:
        return dueToday;
      case CutoffState.nearDeadline:
        return nearDeadline;
      case CutoffState.justPassed:
        return error;
      case CutoffState.normal:
        return normal;
    }
  }

  static String _daysLabel(int n, String suffix) {
    final plural = n == 1 ? 'day' : 'days';
    if (suffix.isEmpty) return '$n $plural';
    if (suffix == 'days') return '$n $plural';
    return '$n $plural $suffix';
  }
}
