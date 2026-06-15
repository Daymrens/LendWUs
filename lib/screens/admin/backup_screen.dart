import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../core/theme/app_colors.dart';
import '../../core/firebase/firebase_service.dart';
import '../../core/services/security_service.dart';

final backupListProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final snapshot = await FirebaseService.firestore
      .collection('backups')
      .orderBy('backup_date', descending: true)
      .get();
  final grouped = <String, Map<String, dynamic>>{};
  for (final doc in snapshot.docs) {
    final data = doc.data();
    final id = doc.id;
    final collection = data['collection'] as String? ?? '?';
    final parts = id.split('_');
    final backupId = parts.length >= 2 ? parts[1] : id;
    if (!grouped.containsKey(backupId)) {
      grouped[backupId] = {
        'id': backupId,
        'date': data['backup_date'] as String? ?? '',
        'collections': <String>[],
        'totalDocs': 0,
      };
    }
    final entry = grouped[backupId]!;
    (entry['collections'] as List<String>).add(collection);
    entry['totalDocs'] = (entry['totalDocs'] as int) + (data['count'] as int? ?? 0);
  }
  final list = grouped.values.toList();
  list.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
  return list;
});

class BackupScreen extends ConsumerWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backupsAsync = ref.watch(backupListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Backups'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cleaning_services),
            tooltip: 'Cleanup old backups (>30 days)',
            onPressed: () => _cleanupOld(ref, context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(backupListProvider),
          ),
        ],
      ),
      body: backupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (backups) => Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: AppColors.surfaceAlt,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.backup),
                label: const Text('Create Backup'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _createBackup(ref, context),
              ),
            ),
            const Gap(8),
            Expanded(
              child: backups.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.backup_outlined, size: 48, color: AppColors.textMuted.withAlpha(80)),
                          const Gap(12),
                          Text('No backups yet', style: TextStyle(color: AppColors.textMuted)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: backups.length,
                      itemBuilder: (_, i) {
                        final b = backups[i];
                        final collections = (b['collections'] as List<String>).toSet().join(', ');
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.backup, color: AppColors.primary, size: 28),
                              const Gap(16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _formatDate(b['date'] as String),
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    const Gap(4),
                                    Text(
                                      '${b['totalDocs']} docs • $collections',
                                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                                onPressed: () => _deleteBackup(ref, context, b['id'] as String),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createBackup(WidgetRef ref, BuildContext context) async {
    try {
      await DataBackupService.backupData();
      ref.invalidate(backupListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup created successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e')),
        );
      }
    }
  }

  Future<void> _cleanupOld(WidgetRef ref, BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cleanup Old Backups?'),
        content: const Text('Delete backups older than 30 days?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cleanup'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await DataBackupService.cleanupOldBackups();
        ref.invalidate(backupListProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Old backups cleaned up')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cleanup failed: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteBackup(WidgetRef ref, BuildContext context, String backupId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Backup?'),
        content: Text('Delete backup $backupId?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        final snapshot = await FirebaseService.firestore
            .collection('backups')
            .get();
        final batch = FirebaseService.firestore.batch();
        for (final doc in snapshot.docs) {
          if (doc.id.contains(backupId)) {
            batch.delete(doc.reference);
          }
        }
        await batch.commit();
        ref.invalidate(backupListProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Backup deleted')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Delete failed: $e')),
          );
        }
      }
    }
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}
