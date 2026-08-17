import 'package:flutter/material.dart';

class ContactModel {
  final String id;
  final String? firstName;
  final String? lastName;
  final String email;
  final String? phone;
  final String? jobTitle;
  final String? companyId;
  final String? companyName;
  final String? companyAvatar;
  final String? ownerId;
  final String? ownerName;
  final String? msp;
  final String? avatarUrl;
  final String? leadStatus;
  final String? lifecycleStage;
  final String? createdAt;
  final List<Map<String, dynamic>>? associatedCompanies;
  final List<Map<String, dynamic>>? deals;
  final List<Map<String, dynamic>>? associatedContacts;

  const ContactModel({
    required this.id,
    this.firstName,
    this.lastName,
    required this.email,
    this.phone,
    this.jobTitle,
    this.companyId,
    this.companyName,
    this.companyAvatar,
    this.ownerId,
    this.ownerName,
    this.msp,
    this.avatarUrl,
    this.leadStatus,
    this.lifecycleStage,
    this.createdAt,
    this.associatedCompanies,
    this.deals,
    this.associatedContacts,
  });

  factory ContactModel.fromJson(Map<String, dynamic> json) {
    return ContactModel(
      id: json['id'] as String? ?? '',
      firstName: json['firstName'] as String? ?? json['first_name'] as String?,
      lastName: json['lastName'] as String? ?? json['last_name'] as String?,
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
      jobTitle: json['jobTitle'] as String? ?? json['job_title'] as String?,
      companyId: json['companyId'] as String? ?? json['company_id'] as String?,
      companyName: json['companyName'] as String? ?? json['company_name'] as String?,
      companyAvatar: json['companyAvatar'] as String? ?? json['company_avatar'] as String?,
      ownerId: json['ownerId'] as String? ?? json['owner_id'] as String?,
      ownerName: json['ownerName'] as String? ?? json['owner_name'] as String?,
      msp: json['msp'] as String?,
      avatarUrl: json['avatarUrl'] as String? ?? json['avatar_url'] as String?,
      leadStatus: json['leadStatus'] as String? ?? json['lead_status'] as String?,
      lifecycleStage: json['lifecycleStage'] as String? ?? json['lifecycle_stage'] as String?,
      createdAt: json['createdAt'] as String? ?? json['created_at'] as String?,
      associatedCompanies: (json['associatedCompanies'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      deals: (json['deals'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      associatedContacts: (json['associatedContacts'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );
  }

  String get name {
    final first = firstName ?? '';
    final last = lastName ?? '';
    final full = '$first $last'.trim();
    return full.isNotEmpty ? full : email;
  }

  String get initials {
    if (firstName != null && firstName!.isNotEmpty) {
      final f = firstName![0].toUpperCase();
      final l = (lastName != null && lastName!.isNotEmpty) ? lastName![0].toUpperCase() : '';
      return '$f$l';
    }
    return email.isNotEmpty ? email[0].toUpperCase() : 'C';
  }

  Color get avatarBgColor => const Color(0xFF00A884);
  String get statusBadge => leadStatus ?? lifecycleStage ?? 'Lead';
  String get title => jobTitle ?? 'Contact';
  String get company => companyName ?? 'No company';

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      if (firstName != null) 'firstName': firstName,
      if (lastName != null) 'lastName': lastName,
      'email': email,
      if (phone != null) 'phone': phone,
      if (jobTitle != null) 'jobTitle': jobTitle,
      if (companyId != null) 'companyId': companyId,
      if (companyName != null) 'companyName': companyName,
      if (companyAvatar != null) 'companyAvatar': companyAvatar,
      if (ownerId != null) 'ownerId': ownerId,
      if (ownerName != null) 'ownerName': ownerName,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      if (leadStatus != null) 'leadStatus': leadStatus,
      if (lifecycleStage != null) 'lifecycleStage': lifecycleStage,
      if (createdAt != null) 'createdAt': createdAt,
    };
  }

  ContactModel copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? jobTitle,
    String? companyId,
    String? companyName,
    String? companyAvatar,
    String? ownerId,
    String? ownerName,
    String? avatarUrl,
    String? leadStatus,
    String? lifecycleStage,
    String? createdAt,
  }) {
    return ContactModel(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      jobTitle: jobTitle ?? this.jobTitle,
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      companyAvatar: companyAvatar ?? this.companyAvatar,
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName ?? this.ownerName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      leadStatus: leadStatus ?? this.leadStatus,
      lifecycleStage: lifecycleStage ?? this.lifecycleStage,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static List<ContactModel> get sampleContacts => const [];
}
