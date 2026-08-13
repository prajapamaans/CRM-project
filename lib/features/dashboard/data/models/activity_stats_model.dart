/// Model representing activity statistics returned from GET /api/activities/stats.
class ActivityStatsModel {
  final int totalActivities;
  final int calls;
  final int meetings;
  final int emails;
  final int tasks;
  final int notes;
  final int completed;
  final int pending;
  final int callsToday;
  final int meetingsToday;
  final int emailsToday;
  final int pendingTasks;
  final int totalContacts;
  final int totalCompanies;
  final int totalDeals;
  final int totalQuotations;

  ActivityStatsModel({
    required this.totalActivities,
    required this.calls,
    required this.meetings,
    required this.emails,
    required this.tasks,
    required this.notes,
    required this.completed,
    required this.pending,
    required this.callsToday,
    required this.meetingsToday,
    required this.emailsToday,
    required this.pendingTasks,
    required this.totalContacts,
    required this.totalCompanies,
    required this.totalDeals,
    required this.totalQuotations,
  });

  factory ActivityStatsModel.fromJson(Map<String, dynamic> json) {
    return ActivityStatsModel(
      totalActivities: json['totalActivities'] as int? ?? json['total_activities'] as int? ?? 0,
      calls: json['calls'] as int? ?? 0,
      meetings: json['meetings'] as int? ?? 0,
      emails: json['emails'] as int? ?? 0,
      tasks: json['tasks'] as int? ?? 0,
      notes: json['notes'] as int? ?? 0,
      completed: json['completed'] as int? ?? 0,
      pending: json['pending'] as int? ?? 0,
      callsToday: json['callsToday'] as int? ?? json['calls_today'] as int? ?? 0,
      meetingsToday: json['meetingsToday'] as int? ?? json['meetings_today'] as int? ?? 0,
      emailsToday: json['emailsToday'] as int? ?? json['emails_today'] as int? ?? 0,
      pendingTasks: json['pendingTasks'] as int? ?? json['pending_tasks'] as int? ?? 0,
      totalContacts: json['totalContacts'] as int? ?? json['total_contacts'] as int? ?? 0,
      totalCompanies: json['totalCompanies'] as int? ?? json['total_companies'] as int? ?? 0,
      totalDeals: json['totalDeals'] as int? ?? json['total_deals'] as int? ?? 0,
      totalQuotations: json['totalQuotations'] as int? ?? json['total_quotations'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalActivities': totalActivities,
      'calls': calls,
      'meetings': meetings,
      'emails': emails,
      'tasks': tasks,
      'notes': notes,
      'completed': completed,
      'pending': pending,
      'callsToday': callsToday,
      'meetingsToday': meetingsToday,
      'emailsToday': emailsToday,
      'pendingTasks': pendingTasks,
      'totalContacts': totalContacts,
      'totalCompanies': totalCompanies,
      'totalDeals': totalDeals,
      'totalQuotations': totalQuotations,
    };
  }
}
