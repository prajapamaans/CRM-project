/// Model representing deal statistics returned from GET /api/deals/stats.
class DealStatsModel {
  final int totalDeals;
  final double pipelineValue;
  final int closedWon;
  final int closedLost;

  DealStatsModel({
    required this.totalDeals,
    required this.pipelineValue,
    required this.closedWon,
    required this.closedLost,
  });

  factory DealStatsModel.fromJson(Map<String, dynamic> json) {
    return DealStatsModel(
      totalDeals: json['totalDeals'] as int? ?? json['total_deals'] as int? ?? 0,
      pipelineValue: (json['pipelineValue'] as num? ?? json['pipeline_value'] as num? ?? 0).toDouble(),
      closedWon: json['closedWon'] as int? ?? json['closed_won'] as int? ?? 0,
      closedLost: json['closedLost'] as int? ?? json['closed_lost'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalDeals': totalDeals,
      'pipelineValue': pipelineValue,
      'closedWon': closedWon,
      'closedLost': closedLost,
    };
  }
}
