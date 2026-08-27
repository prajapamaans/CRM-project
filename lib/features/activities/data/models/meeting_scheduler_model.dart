class AvailabilitySlot {
  final String start;
  final String end;

  AvailabilitySlot({
    required this.start,
    required this.end,
  });

  factory AvailabilitySlot.fromJson(Map<String, dynamic> json) {
    return AvailabilitySlot(
      start: json['start']?.toString() ?? '',
      end: json['end']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'start': start,
        'end': end,
      };
}

class AvailabilityWindow {
  final String day;
  final List<AvailabilitySlot> slots;

  AvailabilityWindow({
    required this.day,
    required this.slots,
  });

  factory AvailabilityWindow.fromJson(Map<String, dynamic> json) {
    final rawSlots = json['slots'] as List? ?? [];
    return AvailabilityWindow(
      day: json['day']?.toString() ?? '',
      slots: rawSlots
          .whereType<Map>()
          .map((e) => AvailabilitySlot.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'day': day,
        'slots': slots.map((e) => e.toJson()).toList(),
      };
}

class FormFieldModel {
  final String name;
  final String type;
  final String label;
  final bool required;

  FormFieldModel({
    required this.name,
    required this.type,
    required this.label,
    required this.required,
  });

  factory FormFieldModel.fromJson(Map<String, dynamic> json) {
    return FormFieldModel(
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? 'text',
      label: json['label']?.toString() ?? '',
      required: json['required'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type,
        'label': label,
        'required': required,
      };
}

class ReminderEmail {
  final int? timeAmount;
  final String? timeUnit;

  ReminderEmail({
    this.timeAmount,
    this.timeUnit,
  });

  int get value => timeAmount ?? 1;
  String get unit => timeUnit ?? 'day';

  factory ReminderEmail.fromJson(Map<String, dynamic> json) {
    final val = json['value'] as int? ??
        json['timeAmount'] as int? ??
        int.tryParse(json['value']?.toString() ?? json['timeAmount']?.toString() ?? '');
    final u = json['unit']?.toString() ?? json['timeUnit']?.toString();
    return ReminderEmail(
      timeAmount: val,
      timeUnit: u,
    );
  }

  Map<String, dynamic> toJson() => {
        'value': timeAmount,
        'unit': timeUnit,
        'timeAmount': timeAmount,
        'timeUnit': timeUnit,
      };
}

class AssociatedContact {
  final String? id;
  final String? name;
  final String? email;

  AssociatedContact({
    this.id,
    this.name,
    this.email,
  });

  factory AssociatedContact.fromJson(Map<String, dynamic> json) {
    return AssociatedContact(
      id: json['id']?.toString(),
      name: json['name']?.toString(),
      email: json['email']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
      };
}

/// MeetingScheduler Model representing GET /api/meeting-schedulers items.
class MeetingScheduler {
  final String id;
  final String? organizationId;
  final String? ownerId;
  final String name;
  final String slug;
  final String? eventTitle;
  final String? location;
  final String? videoconferenceLink;
  final bool cancelReschedule;
  final String? description;
  final bool collectPayments;
  final List<int> durationOptions;
  final String? timeZone;
  final List<AvailabilityWindow> availabilityWindow;
  final List<FormFieldModel> formFields;
  final String? confirmationType;
  final String? confirmationMessage;
  final String? confirmationRedirectUrl;
  final bool sendConfirmationEmail;
  final List<ReminderEmail> reminderEmails;
  final String? contactId;
  final String? departmentId;
  final String? organizerName;
  final String? organizerAvatarUrl;
  final String? organizerSlug;
  final AssociatedContact? associatedContact;

  MeetingScheduler({
    required this.id,
    this.organizationId,
    this.ownerId,
    required this.name,
    required this.slug,
    this.eventTitle,
    this.location,
    this.videoconferenceLink,
    this.cancelReschedule = true,
    this.description,
    this.collectPayments = false,
    required this.durationOptions,
    this.timeZone,
    required this.availabilityWindow,
    required this.formFields,
    this.confirmationType,
    this.confirmationMessage,
    this.confirmationRedirectUrl,
    this.sendConfirmationEmail = true,
    required this.reminderEmails,
    this.contactId,
    this.departmentId,
    this.organizerName,
    this.organizerAvatarUrl,
    this.organizerSlug,
    this.associatedContact,
  });

  // UI Backward Compatibility Helpers
  String get title => name;

  int get durationMinutes {
    if (durationOptions.isNotEmpty) return durationOptions.first;
    return 30;
  }

  String get ownerInitials {
    final orgName = organizerName ?? '';
    if (orgName.trim().isNotEmpty) {
      final parts = orgName.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
        return parts[0][0].toUpperCase();
      }
    }
    return 'AD';
  }

  factory MeetingScheduler.fromJson(Map<String, dynamic> json) {
    final idVal = json['id']?.toString() ?? json['_id']?.toString();
    final nameVal = (json['name'] ?? json['title'] ?? json['internalName'] ?? 'Meeting Scheduler').toString();
    final slugVal = (json['slug'] ?? json['url'] ?? '/scheduler').toString();

    // Parse durationOptions
    List<int> durations = [];
    if (json['durationOptions'] is List) {
      for (final item in (json['durationOptions'] as List)) {
        if (item is int) {
          durations.add(item);
        } else if (item != null) {
          final parsed = int.tryParse(item.toString());
          if (parsed != null) durations.add(parsed);
        }
      }
    }
    if (durations.isEmpty) {
      final singleDur = json['durationMinutes'] as int? ??
          json['duration'] as int? ??
          int.tryParse(json['duration']?.toString() ?? '');
      if (singleDur != null) durations.add(singleDur);
    }
    if (durations.isEmpty) {
      durations = [30];
    }

    // Parse availabilityWindow
    List<AvailabilityWindow> windows = [];
    if (json['availabilityWindow'] is List) {
      windows = (json['availabilityWindow'] as List)
          .whereType<Map>()
          .map((e) => AvailabilityWindow.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    // Parse formFields
    List<FormFieldModel> fields = [];
    if (json['formFields'] is List) {
      fields = (json['formFields'] as List)
          .whereType<Map>()
          .map((e) => FormFieldModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    // Parse reminderEmails
    List<ReminderEmail> reminders = [];
    if (json['reminderEmails'] is List) {
      reminders = (json['reminderEmails'] as List)
          .whereType<Map>()
          .map((e) => ReminderEmail.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    // Parse associatedContact
    AssociatedContact? contact;
    if (json['associatedContact'] is Map) {
      contact = AssociatedContact.fromJson(Map<String, dynamic>.from(json['associatedContact'] as Map));
    }

    return MeetingScheduler(
      id: (idVal != null && idVal.isNotEmpty)
          ? idVal
          : DateTime.now().millisecondsSinceEpoch.toString(),
      organizationId: json['organizationId']?.toString(),
      ownerId: json['ownerId']?.toString(),
      name: nameVal,
      slug: slugVal.startsWith('/') ? slugVal : '/$slugVal',
      eventTitle: json['eventTitle']?.toString(),
      location: json['location']?.toString(),
      videoconferenceLink: json['videoconferenceLink']?.toString(),
      cancelReschedule: json['cancelReschedule'] as bool? ?? json['cancelAndReschedule'] as bool? ?? true,
      description: json['description']?.toString(),
      collectPayments: json['collectPayments'] as bool? ?? false,
      durationOptions: durations,
      timeZone: json['timeZone']?.toString() ?? json['timezone']?.toString() ?? 'Asia/Calcutta',
      availabilityWindow: windows,
      formFields: fields,
      confirmationType: json['confirmationType']?.toString(),
      confirmationMessage: json['confirmationMessage']?.toString(),
      confirmationRedirectUrl: json['confirmationRedirectUrl']?.toString(),
      sendConfirmationEmail: json['sendConfirmationEmail'] as bool? ?? true,
      reminderEmails: reminders,
      contactId: json['contactId']?.toString(),
      departmentId: json['departmentId']?.toString(),
      organizerName: json['organizerName']?.toString() ?? json['ownerName']?.toString(),
      organizerAvatarUrl: json['organizerAvatarUrl']?.toString(),
      organizerSlug: json['organizerSlug']?.toString(),
      associatedContact: contact,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'organizationId': organizationId,
        'ownerId': ownerId,
        'name': name,
        'slug': slug,
        'eventTitle': eventTitle,
        'location': location,
        'videoconferenceLink': videoconferenceLink,
        'cancelReschedule': cancelReschedule,
        'description': description,
        'collectPayments': collectPayments,
        'durationOptions': durationOptions,
        'timeZone': timeZone,
        'availabilityWindow': availabilityWindow.map((e) => e.toJson()).toList(),
        'formFields': formFields.map((e) => e.toJson()).toList(),
        'confirmationType': confirmationType,
        'confirmationMessage': confirmationMessage,
        'confirmationRedirectUrl': confirmationRedirectUrl,
        'sendConfirmationEmail': sendConfirmationEmail,
        'reminderEmails': reminderEmails.map((e) => e.toJson()).toList(),
        'contactId': contactId,
        'departmentId': departmentId,
        'organizerName': organizerName,
        'organizerAvatarUrl': organizerAvatarUrl,
        'organizerSlug': organizerSlug,
        'associatedContact': associatedContact?.toJson(),
      };
}

typedef MeetingSchedulerModel = MeetingScheduler;
