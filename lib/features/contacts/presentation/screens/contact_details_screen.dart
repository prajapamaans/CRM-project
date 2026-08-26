import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:crmproject/core/widgets/app_refresh_indicator.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/utils/activity_utils.dart';
import '../../../../core/models/bingo_summary_model.dart';
import '../../../../core/repositories/master_data_repository.dart';
import '../../../../core/widgets/add_association_modal.dart';
import '../../../../core/widgets/record_association_sheet.dart';
import '../../../../core/storage/activity_association_storage.dart';
import '../../../../core/widgets/associate_msp_modal.dart';
import '../../../../core/widgets/bottom_nav_bar.dart';
import '../../../activities/presentation/widgets/create_task_modal.dart';
import '../../../activities/presentation/widgets/create_note_modal.dart';
import '../../../activities/presentation/widgets/create_email_modal.dart';
import '../../../activities/presentation/widgets/log_call_modal.dart';
import '../../../activities/presentation/widgets/log_meeting_modal.dart';
import '../../data/models/contact_model.dart';
import '../../data/repositories/contact_repository.dart';
import '../providers/contact_provider.dart';
import '../../../navigation/presentation/providers/navigation_provider.dart';
import 'package:crmproject/features/companies/presentation/screens/company_details_screen.dart';
import 'package:crmproject/features/companies/data/models/company_model.dart';
import 'package:crmproject/features/deals/presentation/screens/deal_details_screen.dart';
import 'package:crmproject/features/deals/data/models/deal_model.dart';

class ContactDetailsScreen extends StatefulWidget {
  final ContactModel? contact;
  final int initialTabIndex;

  const ContactDetailsScreen({
    super.key,
    this.contact,
    this.initialTabIndex = 0,
  });

  @override
  State<ContactDetailsScreen> createState() => _ContactDetailsScreenState();
}

