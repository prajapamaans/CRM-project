import 'package:flutter/foundation.dart';
import '../../../../core/models/master_dropdown_model.dart';
import 'contact_model.dart';

/// Single stage count item containing exact requirements: stageId, stageName, count, position.
class ContactLifecycleCountResult {
  final String stageId;
  final String stageName;
  final int count;
  final int position;

  ContactLifecycleCountResult({
    required this.stageId,
    required this.stageName,
    required this.count,
    required this.position,
  });

  Map<String, dynamic> toJson() {
    return {
      'stageId': stageId,
      'stageName': stageName,
      'count': count,
      'position': position,
    };
  }

  @override
  String toString() =>
      'ContactLifecycleCountResult(stageId: $stageId, stageName: $stageName, count: $count, position: $position)';
}

/// Analysis summary containing total contacts analyzed, unassigned count, unknown ID count, and stage counts.
class ContactLifecycleAnalysisSummary {
  final int totalContacts;
  final int contactsWithNoStage;
  final int contactsWithUnknownStageId;
  final List<ContactLifecycleCountResult> stageCounts;

  ContactLifecycleAnalysisSummary({
    required this.totalContacts,
    required this.contactsWithNoStage,
    required this.contactsWithUnknownStageId,
    required this.stageCounts,
  });

  Map<String, dynamic> toJson() {
    return {
      'totalContacts': totalContacts,
      'contactsWithNoStage': contactsWithNoStage,
      'contactsWithUnknownStageId': contactsWithUnknownStageId,
      'stageCounts': stageCounts.map((e) => e.toJson()).toList(),
    };
  }

  /// Logs the validation report to console/debugPrint as required in SECTION 7.
  void logReport() {
    final buffer = StringBuffer();
    buffer.writeln('\n================ LIFECYCLE STAGE COUNT REPORT ================');
    buffer.writeln('Total Contacts: $totalContacts\n');
    for (final stage in stageCounts) {
      buffer.writeln('${stage.stageName}: ${stage.count}');
    }
    buffer.writeln('\nContacts with no lifecycle stage: $contactsWithNoStage');
    buffer.writeln('Contacts with unknown lifecycle stage ID: $contactsWithUnknownStageId');
    buffer.writeln('==============================================================\n');

    debugPrint(buffer.toString());
  }
}

/// Analyzer utility to count contacts by their configured master lifecycle stages.
class ContactLifecycleAnalyzer {
  static const List<LifecycleStageModel> defaultContactStages = [
    LifecycleStageModel(id: 'stage_added', name: 'Added', position: 0, entityType: 'contact'),
    LifecycleStageModel(id: 'stage_subscriber', name: 'Subscriber', position: 1, entityType: 'contact'),
    LifecycleStageModel(id: 'stage_lead', name: 'Lead', position: 2, entityType: 'contact'),
    LifecycleStageModel(id: 'stage_mql', name: 'Marketing Qualified Lead', position: 3, entityType: 'contact'),
    LifecycleStageModel(id: 'stage_sql', name: 'Sales Qualified Lead', position: 4, entityType: 'contact'),
    LifecycleStageModel(id: 'stage_opportunity', name: 'Opportunity', position: 5, entityType: 'contact'),
    LifecycleStageModel(id: 'stage_customer', name: 'Customer', position: 6, entityType: 'contact'),
    LifecycleStageModel(id: 'stage_evangelist', name: 'Evangelist', position: 7, entityType: 'contact'),
    LifecycleStageModel(id: 'stage_other', name: 'Other', position: 8, entityType: 'contact'),
  ];

  static ContactLifecycleAnalysisSummary analyze({
    required List<ContactModel> contacts,
    List<LifecycleStageModel>? masterStages,
  }) {
    final stages = (masterStages != null && masterStages.isNotEmpty)
        ? List<LifecycleStageModel>.from(masterStages)
        : List<LifecycleStageModel>.from(defaultContactStages);

    // Keep stage order from position field
    stages.sort((a, b) => a.position.compareTo(b.position));

    final Map<String, int> countsMap = {};
    for (final stage in stages) {
      countsMap[stage.id] = 0;
    }

    int contactsWithNoStage = 0;
    int contactsWithUnknownStageId = 0;

    for (final contact in contacts) {
      final rawId = contact.lifecycleStageId?.trim();
      final rawName = contact.lifecycleStage?.trim();

      if ((rawId == null || rawId.isEmpty) && (rawName == null || rawName.isEmpty)) {
        contactsWithNoStage++;
        continue;
      }

      // 1. Match by stage ID first
      LifecycleStageModel? matchedStage;
      if (rawId != null && rawId.isNotEmpty) {
        matchedStage = stages.firstWhere(
          (s) => s.id == rawId,
          orElse: () => stages.firstWhere(
            (s) => s.name.trim().toLowerCase() == rawId.toLowerCase(),
            orElse: () => const LifecycleStageModel(id: '', name: '', position: -1, entityType: ''),
          ),
        );
      }

      // 2. Fallback match by stage Name if ID did not match valid stage
      if ((matchedStage == null || matchedStage.id.isEmpty) && rawName != null && rawName.isNotEmpty) {
        matchedStage = stages.firstWhere(
          (s) => s.name.trim().toLowerCase() == rawName.toLowerCase(),
          orElse: () => const LifecycleStageModel(id: '', name: '', position: -1, entityType: ''),
        );
      }

      if (matchedStage != null && matchedStage.id.isNotEmpty) {
        countsMap[matchedStage.id] = (countsMap[matchedStage.id] ?? 0) + 1;
      } else {
        contactsWithUnknownStageId++;
      }
    }

    final stageCounts = stages.map((stage) {
      return ContactLifecycleCountResult(
        stageId: stage.id,
        stageName: stage.name,
        count: countsMap[stage.id] ?? 0,
        position: stage.position,
      );
    }).toList();

    final summary = ContactLifecycleAnalysisSummary(
      totalContacts: contacts.length,
      contactsWithNoStage: contactsWithNoStage,
      contactsWithUnknownStageId: contactsWithUnknownStageId,
      stageCounts: stageCounts,
    );

    summary.logReport();
    return summary;
  }
}
