import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/member.dart';
import '../../data/models/loan.dart';
import '../../data/models/contribution.dart';
import '../../providers/members_provider.dart';
import '../../providers/loans_provider.dart';

class GlobalSearchScreen extends ConsumerStatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  ConsumerState<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  String _query = '';
  bool _showResults = false;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          focusNode: _focusNode,
          onChanged: (v) => setState(() {
            _query = v.trim().toLowerCase();
            _showResults = _query.isNotEmpty;
          }),
          style:  TextStyle(fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Search members, loans, contributions...',
            border: InputBorder.none,
            filled: false,
            suffixIcon: _query.isNotEmpty
                ? IconButton(
                    icon:  Icon(Icons.clear, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _query = '';
                        _showResults = false;
                      });
                    },
                  )
                : null,
          ),
        ),
      ),
      body: _showResults ?  _SearchResults(query: '') : _buildRecent(context),
    );
  }

  Widget _buildRecent(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(60)),
           Gap(12),
          Text('Type to search across members, loans, and contributions',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SearchResults extends ConsumerWidget {
  final String query;
   _SearchResults({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(membersStreamProvider);
    final contributionsAsync = ref.watch(contributionsStreamProvider);
    final loansAsync = ref.watch(activeLoansStreamProvider);

    return membersAsync.when(
      data: (members) {
        return contributionsAsync.when(
          data: (contributions) {
            return loansAsync.when(
              data: (loans) {
                return _buildResults(context, ref, members, contributions, loans);
              },
              loading: () =>  Center(child: CircularProgressIndicator()),
              error: (_, __) =>  Center(child: Text('Error loading loans')),
            );
          },
          loading: () =>  Center(child: CircularProgressIndicator()),
          error: (_, __) =>  Center(child: Text('Error loading contributions')),
        );
      },
      loading: () =>  Center(child: CircularProgressIndicator()),
      error: (_, __) =>  Center(child: Text('Error loading members')),
    );
  }

  Widget _buildResults(
    BuildContext context,
    WidgetRef ref,
    List<Member> members,
    List<Contribution> contributions,
    List<Loan> loans,
  ) {
    final q = query;
    final colorScheme = Theme.of(context).colorScheme;

    final matchedMembers = members.where((m) =>
      m.name.toLowerCase().contains(q) ||
      (m.memberId?.toLowerCase().contains(q) ?? false) ||
      (m.linkedEmail?.toLowerCase().contains(q) ?? false)
    ).toList();

    final matchedContributions = contributions.where((c) =>
      members.any((m) => m.id == c.memberId && m.name.toLowerCase().contains(q))
    ).toList();

    final matchedLoans = loans.where((l) =>
      members.any((m) => m.id == l.memberId && m.name.toLowerCase().contains(q))
    ).toList();

    final totalResults = matchedMembers.length + matchedContributions.length + matchedLoans.length;

    if (totalResults == 0) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48, color: colorScheme.onSurfaceVariant.withAlpha(100)),
             Gap(8),
            Text('No results for "$query"', style: TextStyle(color: colorScheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    return ListView(
      padding:  EdgeInsets.all(16),
      children: [
        if (matchedMembers.isNotEmpty) ...[
          Text('Members (${matchedMembers.length})',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colorScheme.onSurface),
          ),
           Gap(4),
          ...matchedMembers.map((m) => ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 16,
              backgroundImage: m.avatarPath != null ? NetworkImage(m.avatarPath!) : null,
              child: m.avatarPath == null ? Text(m.name.isNotEmpty ? m.name[0].toUpperCase() : '?') : null,
            ),
            title: Text(m.name, style:  TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: Text(m.memberId ?? '', style:  TextStyle(fontSize: 12)),
            trailing:  Icon(Icons.chevron_right, size: 18),
            onTap: () => context.push('/member-profile/${m.id}'),
          )),
           Gap(16),
        ],
        if (matchedLoans.isNotEmpty) ...[
          Text('Active Loans (${matchedLoans.length})',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colorScheme.onSurface),
          ),
           Gap(4),
          ...matchedLoans.map((l) {
            final member = members.where((m) => m.id == l.memberId).firstOrNull;
            return ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.warning.withAlpha(51),
                child:  Icon(Icons.account_balance, color: AppColors.warning, size: 18),
              ),
              title: Text(member?.name ?? 'Unknown',
                style:  TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: Text('${CurrencyFormatter.format(l.principal)} · ${(l.interestRate * 100).toStringAsFixed(0)}%',
                style:  TextStyle(fontSize: 12)),
              trailing:  Icon(Icons.chevron_right, size: 18),
              onTap: () {
                if (member != null) context.push('/member-profile/${member.id}');
              },
            );
          }),
           Gap(16),
        ],
        if (matchedContributions.isNotEmpty) ...[
          Text('Contributions (${matchedContributions.length})',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colorScheme.onSurface),
          ),
           Gap(4),
          ...matchedContributions.map((c) {
            final member = members.where((m) => m.id == c.memberId).firstOrNull;
            return ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary.withAlpha(51),
                child:  Icon(Icons.add_circle, color: AppColors.primary, size: 18),
              ),
              title: Text(member?.name ?? 'Unknown',
                style:  TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: Text('${CurrencyFormatter.format(c.amount)} · ${c.month}/${c.year}',
                style:  TextStyle(fontSize: 12)),
              trailing:  Icon(Icons.chevron_right, size: 18),
              onTap: () {
                if (member != null) context.push('/member-profile/${member.id}');
              },
            );
          }),
        ],
      ],
    );
  }
}