class _ContactDetailsScreenState extends State<ContactDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _jobTitleController;
  late TextEditingController _companyController;
  late TextEditingController _ownerController;
  late TextEditingController _mspController;
  late TextEditingController _searchActivitiesController;
  late TextEditingController _startDateController;
  late TextEditingController _endDateController;

  String _lifecycleStage = 'Added';
  String _leadStatus = '';
  String? _editingFieldKey;

  // Associated records lists
  final List<Map<String, dynamic>> _associatedCompanies = [];
  final List<Map<String, dynamic>> _associatedContacts = [];
  final List<Map<String, dynamic>> _associatedDeals = [];
  List<Map<String, dynamic>> _associatedMsps = [];
  final List<Map<String, dynamic>> _associatedTasks = [];

  // Activities Tab State
  int _selectedActivitySubTab = 0;
  String _selectedDateFilter = 'All time';
  String _selectedAssigneeFilter = 'Activity assigned to';
  bool _isActivitiesCollapsed = false;
  List<Map<String, dynamic>> _activities = [];
  bool _isLoadingActivities = false;

  // AI Summary State
  BingoSummaryResponse? _bingoSummaryResponse;
  String? _aiSummary;
  bool _isLoadingAiSummary = false;

  Future<void> _fetchAiSummary(String recordType, String recordId) async {
    setState(() {
      _isLoadingAiSummary = true;
    });

    try {
      final apiService = ApiService();
      final bingoResponse = await apiService.getBingoSummary(
        recordType: recordType,
        recordId: recordId,
      );

      if (mounted) {
        setState(() {
          _bingoSummaryResponse = bingoResponse;
          if (bingoResponse.data.blocked) {
            _aiSummary = 'AI summary is blocked for this record.';
          } else if (bingoResponse.data.summary.isNotEmpty) {
            _aiSummary = bingoResponse.data.summary;
          } else {
            _aiSummary = 'No summary available for this record.';
          }
        });
      }
    } catch (e) {
      debugPrint('[ContactDetailsScreen _fetchAiSummary ERROR]: $e');
      if (mounted) {
        setState(() {
          _aiSummary = 'Failed to generate AI summary. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAiSummary = false;
        });
      }
    }
  }

  final List<String> _activitySubTabs = const [
    'All activities',
    'Notes',
    'Emails',
    'Calls',
    'Tasks',
    'Meetings',
  ];

  final List<String> _dateFilterOptions = const [
    'Today',
    'Yesterday',
    'This week',
    'Last week',
    'This month',
    'Last month',
    'This year',
    'All time',
  ];

  final List<String> _lifecycleStages = const [
    'Added',
    'Subscriber',
    'Lead',
    'Marketing Qualified Lead',
    'Sales Qualified Lead',
    'Opportunity',
    'Customer',
    'Evangelist',
  ];

  List<Map<String, dynamic>> _userList = [];
  final Set<String> _expandedActivityIds = {};
  String _lastActivityDateStr = '--';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );

    final c = widget.contact;
    _firstNameController = TextEditingController(text: c?.firstName ?? '');
    _lastNameController = TextEditingController(text: c?.lastName ?? '');
    _emailController = TextEditingController(text: c?.email ?? '');
    _phoneController = TextEditingController(text: c?.phone ?? '');
    _jobTitleController = TextEditingController(text: c?.jobTitle ?? '');
    _companyController = TextEditingController(text: c?.companyName ?? '');
    _ownerController =
        TextEditingController(text: c?.ownerName ?? 'Admin User');
    _mspController = TextEditingController(text: '');
    _searchActivitiesController = TextEditingController();
    _startDateController = TextEditingController();
    _endDateController = TextEditingController();

    _lifecycleStage = c?.lifecycleStage ?? 'Added';
    _leadStatus = c?.leadStatus ?? '';

    _fetchActivities();
    _fetchUsers();
    _fetchContactDetails();
  }

  bool _isLoadingDetails = false;

  Future<void> _fetchContactDetails() async {
    final contactId = widget.contact?.id;
    if (contactId == null || contactId.isEmpty) return;

    setState(() {
      _isLoadingDetails = true;
    });

    try {
      final repo = ContactRepositoryImpl();
      final contactModel = await repo.getContactById(contactId);

      // We also extract raw associations from response if present via dio/repo
      // raw getContactById returns associatedCompanies, deals, associatedContacts
      if (mounted) {
        setState(() {
          // Update controllers if updated
          if (contactModel.firstName != null) _firstNameController.text = contactModel.firstName!;
          if (contactModel.lastName != null) _lastNameController.text = contactModel.lastName!;
          if (contactModel.email.isNotEmpty) _emailController.text = contactModel.email;
          if (contactModel.phone != null) _phoneController.text = contactModel.phone!;
          if (contactModel.jobTitle != null) _jobTitleController.text = contactModel.jobTitle!;
          if (contactModel.companyName != null) _companyController.text = contactModel.companyName!;
          if (contactModel.ownerName != null) _ownerController.text = contactModel.ownerName!;
          if (contactModel.lifecycleStage != null) _lifecycleStage = contactModel.lifecycleStage!;
          if (contactModel.leadStatus != null) _leadStatus = contactModel.leadStatus!;

          // Update associations from API response
          _associatedCompanies.clear();
          if (contactModel.associatedCompanies != null) {
            for (final comp in contactModel.associatedCompanies!) {
              _associatedCompanies.add({
                'id': comp['id']?.toString() ?? '',
                'name': comp['name']?.toString() ?? comp['companyName']?.toString() ?? '',
                'subtext': comp['domain']?.toString() ?? comp['companyDomain']?.toString() ?? '',
                'isPrimary': comp['isPrimary'] == true || comp['primary'] == true,
              });
            }
          }

          _associatedContacts.clear();
          if (contactModel.associatedContacts != null) {
            for (final cont in contactModel.associatedContacts!) {
              final rawName = cont['name']?.toString() ?? '';
              final firstName = cont['firstName']?.toString() ?? cont['first_name']?.toString() ?? '';
              final lastName = cont['lastName']?.toString() ?? cont['last_name']?.toString() ?? '';
              final fullName = rawName.isNotEmpty ? rawName : '$firstName $lastName'.trim();
              final email = cont['email']?.toString() ?? '';

              _associatedContacts.add({
                'id': cont['id']?.toString() ?? '',
                'name': fullName.isNotEmpty ? fullName : 'Unnamed Contact',
                'subtext': email.isNotEmpty ? email : '-',
                'email': email,
                'jobTitle': cont['jobTitle']?.toString() ?? cont['job_title']?.toString() ?? '',
                'isPrimary': cont['isPrimary'] == true || cont['primary'] == true,
              });
            }
          }

          _associatedDeals.clear();
          if (contactModel.deals != null) {
            for (final d in contactModel.deals!) {
              final amt = d['amount'];
              String sub = '';
              if (d['stage'] != null && d['stage'].toString().isNotEmpty) {
                sub += d['stage'].toString();
              }
              if (amt != null) {
                if (sub.isNotEmpty) sub += ' • ';
                sub += '\$$amt';
              }
              _associatedDeals.add({
                'id': d['id']?.toString() ?? '',
                'name': d['title']?.toString() ?? d['name']?.toString() ?? '',
                'title': d['title']?.toString() ?? d['name']?.toString() ?? '',
                'amount': amt,
                'stage': d['stage']?.toString() ?? '',
                'expectedCloseDate': d['expectedCloseDate']?.toString() ?? '',
                'subtext': sub,
                'isPrimary': d['isPrimary'] == true || d['primary'] == true,
              });
            }
          }

          if (contactModel.msp != null && contactModel.msp!.isNotEmpty) {
            _mspController.text = contactModel.msp!;
            _associatedMsps = [{'name': contactModel.msp!}];
          } else {
            _associatedMsps = [];
          }
        });
      }
    } catch (e) {
      debugPrint('[ContactDetailsScreen _fetchContactDetails ERROR]: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingDetails = false;
        });
      }
    }
  }

  Future<void> _fetchUsers() async {
    try {
      final repo = MasterDataRepositoryImpl();
      final users = await repo.getReportsUsers(limit: 200);
      if (mounted) {
        setState(() {
          _userList = users;
        });
      }
    } catch (e) {
      debugPrint('[ContactDetailsScreen _fetchUsers ERROR]: $e');
    }
  }

  List<Map<String, dynamic>> get _filteredActivities {
    final search = _searchActivitiesController.text.trim().toLowerCase();

    return _activities.where((act) {
      final type = (act['type'] ?? act['activityType'] ?? '').toString().toUpperCase();
      final fieldKey = (act['fieldKey'] ?? act['field_key'] ?? '').toString().toLowerCase();

      // 1. Sub-tab filter
      if (_selectedActivitySubTab == 1) {
        // Notes
        if (!type.contains('NOTE') && !fieldKey.contains('note')) return false;
      } else if (_selectedActivitySubTab == 2) {
        // Emails
        if (!type.contains('EMAIL') && !fieldKey.contains('email')) return false;
      } else if (_selectedActivitySubTab == 3) {
        // Calls
        if (!type.contains('CALL') && !fieldKey.contains('call')) return false;
      } else if (_selectedActivitySubTab == 4) {
        // Tasks
        if (!type.contains('TASK') && !type.contains('TO-DO') && !type.contains('TO_DO') && !fieldKey.contains('task')) return false;
      } else if (_selectedActivitySubTab == 5) {
        // Meetings
        if (!type.contains('MEETING') && !fieldKey.contains('meeting')) return false;
      }

      // 2. Search query filter
      if (search.isNotEmpty) {
        final title = (act['title'] ?? act['notes'] ?? act['type'] ?? '').toString().toLowerCase();
        final notes = (act['notes'] ?? '').toString().toLowerCase();
        final ownerName = (act['creatorName'] ?? act['ownerName'] ?? act['assignedTo'] ?? '').toString().toLowerCase();
        if (!title.contains(search) && !notes.contains(search) && !ownerName.contains(search) && !type.toLowerCase().contains(search)) {
          return false;
        }
      }

      // 3. Assignee Filter
      if (_selectedAssigneeFilter != 'Activity assigned to') {
        final ownerName = (act['creatorName'] ?? act['ownerName'] ?? act['assignedTo'] ?? '').toString();
        if (_selectedAssigneeFilter == 'Unassigned') {
          if (ownerName.isNotEmpty && ownerName != 'Unassigned') return false;
        } else {
          if (!ownerName.toLowerCase().contains(_selectedAssigneeFilter.toLowerCase())) {
            return false;
          }
        }
      }

      // 4. Date Filter
      final rawDateStr = act['createdAt'] ?? act['scheduledAt'] ?? act['date'] ?? '';
      if (rawDateStr.toString().isNotEmpty) {
        DateTime? dt;
        try {
          dt = DateTime.parse(rawDateStr.toString()).toLocal();
        } catch (_) {}

        if (dt != null) {
          final now = DateTime.now();
          final todayStart = DateTime(now.year, now.month, now.day);
          final yesterdayStart = todayStart.subtract(const Duration(days: 1));

          if (_selectedDateFilter == 'Today') {
            if (dt.isBefore(todayStart)) return false;
          } else if (_selectedDateFilter == 'Yesterday') {
            if (dt.isBefore(yesterdayStart) || dt.isAfter(todayStart)) return false;
          } else if (_selectedDateFilter == 'This week') {
            final startOfWeek = todayStart.subtract(Duration(days: now.weekday - 1));
            if (dt.isBefore(startOfWeek)) return false;
          } else if (_selectedDateFilter == 'Last week') {
            final startOfThisWeek = todayStart.subtract(Duration(days: now.weekday - 1));
            final startOfLastWeek = startOfThisWeek.subtract(const Duration(days: 7));
            if (dt.isBefore(startOfLastWeek) || dt.isAfter(startOfThisWeek)) return false;
          } else if (_selectedDateFilter == 'This month') {
            final startOfMonth = DateTime(now.year, now.month, 1);
            if (dt.isBefore(startOfMonth)) return false;
          } else if (_selectedDateFilter == 'Last month') {
            final startOfThisMonth = DateTime(now.year, now.month, 1);
            final startOfLastMonth = DateTime(now.year, now.month - 1, 1);
            if (dt.isBefore(startOfLastMonth) || dt.isAfter(startOfThisMonth)) return false;
          } else if (_selectedDateFilter == 'This year') {
            final startOfYear = DateTime(now.year, 1, 1);
            if (dt.isBefore(startOfYear)) return false;
          }
        }
      }

      return true;
    }).toList();
  }

  Map<String, List<Map<String, String>>> _extractAssociations(
    Map<String, dynamic> act, {
    String? defaultCompId,
    String? defaultCompName,
    String? defaultContactId,
    String? defaultContactName,
    String? defaultDealId,
    String? defaultDealName,
  }) {
    final Map<String, List<Map<String, String>>> result = {
      'Companies': [],
      'Contacts': [],
      'Deals': [],
    };

    final rawAssoc = act['associations'];
    if (rawAssoc is Map) {
      if (rawAssoc['Companies'] is List) {
        for (final item in rawAssoc['Companies']) {
          if (item is Map) {
            final id = (item['id'] ?? item['_id'] ?? item['objectId'])?.toString();
            final name = (item['name'] ?? item['title'])?.toString() ?? 'Company';
            if (id != null && id.isNotEmpty) {
              if (!result['Companies']!.any((x) => x['id'] == id)) {
                result['Companies']!.add({'id': id, 'name': name});
              }
            }
          }
        }
      }
      if (rawAssoc['Contacts'] is List) {
        for (final item in rawAssoc['Contacts']) {
          if (item is Map) {
            final id = (item['id'] ?? item['_id'] ?? item['objectId'])?.toString();
            final name = (item['name'] ?? item['title'])?.toString() ?? 'Contact';
            if (id != null && id.isNotEmpty) {
              if (!result['Contacts']!.any((x) => x['id'] == id)) {
                result['Contacts']!.add({'id': id, 'name': name});
              }
            }
          }
        }
      }
      if (rawAssoc['Deals'] is List) {
        for (final item in rawAssoc['Deals']) {
          if (item is Map) {
            final id = (item['id'] ?? item['_id'] ?? item['objectId'])?.toString();
            final name = (item['name'] ?? item['title'])?.toString() ?? 'Deal';
            if (id != null && id.isNotEmpty) {
              if (!result['Deals']!.any((x) => x['id'] == id)) {
                result['Deals']!.add({'id': id, 'name': name});
              }
            }
          }
        }
      }
    } else if (rawAssoc is List) {
      for (final item in rawAssoc) {
        if (item is Map) {
          final id = (item['objectId'] ?? item['id'] ?? item['_id'])?.toString();
          final type = (item['objectType'] ?? item['type'])?.toString().toLowerCase();
          final name = (item['name'] ?? item['title'])?.toString();
          if (id != null && id.isNotEmpty) {
            if (type == 'company' || type == 'companies') {
              if (!result['Companies']!.any((x) => x['id'] == id)) {
                result['Companies']!.add({'id': id, 'name': name ?? 'Company'});
              }
            } else if (type == 'contact' || type == 'contacts') {
              if (!result['Contacts']!.any((x) => x['id'] == id)) {
                result['Contacts']!.add({'id': id, 'name': name ?? 'Contact'});
              }
            } else if (type == 'deal' || type == 'deals') {
              if (!result['Deals']!.any((x) => x['id'] == id)) {
                result['Deals']!.add({'id': id, 'name': name ?? 'Deal'});
              }
            }
          }
        }
      }
    }

    final cId = (act['companyId'] ?? act['company_id'] ?? (act['company'] is Map ? act['company']['id'] : null) ?? defaultCompId)?.toString();
    final cName = (act['companyName'] ?? act['company_name'] ?? (act['company'] is Map ? act['company']['name'] : null) ?? defaultCompName ?? 'Company').toString();
    if (cId != null && cId.isNotEmpty && !result['Companies']!.any((x) => x['id'] == cId)) {
      result['Companies']!.add({'id': cId, 'name': cName});
    }

    final cntId = (act['contactId'] ?? act['contact_id'] ?? (act['contact'] is Map ? act['contact']['id'] : null) ?? defaultContactId)?.toString();
    final cntName = (act['contactName'] ?? act['contact_name'] ?? (act['contact'] is Map ? act['contact']['name'] : null) ?? defaultContactName ?? 'Contact').toString();
    if (cntId != null && cntId.isNotEmpty && !result['Contacts']!.any((x) => x['id'] == cntId)) {
      result['Contacts']!.add({'id': cntId, 'name': cntName});
    }

    final dId = (act['dealId'] ?? act['deal_id'] ?? (act['deal'] is Map ? act['deal']['id'] : null) ?? defaultDealId)?.toString();
    final dName = (act['dealName'] ?? act['deal_name'] ?? (act['deal'] is Map ? act['deal']['name'] : null) ?? defaultDealName ?? 'Deal').toString();
    if (dId != null && dId.isNotEmpty && !result['Deals']!.any((x) => x['id'] == dId)) {
      result['Deals']!.add({'id': dId, 'name': dName});
    }

    return ActivityAssociationStorage.mergeAssociations(act, result);
  }

  Future<void> _fetchActivities() async {
    final contactId = widget.contact?.id;
    if (contactId == null || contactId.isEmpty) return;

    setState(() {
      _isLoadingActivities = true;
    });

    try {
      final repo = MasterDataRepositoryImpl();
      final results = await Future.wait([
        repo.getActivities(contactId: contactId, limit: 100),
        repo.getUnifiedTimeline(contactId: contactId, limit: 100),
        repo.getActivities(limit: 100),
      ]);
      final activitiesList = results[0];
      final timelineList = results[1];
      final allActivitiesList = results[2];

      final associatedList = allActivitiesList.where((act) {
        final cntId = (act['contactId'] ?? act['contact_id'] ?? (act['contact'] is Map ? act['contact']['id'] : null))?.toString();
        if (cntId == contactId) return true;
        if (ActivityAssociationStorage.isAssociatedWithEntity(act, 'contact', contactId)) return true;
        if (act['associations'] is Map) {
          final cnts = (act['associations'] as Map)['Contacts'];
          if (cnts is List) {
            return cnts.any((item) => (item is Map ? item['id']?.toString() : item?.toString()) == contactId);
          }
        } else if (act['associations'] is List) {
          return (act['associations'] as List).any((item) => item is Map && (item['objectId']?.toString() == contactId || item['id']?.toString() == contactId));
        }
        return false;
      }).toList();

      final combined = <Map<String, dynamic>>[...activitiesList, ...timelineList, ...associatedList];
      // Deduplicate by id if available
      final seenIds = <String>{};
      final uniqueList = <Map<String, dynamic>>[];
      for (final item in combined) {
        final id = item['id']?.toString();
        if (id != null && id.isNotEmpty) {
          if (!seenIds.contains(id)) {
            seenIds.add(id);
            uniqueList.add(item);
          }
        } else {
          uniqueList.add(item);
        }
      }

      uniqueList.sort((a, b) {
        final dtA = parseActivityDateTime(a);
        final dtB = parseActivityDateTime(b);
        return dtB.compareTo(dtA);
      });

        String updatedLastDate = '--';
        if (uniqueList.isNotEmpty) {
          final dt = parseActivityDateTime(uniqueList.first);
          if (dt.millisecondsSinceEpoch > 0) {
            final local = dt.toLocal();
            updatedLastDate = '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
          }
        }

        if (mounted) {
          setState(() {
            _activities = uniqueList;
            _lastActivityDateStr = updatedLastDate;
          });
        }
    } catch (e) {
      debugPrint('[ContactDetailsScreen _fetchActivities ERROR]: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingActivities = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _jobTitleController.dispose();
    _companyController.dispose();
    _ownerController.dispose();
    _mspController.dispose();
    _searchActivitiesController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  String get _displayName {
    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();
    final full = '$first $last'.trim();
    if (full.isNotEmpty) return full;
    if (_emailController.text.trim().isNotEmpty) {
      return _emailController.text.trim();
    }
    return 'Contact Details';
  }

  String get _initialLetter {
    final name = _displayName;
    if (name.isNotEmpty) {
      return name[0].toUpperCase();
    }
    return 'X';
  }

  String get _formattedCreateDate {
    final rawDate = widget.contact?.createdAt;
    if (rawDate != null) {
      final dt = parseActivityDateTime(rawDate);
      if (dt.millisecondsSinceEpoch != 0) {
        return formatActivityDateTime(dt.toLocal());
      }
    }
    return '08/04/2026\n2:12 PM\nGMT+5:30';
  }

  String get _formattedLastActivityDate {
    return formatLastActivityDateFromList(_activities, fallback: _lastActivityDateStr);
  }

  Future<void> _saveContactChanges() async {
    final contactId = widget.contact?.id;
    if (contactId == null || contactId.isEmpty) return;

    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final jobTitle = _jobTitleController.text.trim();
    final companyName = _companyController.text.trim();
    final ownerName = _ownerController.text.trim();

    final payload = <String, dynamic>{
      'firstName': first,
      'first_name': first,
      'lastName': last,
      'last_name': last,
      'email': email,
      'phone': phone,
      'jobTitle': jobTitle,
      'job_title': jobTitle,
      'companyName': companyName,
      'company_name': companyName,
      'ownerName': ownerName,
      'owner_name': ownerName,
      'lifecycleStage': _lifecycleStage,
      'lifecycle_stage': _lifecycleStage,
      if (_leadStatus.isNotEmpty) ...{
        'leadStatus': _leadStatus,
        'lead_status': _leadStatus,
      },
      if (_lastActivityDateStr.isNotEmpty && _lastActivityDateStr != '--') ...{
        'lastContacted': _lastActivityDateStr,
        'lastActivityDate': _lastActivityDateStr,
        'last_activity_date': _lastActivityDateStr,
      },
    };

    final success = await context.read<ContactProvider>().updateContact(contactId, payload);

    if (mounted) {
      final updatedCont = context.read<ContactProvider>().selectedContact;
      if (updatedCont != null) {
        if (updatedCont.firstName != null) _firstNameController.text = updatedCont.firstName!;
        if (updatedCont.lastName != null) _lastNameController.text = updatedCont.lastName!;
        if (updatedCont.email.isNotEmpty) _emailController.text = updatedCont.email;
        if (updatedCont.phone != null) _phoneController.text = updatedCont.phone!;
        if (updatedCont.jobTitle != null) _jobTitleController.text = updatedCont.jobTitle!;
        if (updatedCont.companyName != null) _companyController.text = updatedCont.companyName!;
        if (updatedCont.ownerName != null) _ownerController.text = updatedCont.ownerName!;
        if (updatedCont.lifecycleStage != null && updatedCont.lifecycleStage!.isNotEmpty) {
          _lifecycleStage = updatedCont.lifecycleStage!;
        }
        if (updatedCont.leadStatus != null) {
          _leadStatus = updatedCont.leadStatus!;
        }
      }
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Contact updated successfully' : 'Failed to update contact',
          ),
          backgroundColor: success ? const Color(0xFF00A884) : Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 56,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: InkWell(
              onTap: () => Navigator.of(context).pop(),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: Color(0xFF334155),
                  size: 20,
                ),
              ),
            ),
          ),
        ),
        title: Text(
          _displayName,
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E293B),
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              _fetchActivities();
              _fetchUsers();
              _fetchContactDetails();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Refreshing contact data...'),
                  backgroundColor: Color(0xFF00A884),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            icon: const Icon(
              Icons.refresh_rounded,
              color: Color(0xFF00A884),
              size: 24,
            ),
            tooltip: 'Refresh Contact Data',
          ),
          IconButton(
            onPressed: () {},
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.notifications_none_rounded,
                  color: Color(0xFF1E293B),
                  size: 24,
                ),
                Positioned(
                  right: -1,
                  top: -1,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF5252),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Top 2 Action Cards Row (Task & Note)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      _openActivityModal('Task');
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Color(0xFFE6F4F1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.task_alt_outlined,
                              color: Color(0xFF00A884),
                              size: 20,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Task',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      _openActivityModal('Note');
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Color(0xFFE6F4F1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.more_horiz_rounded,
                              color: Color(0xFF00A884),
                              size: 20,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Note',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Tab Bar Navigation
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF00A884),
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: const Color(0xFF00A884),
              indicatorWeight: 2.5,
              labelStyle: GoogleFonts.poppins(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: GoogleFonts.poppins(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
              tabs: [
                const Tab(text: 'Overview'),
                const Tab(text: 'Activities'),
                Tab(
                  text:
                      'Associations (${_associatedCompanies.length + _associatedContacts.length + _associatedMsps.length + _associatedDeals.length})',
                ),
              ],
            ),
          ),

          // Tab Bar Views
          Expanded(
            child: AppRefreshIndicator(
              onRefresh: () async {
                await _fetchContactDetails();
                await _fetchActivities();
              },
              child: Stack(
                children: [
                  TabBarView(
                    controller: _tabController,
                    children: [
                      // 1. Overview Tab
                      _buildOverviewTab(),

                      // 2. Activities Tab
                      _buildActivitiesTab(),

                      // 3. Associations Tab
                      _buildAssociationsTab(),
                    ],
                  ),
                  if (_isLoadingDetails)
                    Container(
                      color: Colors.white.withValues(alpha: 0.6),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF00A884),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: 1, // Contacts Tab
        onTap: (index) {
          context.read<NavigationProvider>().selectScreen(index);
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
      ),
    );
  }

  // ==========================================
  // TAB 1: OVERVIEW TAB
  // ==========================================
  Widget _buildOverviewTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        // 1. Profile Summary Card
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFFCBD5E1), width: 1),
                        ),
                        child: Center(
                          child: Text(
                            _initialLetter,
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF334155),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: -3,
                        bottom: -3,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _editingFieldKey = 'firstName';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFF00A884),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit_rounded,
                              size: 11,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _displayName,
                                style: GoogleFonts.poppins(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                _fetchActivities();
                                _fetchUsers();
                                _fetchContactDetails();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Refreshing contact data...'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE6F4F1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF64D2B7), width: 1),
                                ),
                                child: const Icon(
                                  Icons.refresh_rounded,
                                  size: 18,
                                  color: Color(0xFF00A884),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _jobTitleController.text.trim().isNotEmpty
                              ? _jobTitleController.text.trim()
                              : 'No job title',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Action Icons Bar (Note, Email, Call, Task, Meeting)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildActionButton(Icons.description_outlined, 'Note'),
                  _buildActionButton(Icons.mail_outline_rounded, 'Email'),
                  _buildActionButton(Icons.phone_outlined, 'Call'),
                  _buildActionButton(Icons.task_alt_rounded, 'Task'),
                  _buildActionButton(Icons.videocam_outlined, 'Meeting'),
                ],
              ),
            ],
          ),
        ),

        // 2. Contact stage tracker Card
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Contact stage tracker',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    'Lifecycle stage: ',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (val) {
                      setState(() {
                        _lifecycleStage = val;
                      });
                      _saveContactChanges();
                    },
                    offset: const Offset(0, 30),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    itemBuilder: (context) => _lifecycleStages
                        .map((s) => PopupMenuItem(
                              value: s,
                              child: Text(
                                s,
                                style: GoogleFonts.poppins(fontSize: 13),
                              ),
                            ))
                        .toList(),
                    child: Row(
                      children: [
                        Text(
                          _lifecycleStage,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF00A884),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Color(0xFF00A884),
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Progress Bar (8 Boxes Row)
              Row(
                children: List.generate(8, (index) {
                  final int currentStageIndex = _lifecycleStages.indexWhere(
                    (s) => s.trim().toLowerCase() == _lifecycleStage.trim().toLowerCase(),
                  );
                  final int activeIndex = currentStageIndex >= 0 ? currentStageIndex : 0;
                  final bool isCompleted = index <= activeIndex;
                  return Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _lifecycleStage = _lifecycleStages[index];
                        });
                        _saveContactChanges();
                      },
                      child: Container(
                        height: 24,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? const Color(0xFF00A884)
                              : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: isCompleted
                            ? const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 16,
                              )
                            : null,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              Text(
                'Lead status',
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 4),
              PopupMenuButton<String>(
                onSelected: (val) {
                  setState(() {
                    _leadStatus = val;
                  });
                  _saveContactChanges();
                },
                itemBuilder: (context) => [
                  'New',
                  'Open',
                  'In Progress',
                  'Unqualified',
                  'Attempted to Contact',
                  'Connected'
                ]
                    .map((s) => PopupMenuItem(
                          value: s,
                          child: Text(s, style: GoogleFonts.poppins(fontSize: 13)),
                        ))
                    .toList(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _leadStatus.isNotEmpty ? _leadStatus : 'Select a status',
                      style: GoogleFonts.poppins(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF64748B),
                      size: 18,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 3. Data highlights Card
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Data highlights',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CREATE DATE',
                          style: GoogleFonts.poppins(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF64748B),
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formattedCreateDate,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            height: 1.3,
                            color: const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LIFECYCLE STAGE',
                          style: GoogleFonts.poppins(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF64748B),
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _lifecycleStage,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LAST ACTIVITY DATE',
                          style: GoogleFonts.poppins(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF64748B),
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formattedLastActivityDate,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            height: 1.3,
                            color: const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // 4. About this contact Section (with edit icons on every field)
        Container(
          margin: const EdgeInsets.fromLTRB(16, 6, 16, 24),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'About this contact',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 16),
              _buildAboutField('Contact Owner', 'owner', _ownerController),
              _buildAboutField('First Name', 'firstName', _firstNameController),
              _buildAboutField('Last Name', 'lastName', _lastNameController),
              _buildAboutField('Email', 'email', _emailController),
              _buildAboutField('Phone Number', 'phone', _phoneController),
              _buildAboutField('Job Title', 'jobTitle', _jobTitleController),
              _buildAboutField('Company', 'company', _companyController),
              _buildAboutField(
                'Lifecycle Stage',
                'lifecycleStage',
                TextEditingController(text: _lifecycleStage),
                options: _lifecycleStages,
                onSelectedOption: (selected) {
                  setState(() {
                    _lifecycleStage = selected;
                  });
                  _saveContactChanges();
                },
              ),
              _buildAboutField(
                'Lead Status',
                'leadStatus',
                TextEditingController(
                    text: _leadStatus.isNotEmpty ? _leadStatus : '--'),
                options: const [
                  'New',
                  'Open',
                  'In Progress',
                  'Open Deal',
                  'Unqualified',
                  'Attempted to Contact',
                  'Connected',
                  'Bad Timing'
                ],
                onSelectedOption: (selected) {
                  setState(() {
                    _leadStatus = selected;
                  });
                  _saveContactChanges();
                },
              ),
              _buildAboutField(
                'MSP',
                'msp',
                _mspController,
                options: const ['MSP 1', 'MSP 2', 'MSP 3', 'None'],
                onSelectedOption: (selected) {
                  setState(() {
                    _mspController.text = selected;
                  });
                  _saveContactChanges();
                },
              ),
              _buildAboutField(
                'Priority',
                'priority',
                TextEditingController(text: 'Medium'),
                options: const ['Low', 'Medium', 'High'],
                onSelectedOption: (selected) {
                  _saveContactChanges();
                },
              ),
              _buildAboutField('Last Contacted', 'lastContacted', TextEditingController(text: _lastActivityDateStr)),
              _buildAboutField('Last Activity Date', 'lastActivityDate', TextEditingController(text: _lastActivityDateStr)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmAndDeleteActivity(Map<String, dynamic> act) async {
    final actId = (act['id'] ?? act['_id'] ?? '').toString();
    if (actId.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Activity', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete this activity?', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final type = (act['type'] ?? '').toString().toLowerCase();
      try {
        if (type.contains('task')) {
          await ApiService().delete('/tasks/$actId');
        } else {
          await ApiService().delete('${ApiConstants.activities}/$actId');
        }
      } catch (_) {
        try {
          await ApiService().delete('${ApiConstants.activities}/$actId');
        } catch (e) {
          debugPrint('[DELETE ACTIVITY ERROR]: $e');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Activity deleted successfully'),
            backgroundColor: Color(0xFF00A884),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _fetchActivities();
      }
    }
  }

  Future<void> _editActivityModal(Map<String, dynamic> act) async {
    final actId = (act['id'] ?? act['_id'] ?? '').toString();
    final type = (act['type'] ?? act['activityType'] ?? '').toString().toLowerCase();
    final rawNotes = act['notes'] ?? act['content'] ?? act['body'] ?? act['description'] ?? '';
    final notesText = parseActivityDescription(rawNotes);
    final rawTitle = act['title'] ?? act['subject'] ?? (notesText.isNotEmpty ? notesText : 'Activity');
    final titleText = parseActivityDescription(rawTitle);

    dynamic result;
    if (type.contains('task')) {
      result = await CreateTaskModal.show(
        context,
        taskToEdit: TaskModel(
          id: actId,
          title: titleText,
          dueDate: (act['dueDate'] ?? act['due_date'] ?? act['scheduledAt'] ?? 'Today').toString(),
          priority: (act['priority'] ?? 'Medium').toString(),
          status: (act['status'] ?? 'PENDING').toString(),
          assignedTo: (act['ownerName'] ?? act['assignedTo'] ?? 'Admin User').toString(),
          notes: notesText,
          rawMap: act,
        ),
        contactId: widget.contact?.id,
        associatedRecordName: widget.contact?.name ?? widget.contact?.firstName ?? 'Contact',
      );
    } else if (type.contains('email')) {
      result = await CreateEmailModal.show(
        context,
        emailToEdit: act,
        contactId: widget.contact?.id,
        associatedRecordName: widget.contact?.name ?? widget.contact?.firstName ?? 'Contact',
      );
    } else if (type.contains('note')) {
      result = await CreateNoteModal.show(
        context,
        noteToEdit: act,
        contactId: widget.contact?.id,
        associatedRecordName: widget.contact?.name ?? widget.contact?.firstName ?? 'Contact',
      );
    } else if (type.contains('call')) {
      result = await LogCallModal.show(
        context,
        callToEdit: CallModel(
          id: actId,
          title: titleText,
          outcome: (act['outcome'] ?? 'Connected').toString(),
          duration: (act['duration'] ?? '5m').toString(),
          startTime: (act['startTime'] ?? '10:00 AM').toString(),
          notes: notesText,
          rawMap: act,
        ),
        contactId: widget.contact?.id,
        associatedRecordName: widget.contact?.name ?? widget.contact?.firstName ?? 'Contact',
      );
    } else if (type.contains('meeting')) {
      result = await LogMeetingModal.show(
        context,
        existingMeeting: MeetingModel(
          id: actId,
          title: titleText,
          outcome: (act['outcome'] ?? 'Completed').toString(),
          duration: (act['duration'] ?? '30m').toString(),
          startTime: (act['startTime'] ?? '10:00 AM').toString(),
          notes: notesText,
          rawMap: act,
        ),
        contactId: widget.contact?.id,
        associatedRecordName: widget.contact?.name ?? widget.contact?.firstName ?? 'Contact',
      );
    } else {
      result = await CreateNoteModal.show(
        context,
        noteToEdit: act,
        contactId: widget.contact?.id,
        associatedRecordName: widget.contact?.name ?? widget.contact?.firstName ?? 'Contact',
      );
    }

    if (mounted && result != null && result != false) {
      _fetchActivities();
    }
  }

  // ==========================================
  // TAB 2: ACTIVITIES TAB
  // ==========================================
  Widget _buildActivitiesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Horizontal Sub-Tabs Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(_activitySubTabs.length, (index) {
                    final isSelected = _selectedActivitySubTab == index;
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedActivitySubTab = index;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: isSelected
                                  ? const Color(0xFF1E293B)
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                        child: Text(
                          _activitySubTabs[index],
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w600,
                            color: isSelected
                                ? const Color(0xFF1E293B)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 16),

              // 2. Search activities Bar
              Container(
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  controller: _searchActivitiesController,
                  onChanged: (_) {
                    setState(() {});
                  },
                  decoration: InputDecoration(
                    hintText: 'Search activities',
                    hintStyle: GoogleFonts.poppins(
                      fontSize: 13,
                      color: const Color(0xFF94A3B8),
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF94A3B8),
                      size: 20,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 3. Filter Controls Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          // Date Filter Dropdown (Opens Filter Sheet matching Image 3)
                          InkWell(
                            onTap: _showDateFilterDialog,
                            child: Row(
                              children: [
                                Text(
                                  '$_selectedDateFilter ',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF00A884),
                                  ),
                                ),
                                const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Color(0xFF00A884),
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Assignee Filter Dropdown
                          PopupMenuButton<String>(
                            onSelected: (val) {
                              setState(() {
                                _selectedAssigneeFilter = val;
                              });
                            },
                            itemBuilder: (context) {
                              final options = <String>[
                                'Activity assigned to',
                                'Admin User',
                                'Unassigned',
                              ];
                              for (final u in _userList) {
                                final name = '${u['firstName'] ?? u['first_name'] ?? ''} ${u['lastName'] ?? u['last_name'] ?? ''}'.trim();
                                if (name.isNotEmpty && !options.contains(name)) {
                                  options.add(name);
                                }
                              }
                              return options
                                  .map((s) => PopupMenuItem(
                                        value: s,
                                        child: Text(s,
                                            style: GoogleFonts.poppins(fontSize: 13)),
                                      ))
                                  .toList();
                            },
                            child: Row(
                              children: [
                                Text(
                                  '$_selectedAssigneeFilter ',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF00A884),
                                  ),
                                ),
                                const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Color(0xFF00A884),
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Collapse/Expand button
                  InkWell(
                    onTap: () {
                      setState(() {
                        _isActivitiesCollapsed = !_isActivitiesCollapsed;
                      });
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isActivitiesCollapsed ? 'Expand all ' : 'Collapse all ',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF00A884),
                          ),
                        ),
                        Icon(
                          _isActivitiesCollapsed
                              ? Icons.keyboard_arrow_down_rounded
                              : Icons.keyboard_arrow_up_rounded,
                          color: const Color(0xFF00A884),
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Show Create button ONLY on specific activity sub-tabs (Notes, Emails, Calls, Tasks, Meetings)
              if (_selectedActivitySubTab != 0) ...[
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () {
                      final tabName = _activitySubTabs[_selectedActivitySubTab];
                      final modalType = tabName == 'Notes'
                          ? 'Note'
                          : (tabName == 'Emails'
                              ? 'Email'
                              : (tabName == 'Calls'
                                  ? 'Call'
                                  : (tabName == 'Tasks' ? 'Task' : 'Meeting')));
                      _openActivityModal(modalType);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2B3A4A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      elevation: 0,
                    ),
                    child: Text(
                      _selectedActivitySubTab == 1
                          ? 'Create Note'
                          : (_selectedActivitySubTab == 2
                              ? 'Create Email'
                              : (_selectedActivitySubTab == 3
                                  ? 'Create Call'
                                  : (_selectedActivitySubTab == 4
                                      ? 'Create Task'
                                      : 'Create Meeting'))),
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // 4. Activity Content Grouped by Time
              if (!_isActivitiesCollapsed) ...[
                if (_isLoadingActivities)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: CircularProgressIndicator(color: Color(0xFF00A884)),
                    ),
                  )
                else if (_filteredActivities.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(
                            Icons.assignment_outlined,
                            size: 44,
                            color: Color(0xFFCBD5E1),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No activities found matching your filters',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  Text(
                    'Activities (${_filteredActivities.length})',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._filteredActivities.map((act) {
                    final type = (act['type'] ?? 'activity').toString().toUpperCase();
                    final title = act['title'] ?? act['notes'] ?? act['type'] ?? 'Activity';
                    final ownerName = act['creatorName'] ?? act['ownerName'] ?? act['assignedTo'] ?? 'Admin User';
                    final rawDate = act['createdAt'] ?? act['scheduledAt'] ?? '';
                    String formattedDate = '';
                    if (rawDate.toString().isNotEmpty) {
                      try {
                        final dt = DateTime.parse(rawDate.toString()).toLocal();
                        final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
                        final ampm = dt.hour >= 12 ? 'PM' : 'AM';
                        final min = dt.minute.toString().padLeft(2, '0');
                        final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                        formattedDate = '${months[dt.month - 1]} ${dt.day}, ${dt.year} at $h:$min $ampm GMT+5:30';
                      } catch (_) {
                        formattedDate = rawDate.toString();
                      }
                    }

                    IconData actIcon = Icons.task_alt_rounded;
                    if (type.contains('CALL')) actIcon = Icons.phone_outlined;
                    if (type.contains('MEETING')) actIcon = Icons.videocam_outlined;
                    if (type.contains('NOTE')) actIcon = Icons.description_outlined;
                    if (type.contains('EMAIL')) actIcon = Icons.mail_outline_rounded;

                    final bool isTask = type.contains('TASK') || act['type']?.toString().toLowerCase() == 'task';
                    final String statusVal = (act['status'] ?? 'PENDING').toString().toUpperCase();
                    final bool isTaskCompleted = statusVal == 'COMPLETED';
                    final String actId = (act['id'] ?? act['_id'] ?? '${type}_${title}_$formattedDate').toString();
                    final bool isExpanded = _expandedActivityIds.contains(actId);

                    return InkWell(
                      onTap: () {
                        setState(() {
                          if (isExpanded) {
                            _expandedActivityIds.remove(actId);
                          } else {
                            _expandedActivityIds.add(actId);
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isExpanded ? const Color(0xFF00A884) : const Color(0xFFE2E8F0),
                            width: isExpanded ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            isTask
                                ? SizedBox(
                                    width: 36,
                                    height: 36,
                                    child: Checkbox(
                                      value: isTaskCompleted,
                                      activeColor: const Color(0xFF00A884),
                                      onChanged: (bool? newValue) async {
                                        final newStatus = newValue == true ? 'COMPLETED' : 'PENDING';
                                        final updateData = Map<String, dynamic>.from(act);
                                        updateData['status'] = newStatus;
                                        try {
                                          await ApiService().put('${ApiConstants.activities}/$actId', data: updateData);
                                        } catch (_) {}
                                        try {
                                          await ApiService().put('/tasks/$actId', data: updateData);
                                        } catch (_) {}
                                        _fetchActivities();
                                      },
                                    ),
                                  )
                                : Container(
                                    width: 36,
                                    height: 36,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFE6F4F1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      actIcon,
                                      color: const Color(0xFF00A884),
                                      size: 18,
                                    ),
                                  ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        isExpanded
                                            ? Icons.keyboard_arrow_down_rounded
                                            : Icons.chevron_right_rounded,
                                        size: 18,
                                        color: isExpanded
                                            ? const Color(0xFF00A884)
                                            : const Color(0xFF64748B),
                                      ),
                                      const SizedBox(width: 2),
                                      Expanded(
                                        child: Text(
                                          title.toString(),
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF1E293B),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.person_outline_rounded,
                                        size: 14,
                                        color: Color(0xFF64748B),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        ownerName.toString(),
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
                                      if (formattedDate.isNotEmpty) ...[
                                        const SizedBox(width: 14),
                                        const Icon(
                                          Icons.access_time_rounded,
                                          size: 14,
                                          color: Color(0xFF64748B),
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            formattedDate,
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: const Color(0xFF64748B),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (isExpanded) ...[
                                    const SizedBox(height: 10),
                                    const Divider(color: Color(0xFFE2E8F0), height: 1),
                                    const SizedBox(height: 10),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: Text(
                                        parseActivityDescription(act['description'] ?? act['notes'] ?? title),
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          color: const Color(0xFF334155),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    InkWell(
                                      onTap: () async {
                                        final initialAssoc = _extractAssociations(
                                          act,
                                          defaultContactId: widget.contact?.id,
                                          defaultContactName: widget.contact?.name,
                                        );

                                        final result = await RecordAssociationSheet.show(
                                          context,
                                          initialAssociations: initialAssoc,
                                        );
                                        if (result != null) {
                                          final actId = (act['id'] ?? act['_id'])?.toString();
                                          final newCompId = result['Companies']?.isNotEmpty == true ? result['Companies']!.first['id'] : null;
                                          final newCompName = result['Companies']?.isNotEmpty == true ? result['Companies']!.first['name'] : null;
                                          final newCntId = result['Contacts']?.isNotEmpty == true ? result['Contacts']!.first['id'] : null;
                                          final newCntName = result['Contacts']?.isNotEmpty == true ? result['Contacts']!.first['name'] : null;
                                          final newDealId = result['Deals']?.isNotEmpty == true ? result['Deals']!.first['id'] : null;
                                          final newDealName = result['Deals']?.isNotEmpty == true ? result['Deals']!.first['name'] : null;

                                          setState(() {
                                            act['associations'] = result;
                                            act['companyId'] = newCompId;
                                            act['company_id'] = newCompId;
                                            act['companyName'] = newCompName;
                                            act['contactId'] = newCntId;
                                            act['contact_id'] = newCntId;
                                            act['contactName'] = newCntName;
                                            act['dealId'] = newDealId;
                                            act['deal_id'] = newDealId;
                                            act['dealName'] = newDealName;
                                          });

                                          if (actId != null && actId.isNotEmpty) {
                                            await ActivityAssociationStorage.saveAssociations(actId, result);
                                            try {
                                              final api = ApiService();
                                              final compIds = result['Companies']?.map((e) => e['id']).whereType<String>().toList() ?? [];
                                              final cntIds = result['Contacts']?.map((e) => e['id']).whereType<String>().toList() ?? [];
                                              final dealIds = result['Deals']?.map((e) => e['id']).whereType<String>().toList() ?? [];

                                              final List<Map<String, String>> assocList = [];
                                              for (final id in compIds) {
                                                assocList.add({'objectId': id, 'objectType': 'company'});
                                              }
                                              for (final id in cntIds) {
                                                assocList.add({'objectId': id, 'objectType': 'contact'});
                                              }
                                              for (final id in dealIds) {
                                                assocList.add({'objectId': id, 'objectType': 'deal'});
                                              }

                                              final updatePayload = Map<String, dynamic>.from(act);
                                              updatePayload['companyId'] = newCompId;
                                              updatePayload['company_id'] = newCompId;
                                              updatePayload['companyIds'] = compIds;
                                              updatePayload['company_ids'] = compIds;
                                              updatePayload['contactId'] = newCntId;
                                              updatePayload['contact_id'] = newCntId;
                                              updatePayload['contactIds'] = cntIds;
                                              updatePayload['contact_ids'] = cntIds;
                                              updatePayload['dealId'] = newDealId;
                                              updatePayload['deal_id'] = newDealId;
                                              updatePayload['dealIds'] = dealIds;
                                              updatePayload['deal_ids'] = dealIds;
                                              updatePayload['associations'] = result;
                                              updatePayload['associationsList'] = assocList;
                                              updatePayload['associations_list'] = assocList;

                                              try {
                                                await api.put('${ApiConstants.activities}/$actId', data: updatePayload);
                                              } catch (_) {
                                                try {
                                                  await api.patch('${ApiConstants.activities}/$actId', data: updatePayload);
                                                } catch (_) {
                                                  await api.post('${ApiConstants.activities}/$actId', data: updatePayload);
                                                }
                                              }
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                    content: Text('Associations updated successfully'),
                                                    duration: Duration(seconds: 1),
                                                  ),
                                                );
                                              }
                                              await _fetchActivities();
                                            } catch (e) {
                                              debugPrint('[Update Association Error]: $e');
                                            }
                                          }
                                        }
                                      },
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Builder(
                                            builder: (context) {
                                              final assocMap = _extractAssociations(
                                                act,
                                                defaultContactId: widget.contact?.id,
                                                defaultContactName: widget.contact?.name,
                                              );
                                              final cnt = assocMap['Companies']!.length + assocMap['Contacts']!.length + assocMap['Deals']!.length;
                                              return Text(
                                                '$cnt association${cnt == 1 ? '' : 's'} ',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: const Color(0xFF00A884),
                                                ),
                                              );
                                            },
                                          ),
                                          const Icon(
                                            Icons.keyboard_arrow_down_rounded,
                                            size: 16,
                                            color: Color(0xFF00A884),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(
                                Icons.more_vert_rounded,
                                color: Color(0xFF94A3B8),
                                size: 20,
                              ),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              itemBuilder: (context) => [
                                PopupMenuItem<String>(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF00A884)),
                                      const SizedBox(width: 8),
                                      Text('Edit Activity', style: GoogleFonts.poppins(fontSize: 13)),
                                    ],
                                  ),
                                ),
                                PopupMenuItem<String>(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                                      const SizedBox(width: 8),
                                      Text('Delete Activity', style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFFEF4444))),
                                    ],
                                  ),
                                ),
                              ],
                              onSelected: (action) {
                                if (action == 'delete') {
                                  _confirmAndDeleteActivity(act);
                                } else if (action == 'edit') {
                                  _editActivityModal(act);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _showActivityDetailsModal(Map<String, dynamic> act) {
    final type = (act['type'] ?? act['activityType'] ?? 'Activity').toString().toUpperCase();
    final title = act['title'] ?? act['notes'] ?? act['type'] ?? 'Activity';
    final ownerName = act['creatorName'] ?? act['ownerName'] ?? act['assignedTo'] ?? 'Admin User';
    final description = act['description'] ?? act['notes'] ?? act['message'] ?? '';
    final status = act['status'] ?? 'Completed';
    final priority = act['priority'] ?? 'Normal';
    final rawDate = act['createdAt'] ?? act['scheduledAt'] ?? act['activityDate'] ?? '';

    String formattedDate = '';
    if (rawDate.toString().isNotEmpty) {
      try {
        final dt = DateTime.parse(rawDate.toString()).toLocal();
        final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
        final ampm = dt.hour >= 12 ? 'PM' : 'AM';
        final min = dt.minute.toString().padLeft(2, '0');
        final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        formattedDate = '${months[dt.month - 1]} ${dt.day}, ${dt.year} at $h:$min $ampm';
      } catch (_) {
        formattedDate = rawDate.toString();
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 6,
          child: Padding(
            padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title.toString(),
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 10),
              _buildDetailRow('Type', type),
              _buildDetailRow('Assigned / Created By', ownerName.toString()),
              if (formattedDate.isNotEmpty) _buildDetailRow('Date', formattedDate),
              _buildDetailRow('Status', status.toString()),
              if (act['priority'] != null) _buildDetailRow('Priority', priority.toString()),
              if (act['outcome'] != null) _buildDetailRow('Outcome', act['outcome'].toString()),
              if (description.toString().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Details / Changes:',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    description.toString(),
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: const Color(0xFF334155),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      );
    },
  );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF1E293B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Date Filter Dialog matching Image 3
  void _showDateFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            width: 320,
            padding: const EdgeInsets.all(16),
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FILTER BY CREATE DATE',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._dateFilterOptions.map((opt) {
                      final bool isSelected = _selectedDateFilter == opt;
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedDateFilter = opt;
                          });
                          Navigator.of(context).pop();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                opt,
                                style: GoogleFonts.poppins(
                                  fontSize: 13.5,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? const Color(0xFF1E293B)
                                      : const Color(0xFF334155),
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_rounded,
                                  color: Color(0xFF00A884),
                                  size: 18,
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const Divider(height: 24),
                    Text(
                      'CUSTOM RANGE',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Start',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                height: 36,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: const Color(0xFF00A884)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _startDateController,
                                        style: GoogleFonts.poppins(fontSize: 12),
                                        decoration: const InputDecoration(
                                          hintText: 'dd-mm-',
                                          border: InputBorder.none,
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.calendar_today_rounded,
                                      size: 14,
                                      color: Color(0xFF64748B),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'End',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                height: 36,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: const Color(0xFFCBD5E1)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _endDateController,
                                        style: GoogleFonts.poppins(fontSize: 12),
                                        decoration: const InputDecoration(
                                          hintText: 'dd-mm-',
                                          border: InputBorder.none,
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.calendar_today_rounded,
                                      size: 14,
                                      color: Color(0xFF64748B),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF64D2B7),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: Text(
                          'Apply Range',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // TAB 3: ASSOCIATIONS TAB
  // ==========================================
  Widget _buildAssociationsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Card 1: Bingo record summary (+ AI)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFF64748B),
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Bingo record summary',
                        style: GoogleFonts.poppins(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE11D48),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '+ AI',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Generate an AI-powered summary of the profile details and recent history of this record.',
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  color: const Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
              if (_aiSummary != null && _aiSummary!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECDD3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _aiSummary!,
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF1E293B),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isLoadingAiSummary
                      ? null
                      : () {
                          final contactId = widget.contact?.id;
                          if (contactId != null && contactId.isNotEmpty) {
                            _fetchAiSummary('contact', contactId);
                          }
                        },
                  icon: _isLoadingAiSummary
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFE11D48),
                          ),
                        )
                      : const Icon(Icons.auto_awesome,
                          color: Color(0xFFE11D48), size: 16),
                  label: Text(
                    _isLoadingAiSummary ? 'Summarizing...' : 'Summarize',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFE11D48),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE11D48)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Card 2: Companies
        _buildAssociationCard(
          title: 'Companies',
          description: 'Track the companys associated with this record.',
          buttonText: 'Create company',
          entityType: 'company',
          associatedItems: _associatedCompanies,
          onPressed: () async {
            final res = await AddAssociationModal.show(context, entityType: 'company');
            if (res != null && res['action'] == 'add_existing') {
              final selected = res['selected'] as List;
              setState(() {
                for (final item in selected) {
                  final map = Map<String, dynamic>.from(item as Map);
                  if (!_associatedCompanies.any((c) => c['id'] == map['id'])) {
                    _associatedCompanies.add(map);
                  }
                }
              });
            }
          },
        ),

        // Card 3: Contacts
        _buildAssociationCard(
          title: 'Contacts',
          description: 'Track the contacts associated with this record.',
          buttonText: 'Create contact',
          entityType: 'contact',
          associatedItems: _associatedContacts,
          onPressed: () async {
            final res = await AddAssociationModal.show(context, entityType: 'contact');
            if (res != null && res['action'] == 'add_existing') {
              final selected = res['selected'] as List;
              setState(() {
                for (final item in selected) {
                  final map = Map<String, dynamic>.from(item as Map);
                  if (!_associatedContacts.any((c) => c['id'] == map['id'])) {
                    _associatedContacts.add(map);
                  }
                }
              });
            }
          },
        ),

        // Card 4: MSP
        _buildAssociationCard(
          title: 'MSP',
          description:
              'Track the Managed Service Provider (MSP) associated with this record.',
          buttonText: 'Create msp',
          entityType: 'msp',
          associatedItems: _associatedMsps,
          onPressed: () async {
            final res = await AssociateMspModal.show(context, initialMsp: _mspController.text.trim());
            if (res != null && res.isNotEmpty) {
              setState(() {
                _mspController.text = res.join(', ');
                _associatedMsps = res.map((m) => {'name': m}).toList();
              });
            }
          },
        ),

        // Card 5: Deals
        _buildAssociationCard(
          title: 'Deals',
          description: 'Track the deals associated with this record.',
          buttonText: 'Create deal',
          entityType: 'deal',
          associatedItems: _associatedDeals,
          onPressed: () async {
            final res = await AddAssociationModal.show(context, entityType: 'deal');
            if (res != null && res['action'] == 'add_existing') {
              final selected = res['selected'] as List;
              setState(() {
                for (final item in selected) {
                  final map = Map<String, dynamic>.from(item as Map);
                  if (!_associatedDeals.any((d) => d['id'] == map['id'])) {
                    _associatedDeals.add(map);
                  }
                }
              });
            }
          },
        ),

        // Card 6: Tasks
        _buildAssociationCard(
          title: 'Tasks',
          description: 'Track the tasks associated with this record.',
          buttonText: 'Create task',
          entityType: 'task',
          associatedItems: _associatedTasks,
          isTeal: true,
          topActionText: '+ Add',
          onPressed: () async {
            final contactId = widget.contact?.id;
            final res = await CreateTaskModal.show(context, contactId: contactId);
            if (res != null) {
              setState(() {
                _associatedTasks.add({'name': res.title});
                _selectedActivitySubTab = 4; // Select Tasks subtab
                _tabController.animateTo(1); // Switch to Activities tab
              });
              _fetchActivities();
            }
          },
        ),
      ],
    );
  }

  void _navigateToEntityDetails(String entityType, Map<String, dynamic> item) {
    final id = (item['id'] ?? '').toString();
    final name = (item['name'] ?? item['title'] ?? item['company_name'] ?? item['contact_name'] ?? '').toString();
    final subtext = (item['subtext'] ?? item['email'] ?? item['domain'] ?? '').toString();

    if (entityType == 'contact') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ContactDetailsScreen(
            contact: ContactModel(
              id: id,
              firstName: name,
              email: subtext,
            ),
          ),
        ),
      );
    } else if (entityType == 'company') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CompanyDetailsScreen(
            company: CompanyModel(
              id: id,
              name: name,
              domain: subtext,
            ),
          ),
        ),
      );
    } else if (entityType == 'deal') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DealDetailsScreen(
            deal: DealModel(
              id: id,
              title: name,
              amount: 0,
              stage: '',
              probability: 0,
            ),
          ),
        ),
      );
    }
  }

  Widget _buildAssociationCard({
    required String title,
    required String description,
    required String buttonText,
    required String entityType,
    List<Map<String, dynamic>> associatedItems = const [],
    bool isTeal = false,
    String? topActionText,
    VoidCallback? onPressed,
  }) {
    final bool hasItems = associatedItems.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  if (hasItems) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${associatedItems.length}',
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (topActionText != null || hasItems)
                InkWell(
                  onTap: onPressed,
                  child: Text(
                    topActionText ?? '+ Add',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF00A884),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (!hasItems)
            Text(
              description,
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                color: const Color(0xFF64748B),
              ),
            )
          else
            Column(
              children: associatedItems.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final name = (item['name'] ?? item['title'] ?? item['company_name'] ?? item['contact_name'] ?? '').toString();
                final subtext = (item['subtext'] ?? item['email'] ?? item['domain'] ?? '').toString();
                final initialLetter = name.isNotEmpty ? name[0] : 'W';
                final isPrimary = item['isPrimary'] == true || item['primary'] == true;

                return Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            initialLetter,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1E40AF),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: InkWell(
                                    onTap: () => _navigateToEntityDetails(entityType, item),
                                    child: Text(
                                      name,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF00A884),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                if (isPrimary) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: const Color(0xFFBFDBFE)),
                                    ),
                                    child: Text(
                                      'PRIMARY',
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF1E40AF),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (subtext.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                subtext,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: const Color(0xFF64748B),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(
                          Icons.more_vert,
                          color: Color(0xFF64748B),
                          size: 20,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onSelected: (value) {
                          if (value == 'primary') {
                            setState(() {
                              for (var i in associatedItems) {
                                i['isPrimary'] = false;
                                i['primary'] = false;
                              }
                              item['isPrimary'] = true;
                              item['primary'] = true;
                            });
                          } else if (value == 'remove') {
                            setState(() {
                              associatedItems.remove(item);
                            });
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem<String>(
                            value: 'primary',
                            child: Text(
                              'Set as primary',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'remove',
                            child: Text(
                              'Remove association',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: const Color(0xFFEF4444),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: isTeal || hasItems
                      ? const Color(0xFF00A884)
                      : const Color(0xFFCBD5E1),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: Text(
                hasItems
                    ? '+ Add another ${title.toLowerCase().substring(0, title.length - 1)}'
                    : buttonText,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isTeal || hasItems
                      ? const Color(0xFF00A884)
                      : const Color(0xFF334155),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // HELPER WIDGETS
  // ==========================================
  Widget _buildActionButton(IconData icon, String label) {
    return InkWell(
      onTap: () => _openActivityModal(label),
      borderRadius: BorderRadius.circular(20),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
            ),
            child: Icon(
              icon,
              size: 18,
              color: const Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  void _openActivityModal(String type) async {
    final contactId = widget.contact?.id;
    final name = widget.contact?.name.isNotEmpty == true ? widget.contact!.name : 'xyzzzz';
    dynamic result;

    if (type == 'Task') {
      result = await CreateTaskModal.show(context, contactId: contactId, associatedRecordName: name);
    } else if (type == 'Note') {
      result = await CreateNoteModal.show(context, contactId: contactId, associatedRecordName: name);
    } else if (type == 'Email') {
      result = await CreateEmailModal.show(context, contactId: contactId, associatedRecordName: name);
    } else if (type == 'Call') {
      result = await LogCallModal.show(context, contactId: contactId, associatedRecordName: name, activityType: type);
    } else if (type == 'Meeting') {
      result = await LogMeetingModal.show(context, contactId: contactId, associatedRecordName: name);
    }

    if (mounted && result != null && result != false) {
      Map<String, dynamic> newActMap = {};
      if (result is TaskModel) {
        newActMap = {
          if (result.rawMap != null) ...result.rawMap!,
          'id': result.id,
          'title': result.title,
          'type': 'task',
          'notes': result.notes,
          'description': result.notes,
          'status': result.status,
          'priority': result.priority,
          'createdAt': DateTime.now().toIso8601String(),
          'scheduledAt': result.dueDate,
          'assignedTo': result.assignedTo,
          'contactId': contactId,
          'contact_id': contactId,
        };
      } else if (result is CallModel) {
        newActMap = {
          if (result.rawMap != null) ...result.rawMap!,
          'id': result.id,
          'title': result.title,
          'type': 'call',
          'notes': result.notes,
          'description': result.notes,
          'outcome': result.outcome,
          'duration': result.duration,
          'startTime': result.startTime,
          'createdAt': DateTime.now().toIso8601String(),
          'contactId': contactId,
          'contact_id': contactId,
        };
      } else if (result is MeetingModel) {
        newActMap = {
          if (result.rawMap != null) ...result.rawMap!,
          'id': result.id,
          'title': result.title,
          'type': 'meeting',
          'notes': result.notes,
          'description': result.notes,
          'outcome': result.outcome,
          'duration': result.duration,
          'startTime': result.startTime,
          'createdAt': DateTime.now().toIso8601String(),
          'contactId': contactId,
          'contact_id': contactId,
        };
      } else if (result is Map) {
        newActMap = Map<String, dynamic>.from(result as Map);
      }

      setState(() {
        _selectedDateFilter = 'All time';
        _selectedAssigneeFilter = 'Activity assigned to';
        _searchActivitiesController.clear();
        if (type == 'Task') {
          _selectedActivitySubTab = 4; // Tasks subtab
        } else if (type == 'Note') {
          _selectedActivitySubTab = 1;
        } else if (type == 'Email') {
          _selectedActivitySubTab = 2;
        } else if (type == 'Call') {
          _selectedActivitySubTab = 3;
        } else if (type == 'Meeting') {
          _selectedActivitySubTab = 5;
        }
        if (newActMap.isNotEmpty) {
          _activities.removeWhere((item) => item['id']?.toString() == newActMap['id']?.toString());
          _activities.insert(0, newActMap);
        }
        _tabController.animateTo(1); // Switch to Activities tab
      });
      _fetchActivities();
    }
  }

  Widget _buildAboutField(
    String label,
    String key,
    TextEditingController controller, {
    bool isReadOnly = false,
    List<String>? options,
    ValueChanged<String>? onSelectedOption,
  }) {
    final bool isEditing = _editingFieldKey == key;
    final String val = controller.text.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF475569),
                  letterSpacing: 0.5,
                ),
              ),
              if (!isReadOnly && !isEditing)
                InkWell(
                  onTap: () {
                    setState(() {
                      _editingFieldKey = key;
                    });
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.all(2.0),
                    child: Icon(
                      Icons.mode_edit_outline_rounded,
                      size: 15,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (options != null && options.isNotEmpty)
            PopupMenuButton<String>(
              onSelected: (selected) {
                if (onSelectedOption != null) {
                  onSelectedOption(selected);
                }
              },
              itemBuilder: (context) => options
                  .map(
                    (opt) => PopupMenuItem<String>(
                      value: opt,
                      child: Text(
                        opt,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  )
                  .toList(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      val.isNotEmpty ? val : '--',
                      style: GoogleFonts.poppins(
                        fontSize: 13.5,
                        color: val.isNotEmpty && val != '--'
                            ? const Color(0xFF1E293B)
                            : const Color(0xFF64748B),
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF64748B),
                      size: 18,
                    ),
                  ],
                ),
              ),
            )
          else if (isEditing && !isReadOnly)
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFF00A884), width: 1.5),
                    ),
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      style: GoogleFonts.poppins(
                        fontSize: 13.5,
                        color: const Color(0xFF1E293B),
                      ),
                      decoration: const InputDecoration(
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    setState(() {
                      _editingFieldKey = null;
                    });
                    _saveContactChanges();
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00A884),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () {
                    setState(() {
                      _editingFieldKey = null;
                    });
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF64748B),
                      size: 18,
                    ),
                  ),
                ),
              ],
            )
          else
            InkWell(
              onTap: isReadOnly
                  ? null
                  : () {
                      setState(() {
                        _editingFieldKey = key;
                      });
                    },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  val.isNotEmpty ? val : '--',
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    color: val.isNotEmpty
                        ? const Color(0xFF1E293B)
                        : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
