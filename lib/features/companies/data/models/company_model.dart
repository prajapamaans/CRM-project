import 'package:flutter/material.dart';

class CompanyModel {
  final String id;
  final String name;
  final String? domain;
  final String? websiteUrl;
  final String? industryName;
  final String? companySize;
  final String? phone;
  final String? city;
  final String? state;
  final String? country;
  final num? annualRevenue;
  final String? leadStatus;
  final String? lifecycleStage;
  final int? contactCount;
  final String? createdAt;
  final String? ownerId;
  final String? ownerName;
  final String? msp;
  final List<Map<String, dynamic>>? contacts;
  final List<Map<String, dynamic>>? deals;
  final List<Map<String, dynamic>>? associatedCompanies;

  const CompanyModel({
    required this.id,
    required this.name,
    this.domain,
    this.websiteUrl,
    this.industryName,
    this.companySize,
    this.phone,
    this.city,
    this.state,
    this.country,
    this.annualRevenue,
    this.leadStatus,
    this.lifecycleStage,
    this.contactCount,
    this.createdAt,
    this.ownerId,
    this.ownerName,
    this.msp,
    this.contacts,
    this.deals,
    this.associatedCompanies,
  });

  factory CompanyModel.fromJson(Map<String, dynamic> json) {
    final rawRevenue = json['annualRevenue'] ?? json['annual_revenue'];
    num? rev;
    if (rawRevenue is num) {
      rev = rawRevenue;
    } else if (rawRevenue is String) {
      rev = num.tryParse(rawRevenue);
    }

    final rawCount = json['contactCount'] ?? json['contact_count'] ?? json['contactsCount'];
    int? count;
    if (rawCount is num) {
      count = rawCount.toInt();
    } else if (rawCount is String) {
      count = int.tryParse(rawCount);
    }

    String? parsedMsp;
    dynamic rawMsp = json['msp'] ?? json['msps'] ?? json['associatedMsps'] ?? json['associated_msps'];
    if (rawMsp != null) {
      if (rawMsp is String) {
        parsedMsp = rawMsp;
      } else if (rawMsp is List) {
        final listItems = rawMsp.map((e) {
          if (e is Map) {
            return (e['name'] ?? e['title'] ?? e['label'] ?? e.toString()).toString();
          }
          return e.toString();
        }).where((s) => s.isNotEmpty).toList();
        if (listItems.isNotEmpty) {
          parsedMsp = listItems.join(', ');
        }
      } else if (rawMsp is Map) {
        parsedMsp = (rawMsp['name'] ?? rawMsp['title'] ?? rawMsp['label'])?.toString();
      }
    }

    return CompanyModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? json['companyName'] as String? ?? json['company_name'] as String? ?? '',
      domain: json['domain'] as String?,
      websiteUrl: json['website'] as String? ?? json['websiteUrl'] as String? ?? json['website_url'] as String?,
      industryName: json['industry'] as String? ?? json['industryName'] as String? ?? json['industry_name'] as String?,
      companySize: json['companySize'] as String? ?? json['company_size'] as String? ?? json['size'] as String?,
      phone: json['phone'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      country: json['country'] as String?,
      annualRevenue: rev,
      leadStatus: json['leadStatus'] as String? ?? json['lead_status'] as String?,
      lifecycleStage: json['lifecycleStage'] as String? ?? json['lifecycle_stage'] as String?,
      contactCount: count,
      createdAt: json['createdAt'] as String? ?? json['created_at'] as String?,
      ownerId: json['ownerId'] as String? ?? json['owner_id'] as String?,
      ownerName: json['ownerName'] as String? ?? json['owner_name'] as String?,
      msp: parsedMsp,
      contacts: (json['contacts'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      deals: (json['deals'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      associatedCompanies: (json['associatedCompanies'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );
  }

  String get initials {
    if (name.isNotEmpty) {
      final parts = name.trim().split(' ');
      if (parts.length >= 2 && parts[1].isNotEmpty) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return name[0].toUpperCase();
    }
    return 'C';
  }

  Color get logoBgColor => const Color(0xFF00A884);
  Color get logoTextColor => Colors.white;
  String get statusBadge => leadStatus ?? lifecycleStage ?? 'Company';
  String get industry => industryName ?? 'General';
  String get website => websiteUrl ?? domain ?? 'No website';
  int get contactsCount => contactCount ?? 0;
  String? get location {
    final locs = [city, state, country].where((e) => e != null && e.isNotEmpty).join(', ');
    return locs.isNotEmpty ? locs : null;
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'name': name,
      if (domain != null) 'domain': domain,
      if (websiteUrl != null) 'website': websiteUrl,
      if (industryName != null) 'industry': industryName,
      if (companySize != null) 'companySize': companySize,
      if (phone != null) 'phone': phone,
      if (city != null) 'city': city,
      if (state != null) 'state': state,
      if (country != null) 'country': country,
      if (annualRevenue != null) 'annualRevenue': annualRevenue,
      if (leadStatus != null) 'leadStatus': leadStatus,
      if (lifecycleStage != null) 'lifecycleStage': lifecycleStage,
      if (msp != null) 'msp': msp,
    };
  }

  CompanyModel copyWith({
    String? id,
    String? name,
    String? domain,
    String? websiteUrl,
    String? industryName,
    String? companySize,
    String? phone,
    String? city,
    String? state,
    String? country,
    num? annualRevenue,
    String? leadStatus,
    String? lifecycleStage,
    int? contactCount,
    String? msp,
  }) {
    return CompanyModel(
      id: id ?? this.id,
      name: name ?? this.name,
      domain: domain ?? this.domain,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      industryName: industryName ?? this.industryName,
      companySize: companySize ?? this.companySize,
      phone: phone ?? this.phone,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      annualRevenue: annualRevenue ?? this.annualRevenue,
      leadStatus: leadStatus ?? this.leadStatus,
      lifecycleStage: lifecycleStage ?? this.lifecycleStage,
      contactCount: contactCount ?? this.contactCount,
      msp: msp ?? this.msp,
    );
  }

  static List<CompanyModel> get sampleCompanies => const [];
}
