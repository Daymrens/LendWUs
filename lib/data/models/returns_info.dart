class ReturnsInfo {
  final double totalReturns;
  final int totalHeads;
  final double perHeadShare;

  ReturnsInfo({
    required this.totalReturns,
    required this.totalHeads,
    required this.perHeadShare,
  });

  factory ReturnsInfo.fromMap(Map<String, dynamic> map) {
    final totalReturns = (map['totalReturns'] is num ? (map['totalReturns'] as num).toDouble() : 0.0);
    final totalHeads = (map['totalHeads'] is num ? (map['totalHeads'] as num).toInt() : 1);
    return ReturnsInfo(
      totalReturns: totalReturns,
      totalHeads: totalHeads,
      perHeadShare: totalHeads > 0 ? totalReturns / totalHeads : 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalReturns': totalReturns,
      'totalHeads': totalHeads,
      'perHeadShare': perHeadShare,
    };
  }
}
