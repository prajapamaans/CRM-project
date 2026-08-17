class BingoSummaryResponse {
  final bool success;
  final BingoSummaryData data;

  BingoSummaryResponse({
    required this.success,
    required this.data,
  });

  factory BingoSummaryResponse.fromJson(Map<String, dynamic> json) {
    return BingoSummaryResponse(
      success: json['success'] ?? false,
      data: BingoSummaryData.fromJson(
        Map<String, dynamic>.from(json['data'] ?? {}),
      ),
    );
  }
}

class BingoSummaryData {
  final String summary;
  final bool blocked;
  final List<BingoActivity> activities;

  BingoSummaryData({
    required this.summary,
    required this.blocked,
    required this.activities,
  });

  factory BingoSummaryData.fromJson(Map<String, dynamic> json) {
    return BingoSummaryData(
      summary: json['summary']?.toString() ?? '',
      blocked: json['blocked'] ?? false,
      activities: (json['activities'] as List? ?? [])
          .map(
            (e) => BingoActivity.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
    );
  }
}

class BingoActivity {
  final String id;
  final String type;
  final String? title;
  final String? description;
  final String? createdAt;
  final String? source;
  final String? createdBy;
  final String? status;

  BingoActivity({
    required this.id,
    required this.type,
    this.title,
    this.description,
    this.createdAt,
    this.source,
    this.createdBy,
    this.status,
  });

  factory BingoActivity.fromJson(Map<String, dynamic> json) {
    return BingoActivity(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      title: json['title']?.toString(),
      description: json['description']?.toString(),
      createdAt: json['createdAt']?.toString(),
      source: json['source']?.toString(),
      createdBy: json['createdBy']?.toString(),
      status: json['status']?.toString(),
    );
  }
}
