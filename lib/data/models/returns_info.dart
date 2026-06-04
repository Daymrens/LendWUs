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
    final totalReturns = (map['totalReturns'] ?? 0.0).toDouble();
    final totalHeads = (map['totalHeads'] ?? 1).toInt();
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
