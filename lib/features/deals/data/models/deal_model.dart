import 'package:flutter/material.dart';

class DealModel {
  final String id;
  final String title;
  final String? description;
  final double amount;
  final String? currency;
  final String stage;
  final int probability;
  final String? expectedCloseDate;
  final String? companyId;
  final String? companyName;
  final String? contactId;
  final String? ownerId;
  final String? ownerName;
  final String? createdAt;
  final String? priority;

  const DealModel({
    required this.id,
    required this.title,
    this.description,
    required this.amount,
    this.currency,
    required this.stage,
    required this.probability,
    this.expectedCloseDate,
    this.companyId,
    this.companyName,
    this.contactId,
    this.ownerId,
    this.ownerName,
    this.createdAt,
    this.priority,
  });

  factory DealModel.fromJson(Map<String, dynamic> json) {
    final rawProbability = json['probability'];
    int prob = 0;
    if (rawProbability is num) {
      prob = rawProbability.toInt();
    } else if (rawProbability is String) {
      prob = int.tryParse(rawProbability) ?? 0;
    }

    final rawAmount = json['amount'] ?? json['dealValue'] ?? json['deal_value'] ?? json['value'];
    double amt = 0.0;
    if (rawAmount is num) {
      amt = rawAmount.toDouble();
    } else if (rawAmount is String) {
      amt = double.tryParse(rawAmount) ?? 0.0;
    }

    final titleStr = json['title'] as String? ??
        json['name'] as String? ??
        json['dealName'] as String? ??
        json['deal_name'] as String? ??
        '';

    return DealModel(
      id: json['id']?.toString() ?? '',
      title: titleStr,
      description: json['description'] as String?,
      amount: amt,
      currency: json['currency'] as String? ?? 'USD',
      stage: json['stage'] as String? ?? json['stageName'] as String? ?? json['stage_name'] as String? ?? 'Prospect',
      probability: prob,
      expectedCloseDate: json['expectedCloseDate'] as String? ??
          json['expected_close_date'] as String? ??
          json['closeDate'] as String? ??
          json['close_date'] as String?,
      companyId: json['companyId'] as String? ?? json['company_id'] as String?,
      companyName: json['companyName'] as String? ?? json['company_name'] as String?,
      contactId: json['contactId'] as String? ?? json['contact_id'] as String?,
      ownerId: json['ownerId'] as String? ?? json['owner_id'] as String?,
      ownerName: json['ownerName'] as String? ?? json['owner_name'] as String?,
      createdAt: json['createdAt'] as String? ?? json['created_at'] as String?,
      priority: json['priority'] as String?,
    );
  }

  double get progress => (probability / 100.0).clamp(0.0, 1.0);
  Color get dotColor => stage == 'Closed Won' ? const Color(0xFF00A884) : const Color(0xFF3B82F6);
  String get company => companyName ?? 'No company';
  String get owner => ownerName ?? 'Unassigned';
  String get date => expectedCloseDate != null && expectedCloseDate!.contains('T')
      ? expectedCloseDate!.split('T').first
      : (expectedCloseDate ?? '');
  String get statusBadge => stage;
  Color get badgeBgColor => const Color(0xFFE6F4F1);
  Color get badgeTextColor => const Color(0xFF0F766E);

  static List<DealModel> get sampleDeals => const [];
}
