import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class _ChangelogEntry {
  final String version;
  final String date;
  final List<String> additions;
  final List<String> fixes;
  final List<String> changes;

  const _ChangelogEntry({
    required this.version,
    required this.date,
    this.additions = const [],
    this.fixes = const [],
    this.changes = const [],
  });
}

const _changelog = <_ChangelogEntry>[
  _ChangelogEntry(
    version: '1.2.0',
    date: 'June 2026',
    additions: [
      'Biometric fingerprint login with app-reopen verification',
      'Notification clear/delete for members (swipe-to-delete, clear read, clear all)',
      'Member notification UI enhancement with type-colored icons and filters',
      'Changelog screen with version history',
    ],
    fixes: [
      'Firestore rules missing for user_settings/otp_codes/email_logs/backups (permission denied on biometric enable)',
      'Biometric enrollment not persisting credentials for login screen',
      'Post-login biometric prompt Enable button not triggering fingerprint scan',
    ],
    changes: [
      'Enhanced notifications screen with filter bar (All/Unread) and unread badge',
      'Improved security: credentials stored via flutter_secure_storage',
    ],
  ),
  _ChangelogEntry(
    version: '1.1.0',
    date: 'May 2026',
    additions: [
      'Admin: bulk loan processing via CSV paste',
      'Admin: compliance reports with real data aggregation',
      'Admin: member migration with transaction support',
      'Admin: send notification screen with templates',
      'Maintenance mode for app-wide lockdown',
      'Web: member performance analytics dashboard',
      'Web: activity feed with real-time updates',
    ],
    fixes: [
      'Interest rate format inconsistency across codebases',
      'Amortization formula using multiplication instead of exponentiation',
      'ActivityLog crash on Firestore Timestamp parsing',
      'Biometric stub returning true without device check',
      'Hardcoded admin emails removed; relies on Firestore settings',
    ],
    changes: [
      'Consolidated profile and edit-profile screens',
      'Route-level auth guards (admin routes blocked for members, vice versa)',
      'Added composite indexes for key queries',
    ],
  ),
  _ChangelogEntry(
    version: '1.0.0',
    date: 'April 2026',
    additions: [
      'Initial release of LendWUs Group Sinking Fund Manager',
      'Member management with head count and contribution tracking',
      'Loan issuance, repayment, and amortization schedule',
      'Admin dashboard with fund summary and quick actions',
      'Member dashboard with balance, contribution, and loan status',
      'Firebase Auth with email/password and Google Sign-In',
      'Real-time Firestore sync with Riverpod state management',
      'Approval workflow for payments, loans, and head changes',
      'Push notifications via Firebase Cloud Messaging',
      'Web counterpart with React 18 + TypeScript',
    ],
    fixes: [],
    changes: [],
  ),
];

class ChangelogScreen extends StatelessWidget {
  const ChangelogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:  Text('What\'s New'),
      ),
      body: ListView.separated(
        padding:  EdgeInsets.all(24),
        itemCount: _changelog.length,
        separatorBuilder: (_, __) =>  SizedBox(height: 24),
        itemBuilder: (context, index) {
          final entry = _changelog[index];
          final isLatest = index == 0;
          return _VersionCard(entry: entry, isLatest: isLatest);
        },
      ),
    );
  }
}

class _VersionCard extends StatelessWidget {
  final _ChangelogEntry entry;
  final bool isLatest;

   _VersionCard({required this.entry, required this.isLatest});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:  EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLatest ? AppColors.primary.withValues(alpha: 0.4) : AppColors.textMuted.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:  EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isLatest ? AppColors.primary : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'v${entry.version}',
                  style: TextStyle(
                    color: isLatest ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
               SizedBox(width: 12),
              Text(
                entry.date,
                style: TextStyle(
                  color: AppColors.textMuted.withValues(alpha: 0.7),
                  fontSize: 13,
                ),
              ),
              if (isLatest) ...[
                 SizedBox(width: 8),
                Container(
                  padding:  EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:  Text(
                    'Latest',
                    style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
           SizedBox(height: 16),
          if (entry.additions.isNotEmpty) ...[
            _SectionHeader(label: 'Added', color: AppColors.primary),
             SizedBox(height: 6),
            ...entry.additions.map((item) => _BulletItem(text: item, color: AppColors.primary)),
             SizedBox(height: 12),
          ],
          if (entry.fixes.isNotEmpty) ...[
            _SectionHeader(label: 'Fixed', color: AppColors.warning),
             SizedBox(height: 6),
            ...entry.fixes.map((item) => _BulletItem(text: item, color: AppColors.warning)),
             SizedBox(height: 12),
          ],
          if (entry.changes.isNotEmpty) ...[
            _SectionHeader(label: 'Changed', color: AppColors.secondary),
             SizedBox(height: 6),
            ...entry.changes.map((item) => _BulletItem(text: item, color: AppColors.secondary)),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final Color color;

   _SectionHeader({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 3, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
         SizedBox(width: 8),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }
}

class _BulletItem extends StatelessWidget {
  final String text;
  final Color color;

   _BulletItem({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:  EdgeInsets.only(left: 11, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:  EdgeInsets.only(top: 7),
            child: Container(width: 5, height: 5, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          ),
           SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.4)),
          ),
        ],
      ),
    );
  }
}
