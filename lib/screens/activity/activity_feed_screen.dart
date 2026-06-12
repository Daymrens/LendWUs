import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/loan.dart';
import '../../data/models/contribution.dart';
import '../../data/models/repayment.dart';
import '../../providers/members_provider.dart';
import '../../providers/loans_provider.dart';

class ActivityFeedScreen extends ConsumerStatefulWidget {
  const ActivityFeedScreen({super.key});

  @override
  ConsumerState<ActivityFeedScreen> createState() => _ActivityFeedScreenState();
}

class _ActivityFeedScreenState extends ConsumerState<ActivityFeedScreen> {
  String _searchQuery = '';
  String _typeFilter = 'all';
  int _visibleCount = 20;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  static final _types = [
    ('all', 'All'),
    ('contribution', 'Contributions'),
    ('loan', 'Loans'),
    ('repayment', 'Repayments'),
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      setState(() => _visibleCount += 20);
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = [...?ref.watch(membersStreamProvider).asData?.value];
    final contributions = [...?ref.watch(contributionsStreamProvider).asData?.value];
    final loans = [...?ref.watch(loansStreamProvider).asData?.value];
    final repayments = [...?ref.watch(repaymentsStreamProvider).asData?.value];
    final memberMap = {for (var m in members) if (m.id != null) m.id!: m.name};
    final colorScheme = Theme.of(context).colorScheme;

    List<_ActivityItem> items = _buildItems(contributions, loans, repayments, memberMap);
    items.sort((a, b) => b.date.compareTo(a.date));

    if (_typeFilter != 'all') {
      items = items.where((i) => i.type == _typeFilter).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      items = items.where((i) =>
        i.memberName.toLowerCase().contains(q) ||
        i.description.toLowerCase().contains(q)
      ).toList();
    }

    final displayItems = items.take(_visibleCount).toList();

    return Scaffold(
      appBar: AppBar(title:  Text('Activity Feed')),
      body: Column(
        children: [
          Padding(
            padding:  EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              onChanged: (v) {
                setState(() {
                  _searchQuery = v;
                  _visibleCount = 20;
                });
              },
              style:  TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search by name or description...',
                prefixIcon:  Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon:  Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                            _visibleCount = 20;
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                filled: true,
                fillColor: colorScheme.surface,
                contentPadding:  EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
           Gap(4),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding:  EdgeInsets.symmetric(horizontal: 16),
              children: _types.map((t) => Padding(
                padding:  EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(t.$1),
                  selected: _typeFilter == t.$2,
                  onSelected: (_) {
                    setState(() {
                      _typeFilter = t.$2;
                      _visibleCount = 20;
                    });
                  },
                  visualDensity: VisualDensity.compact,
                ),
              )).toList(),
            ),
          ),
           Divider(height: 8),
          Expanded(
            child: displayItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inbox, size: 48, color: colorScheme.onSurfaceVariant.withAlpha(100)),
                         Gap(8),
                        Text('No activity found', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding:  EdgeInsets.symmetric(horizontal: 16),
                    itemCount: displayItems.length + (items.length > _visibleCount ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= displayItems.length) {
                        return  Center(child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ));
                      }
                      final item = displayItems[index];
                      return _ActivityRow(item: item);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  List<_ActivityItem> _buildItems(
    List<Contribution> contributions,
    List<Loan> loans,
    List<Repayment> repayments,
    Map<String, String> memberMap,
  ) {
    List<_ActivityItem> items = [];

    for (var c in contributions) {
      items.add(_ActivityItem(
        date: c.date,
        type: 'contribution',
        amount: c.amount,
        memberName: memberMap[c.memberId] ?? 'Unknown',
        memberId: c.memberId,
        description: 'Contribution',
      ));
    }

    for (var l in loans) {
      items.add(_ActivityItem(
        date: l.issuedDate,
        type: 'loan',
        amount: l.principal,
        memberName: memberMap[l.memberId] ?? 'Unknown',
        memberId: l.memberId,
        description: 'Loan at ${(l.interestRate * 100).toStringAsFixed(0)}%',
      ));
    }

    for (var r in repayments) {
      final loan = loans.where((l) => l.id == r.loanId).firstOrNull;
      items.add(_ActivityItem(
        date: r.date,
        type: 'repayment',
        amount: r.amountPaid,
        memberName: loan != null ? (memberMap[loan.memberId] ?? 'Unknown') : 'Unknown',
        memberId: loan?.memberId,
        description: 'Repayment',
      ));
    }

    return items;
  }
}

class _ActivityItem {
  final DateTime date;
  final String type;
  final double amount;
  final String memberName;
  final String? memberId;
  final String description;

  _ActivityItem({
    required this.date,
    required this.type,
    required this.amount,
    required this.memberName,
    this.memberId,
    required this.description,
  });
}

class _ActivityRow extends StatelessWidget {
  final _ActivityItem item;

   _ActivityRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding:  EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: _colorForType(item.type).withAlpha(51),
            child: Icon(_iconForType(item.type), color: _colorForType(item.type), size: 20),
          ),
           Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.memberName,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: colorScheme.onSurface),
                ),
                 Gap(2),
                Text('${item.description} · ${_formatDate(item.date)}',
                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            CurrencyFormatter.format(item.amount),
            style: TextStyle(
              color: _colorForType(item.type),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'contribution': return AppColors.primary;
      case 'loan': return AppColors.warning;
      case 'repayment': return AppColors.secondary;
      default: return AppColors.textMuted;
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'contribution': return Icons.add_circle;
      case 'loan': return Icons.account_balance;
      case 'repayment': return Icons.payment;
      default: return Icons.circle;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormatter.format(date);
  }
}
