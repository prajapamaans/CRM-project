/// Item model representing a sales representative's activity counts across all 5 types:
/// Call, Email, Meeting, Note, Task.
class ActivityLeaderboardItem {
  final String repName;
  final int callCount;
  final int emailCount;
  final int meetingCount;
  final int noteCount;
  final int taskCount;

  ActivityLeaderboardItem({
    required this.repName,
    this.callCount = 0,
    this.emailCount = 0,
    this.meetingCount = 0,
    this.noteCount = 0,
    this.taskCount = 0,
  });

  int get totalCount => callCount + emailCount + meetingCount + noteCount + taskCount;

  Map<String, dynamic> toJson() {
    return {
      'repName': repName,
      'callCount': callCount,
      'emailCount': emailCount,
      'meetingCount': meetingCount,
      'noteCount': noteCount,
      'taskCount': taskCount,
      'totalCount': totalCount,
    };
  }
}

/// Item model representing a contact owner and their associated contact count.
class ContactOwnerCountItem {
  final String ownerName;
  final int contactCount;

  ContactOwnerCountItem({
    required this.ownerName,
    required this.contactCount,
  });

  Map<String, dynamic> toJson() {
    return {
      'ownerName': ownerName,
      'contactCount': contactCount,
    };
  }
}

/// Item model representing a sales representative's call and meeting totals for "LAST 90 DAYS".
class CallAndMeetingRepItem {
  final String repName;
  final int callCount;
  final int meetingCount;

  CallAndMeetingRepItem({
    required this.repName,
    required this.callCount,
    required this.meetingCount,
  });

  int get totalCount => callCount + meetingCount;

  Map<String, dynamic> toJson() {
    return {
      'repName': repName,
      'callCount': callCount,
      'meetingCount': meetingCount,
      'totalCount': totalCount,
    };
  }
}
