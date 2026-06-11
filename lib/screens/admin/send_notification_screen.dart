import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/repositories/member_repository.dart';
import '../../data/models/member.dart';

class SendNotificationScreen extends ConsumerStatefulWidget {
  const SendNotificationScreen({super.key});

  @override
  ConsumerState<SendNotificationScreen> createState() => _SendNotificationScreenState();
}

class _SendNotificationScreenState extends ConsumerState<SendNotificationScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  String _recipient = 'all';
  String _type = 'custom_notification';
  Member? _selectedMember;
  bool _sending = false;
  String? _result;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.isEmpty || body.isEmpty) {
      setState(() => _result = 'Title and body are required');
      return;
    }

    setState(() {
      _sending = true;
      _result = null;
    });

    try {
      switch (_recipient) {
        case 'all':
          await NotificationRepository.notifyAll(title, body, type: _type);
        case 'admins':
          await NotificationRepository.notifyAdmins(title, body, type: _type);
        case 'members':
          await NotificationRepository.notifyAllMembers(title, body, type: _type);
        case 'member':
          if (_selectedMember == null) {
            setState(() => _result = 'Select a member');
            _sending = false;
            return;
          }
          await NotificationRepository.notifyMember(_selectedMember!.id!, title, body, type: _type);
      }
      setState(() {
        _result = 'Notification sent successfully!';
        _titleController.clear();
        _bodyController.clear();
        _selectedMember = null;
      });
    } catch (e) {
      setState(() => _result = 'Failed to send: $e');
    } finally {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(_membersProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Send Notification')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Compose Notification', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const Gap(16),
            DropdownButtonFormField<String>(
              value: _recipient,
              decoration: const InputDecoration(labelText: 'Recipient', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('Everyone')),
                DropdownMenuItem(value: 'admins', child: Text('All Admins')),
                DropdownMenuItem(value: 'members', child: Text('All Members')),
                DropdownMenuItem(value: 'member', child: Text('Specific Member')),
              ],
              onChanged: (v) => setState(() => _recipient = v!),
            ),
            if (_recipient == 'member') ...[
              const Gap(12),
              membersAsync.when(
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text('Error: $e'),
                data: (members) => DropdownButtonFormField<Member>(
                  value: _selectedMember,
                  decoration: const InputDecoration(labelText: 'Select Member', border: OutlineInputBorder()),
                  items: members.map((m) => DropdownMenuItem(
                    value: m,
                    child: Text(m.name),
                  )).toList(),
                  onChanged: (v) => setState(() => _selectedMember = v),
                ),
              ),
            ],
            const Gap(12),
            DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(labelText: 'Notification Type', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'custom_notification', child: Text('Custom')),
                DropdownMenuItem(value: 'app_update', child: Text('App Update')),
                DropdownMenuItem(value: 'system', child: Text('System')),
              ],
              onChanged: (v) => setState(() => _type = v!),
            ),
            const Gap(12),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
            ),
            const Gap(12),
            TextField(
              controller: _bodyController,
              decoration: const InputDecoration(labelText: 'Message', border: OutlineInputBorder()),
              maxLines: 5,
            ),
            const Gap(20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _sending ? null : _send,
                child: _sending
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Send Notification'),
              ),
            ),
            if (_result != null) ...[
              const Gap(12),
              Text(_result!, style: TextStyle(
                color: _result!.contains('success') ? Colors.green : Colors.red,
              )),
            ],
          ],
        ),
      ),
    );
  }
}

final _membersProvider = FutureProvider<List<Member>>((ref) async {
  final repo = MemberRepository();
  return repo.getAllMembers();
});
