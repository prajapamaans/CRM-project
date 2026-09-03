import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/navigation/route_names.dart';
import '../../../../core/navigation/route_paths.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:crmproject/core/widgets/app_refresh_indicator.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/utils/activity_utils.dart';
import '../../../../core/utils/list_scroll_utils.dart';
import '../../../../core/utils/msp_field_utils.dart';
import '../../../../core/models/bingo_summary_model.dart';
import '../../../../core/providers/master_data_provider.dart';
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
import '../../../activities/presentation/widgets/task_activity_card_details.dart';
import '../../data/models/company_model.dart';
import '../../data/repositories/company_repository.dart';
import '../providers/company_provider.dart';
import '../../../navigation/presentation/providers/navigation_provider.dart';

class CompanyDetailsScreen extends StatefulWidget {
  final CompanyModel? company;
  final int initialTabIndex;

  /// Activity to scroll to and highlight in the All-activities list, e.g. the
  /// one the user tapped on the Calls, Meetings, Emails or Tasks screen.
  final String? highlightActivityId;

  /// Id of the company to show when the screen is opened by route
  /// (`/companies/details/:id`) rather than handed a loaded model.
  final String? companyId;

  const CompanyDetailsScreen({
    super.key,
    this.company,
    this.initialTabIndex = 0,
    this.highlightActivityId,
    this.companyId,
  });

  @override
  State<CompanyDetailsScreen> createState() => _CompanyDetailsScreenState();
}

class _CompanyDetailsScreenState extends State<CompanyDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  late TextEditingController _nameController;
  late TextEditingController _domainController;
  late TextEditingController _phoneController;
  late TextEditingController _industryController;
  late TextEditingController _sizeController;
  late TextEditingController _revenueController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _countryController;
  late TextEditingController _ownerController;
  late TextEditingController _searchActivitiesController;
  late TextEditingController _startDateController;
  late TextEditingController _endDateController;
  late TextEditingController _mspController;

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
      debugPrint('[CompanyDetailsScreen _fetchAiSummary ERROR]: $e');
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

  /// Id of the company on screen, whether it arrived as a loaded model or as
  /// the `:id` path parameter of `/companies/details/:id`.
  String? get _recordId {
    final routeId = widget.companyId?.trim();
    if (routeId != null && routeId.isNotEmpty) return routeId;
    return widget.company?.id;
  }

  /// Activity highlighted in the All-activities list. Seeded from
  /// [CompanyDetailsScreen.highlightActivityId] and moved when the user taps
  /// another row, so only ever one row is highlighted.
  String? _highlightedActivityId;
  final GlobalKey _highlightedActivityKey = GlobalKey();
  final ScrollController _activitiesScrollController = ScrollController();
  bool _hasScrolledToHighlight = false;
  String _lastActivityDateStr = '--';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );

    final c = widget.company;
    _nameController = TextEditingController(text: c?.name ?? '');
    _domainController = TextEditingController(text: c?.domain ?? c?.websiteUrl ?? '');
    _phoneController = TextEditingController(text: c?.phone ?? '');
    _industryController = TextEditingController(text: c?.industryName ?? '');
    _sizeController = TextEditingController(text: c?.companySize ?? '');
    _revenueController = TextEditingController(text: c?.annualRevenue?.toString() ?? '');
    _cityController = TextEditingController(text: c?.city ?? '');
    _stateController = TextEditingController(text: c?.state ?? '');
    _countryController = TextEditingController(text: c?.country ?? '');
    _ownerController = TextEditingController(text: 'Admin User');

    _searchActivitiesController = TextEditingController();
    _startDateController = TextEditingController();
    _endDateController = TextEditingController();
    _mspController = TextEditingController(text: c?.msp ?? '');

    _lifecycleStage = c?.lifecycleStage ?? 'Added';
    _leadStatus = c?.leadStatus ?? '';

    final highlightId = widget.highlightActivityId?.trim();
    if (highlightId != null && highlightId.isNotEmpty) {
      _highlightedActivityId = highlightId;
      // 'All activities' is the only sub-tab guaranteed to contain it.
      _selectedActivitySubTab = 0;
    }

    _fetchActivities();
    _fetchUsers();
    _fetchCompanyDetails();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<MasterDataProvider>().fetchCompanyMasterData();
      // This screen has an MSP field — make sure GET /api/msp-options ran.
      context.read<MasterDataProvider>().ensureMspOptionsLoaded();
    });
  }

  bool _isLoadingDetails = false;

  Future<void> _fetchCompanyDetails() async {
    final companyId = _recordId;
    if (companyId == null || companyId.isEmpty) return;

    setState(() {
      _isLoadingDetails = true;
    });

    try {
      final repo = CompanyRepositoryImpl();
      final companyModel = await repo.getCompanyById(companyId);

      if (mounted) {
        setState(() {
          if (companyModel.name.isNotEmpty) _nameController.text = companyModel.name;
          if (companyModel.domain != null) _domainController.text = companyModel.domain!;
          if (companyModel.phone != null) _phoneController.text = companyModel.phone!;
          if (companyModel.industryName != null) _industryController.text = companyModel.industryName!;
          if (companyModel.companySize != null) _sizeController.text = companyModel.companySize!;
          if (companyModel.annualRevenue != null) _revenueController.text = companyModel.annualRevenue.toString();
          if (companyModel.city != null) _cityController.text = companyModel.city!;
          if (companyModel.state != null) _stateController.text = companyModel.state!;
          if (companyModel.country != null) _countryController.text = companyModel.country!;
          if (companyModel.lifecycleStage != null && companyModel.lifecycleStage!.isNotEmpty) {
            _lifecycleStage = companyModel.lifecycleStage!;
          }

          // Populate associations returned from GET /api/companies/:id
          _associatedContacts.clear();
          if (companyModel.contacts != null) {
            for (final c in companyModel.contacts!) {
              final rawName = c['name'] as String? ?? '';
              final firstName = c['firstName'] as String? ?? c['first_name'] as String? ?? '';
              final lastName = c['lastName'] as String? ?? c['last_name'] as String? ?? '';
              final fullName = rawName.isNotEmpty
                  ? rawName
                  : '$firstName $lastName'.trim();

              final email = c['email'] as String? ?? '';

              _associatedContacts.add({
                'id': c['id']?.toString() ?? '',
                'name': fullName.isNotEmpty ? fullName : 'Unnamed Contact',
                'subtext': email.isNotEmpty ? email : '-',
                'email': email,
                'isPrimary': c['isPrimary'] == true || c['primary'] == true,
              });
            }
          }
          if (companyModel.deals != null && companyModel.deals!.isNotEmpty) {
            _associatedDeals.clear();
            _associatedDeals.addAll(companyModel.deals!);
          }
          if (companyModel.associatedCompanies != null && companyModel.associatedCompanies!.isNotEmpty) {
            _associatedCompanies.clear();
            _associatedCompanies.addAll(companyModel.associatedCompanies!);
          }
          _associatedMsps
            ..clear()
            ..addAll(MspFieldUtils.namesFrom(companyModel.msp).map(
              (name) => {
                'id': name,
                'name': name,
                'subtext': 'Managed Service Provider',
              },
            ));
        });
      }
    } catch (e) {
      debugPrint('[CompanyDetailsScreen _fetchCompanyDetails ERROR]: $e');
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
      debugPrint('[CompanyDetailsScreen _fetchUsers ERROR]: $e');
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
    final companyId = _recordId;
    if (companyId == null || companyId.isEmpty) return;

    setState(() {
      _isLoadingActivities = true;
    });

    try {
      final repo = MasterDataRepositoryImpl();
      final results = await Future.wait([
        repo.getActivities(companyId: companyId, limit: 100),
        repo.getUnifiedTimeline(companyId: companyId, limit: 100),
        repo.getActivities(limit: 100),
      ]);
      final activitiesList = results[0];
      final timelineList = results[1];
      final allActivitiesList = results[2];

      final associatedList = allActivitiesList.where((act) {
        final cId = (act['companyId'] ?? act['company_id'] ?? (act['company'] is Map ? act['company']['id'] : null))?.toString();
        if (cId == companyId) return true;
        if (ActivityAssociationStorage.isAssociatedWithEntity(act, 'company', companyId)) return true;
        if (act['associations'] is Map) {
          final comps = (act['associations'] as Map)['Companies'];
          if (comps is List) {
            return comps.any((item) => (item is Map ? item['id']?.toString() : item?.toString()) == companyId);
          }
        } else if (act['associations'] is List) {
          return (act['associations'] as List).any((item) => item is Map && (item['objectId']?.toString() == companyId || item['id']?.toString() == companyId));
        }
        return false;
      }).toList();

      final combined = <Map<String, dynamic>>[...activitiesList, ...timelineList, ...associatedList];
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
      debugPrint('[CompanyDetailsScreen _fetchActivities ERROR]: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingActivities = false;
        });
        // The timeline is populated now, so the highlighted row can be located.
        _scrollToHighlightedActivity();
      }
    }
  }

  /// Brings the highlighted activity into view once, after the timeline has
  /// loaded. Does nothing when nothing is highlighted or the activity is not in
  /// this record's timeline.
  Future<void> _scrollToHighlightedActivity() async {
    final id = _highlightedActivityId;
    if (id == null || _hasScrolledToHighlight) return;
    if (!_activities.any((a) => (a['id'] ?? a['_id'])?.toString() == id)) return;

    // Only counts as done once it actually scrolled — if the Activities tab
    // was not built yet, the next load tries again.
    _hasScrolledToHighlight = await ensureListItemVisible(
      controller: _activitiesScrollController,
      itemKey: _highlightedActivityKey,
    );
  }

  @override
  void dispose() {
    _activitiesScrollController.dispose();
    _tabController.dispose();
    _nameController.dispose();
    _domainController.dispose();
    _phoneController.dispose();
    _industryController.dispose();
    _sizeController.dispose();
    _revenueController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    _ownerController.dispose();
    _searchActivitiesController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  String get _displayName {
    final name = _nameController.text.trim();
    return name.isNotEmpty ? name : 'Company Details';
  }

  String get _initialLetter {
    final name = _displayName;
    if (name.isNotEmpty) {
      return name[0].toUpperCase();
    }
    return 'C';
  }

  String get _formattedCreateDate {
    final rawDate = widget.company?.createdAt;
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

  Future<void> _saveCompanyChanges() async {
    final companyId = _recordId ?? context.read<CompanyProvider>().selectedCompany?.id;

    final revText = _revenueController.text.trim();
    final num? revenueVal = num.tryParse(revText);
    final empText = _sizeController.text.trim();
    final int? empVal = int.tryParse(empText);

    final name = _nameController.text.trim();
    final domain = _domainController.text.trim();
    final phone = _phoneController.text.trim();
    final industry = _industryController.text.trim();
    final city = _cityController.text.trim();
    final state = _stateController.text.trim();
    final country = _countryController.text.trim();

    final payload = <String, dynamic>{
      'name': name.isNotEmpty ? name : 'Company',
      if (domain.isNotEmpty) 'domain': domain,
      if (domain.isNotEmpty) 'website': domain.startsWith('http') ? domain : 'https://$domain',
      if (phone.isNotEmpty) 'phone': phone,
      if (industry.isNotEmpty) 'industry': industry,
      if (empVal != null) 'numberOfEmployees': empVal,
      if (empText.isNotEmpty) 'companySize': empText,
      if (city.isNotEmpty) 'city': city,
      if (state.isNotEmpty) 'state': state,
      if (country.isNotEmpty) 'country': country,
      'lifecycleStage': _lifecycleStage,
      if (revenueVal != null) 'annualRevenue': revenueVal,
      if (_leadStatus.isNotEmpty) 'leadStatus': _leadStatus,
      if (_lastActivityDateStr.isNotEmpty && _lastActivityDateStr != '--') ...{
        'lastContacted': _lastActivityDateStr,
        'lastActivityDate': _lastActivityDateStr,
        'last_activity_date': _lastActivityDateStr,
      },
      // Without this the MSP About field never reached the API, so it reverted
      // on the next load. 'None' clears the field.
      'msp': _mspController.text.trim() == 'None' ? '' : _mspController.text.trim(),
    };

    bool success = true;
    if (companyId != null && companyId.isNotEmpty) {
      success = await context.read<CompanyProvider>().updateCompany(companyId, payload);
    }

    if (mounted) {
      final updatedComp = context.read<CompanyProvider>().selectedCompany;
      if (updatedComp != null) {
        if (updatedComp.name.isNotEmpty) _nameController.text = updatedComp.name;
        if (updatedComp.domain != null) _domainController.text = updatedComp.domain!;
        if (updatedComp.phone != null) _phoneController.text = updatedComp.phone!;
        if (updatedComp.industryName != null) _industryController.text = updatedComp.industryName!;
        if (updatedComp.companySize != null) _sizeController.text = updatedComp.companySize!;
        if (updatedComp.annualRevenue != null) _revenueController.text = updatedComp.annualRevenue.toString();
        if (updatedComp.city != null) _cityController.text = updatedComp.city!;
        if (updatedComp.state != null) _stateController.text = updatedComp.state!;
        if (updatedComp.country != null) _countryController.text = updatedComp.country!;
        if (updatedComp.lifecycleStage != null && updatedComp.lifecycleStage!.isNotEmpty) {
          _lifecycleStage = updatedComp.lifecycleStage!;
        }
        if (updatedComp.leadStatus != null) {
          _leadStatus = updatedComp.leadStatus!;
        }
      }
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Company updated successfully' : 'Failed to update company',
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
              _fetchCompanyDetails();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Refreshing company data...'),
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
            tooltip: 'Refresh Company Data',
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
                    onTap: () => _openActivityModal('Task'),
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
                    onTap: () => _openActivityModal('Note'),
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
                      'Associations (${_associatedContacts.length + _associatedMsps.length + _associatedDeals.length + _associatedTasks.length})',
                ),
              ],
            ),
          ),

          // Tab Bar Views
          Expanded(
            child: AppRefreshIndicator(
              onRefresh: () async {
                await _fetchCompanyDetails();
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
        currentIndex: 2, // Companies Tab
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
                              _editingFieldKey = 'name';
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
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _domainController.text.trim().isNotEmpty
                              ? _domainController.text.trim()
                              : 'No domain',
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

        // 2. Company stage tracker Card
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
                'Company stage tracker',
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
                      _saveCompanyChanges();
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
                        _saveCompanyChanges();
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
                  _saveCompanyChanges();
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

        // 4. About this company Section
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
                'About this company',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 16),
              _buildAboutField('Company Owner', 'owner', _ownerController),
              _buildAboutField('Company Name', 'name', _nameController),
              _buildAboutField('Company Domain Name', 'domain', _domainController),
              _buildAboutField('Phone Number', 'phone', _phoneController),
              _buildAboutField(
                'Lifecycle Stage',
                'lifecycleStage',
                TextEditingController(text: _lifecycleStage),
                options: _lifecycleStages,
                onSelectedOption: (selected) {
                  setState(() {
                    _lifecycleStage = selected;
                  });
                  _saveCompanyChanges();
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
                  _saveCompanyChanges();
                },
              ),
              Builder(
                builder: (context) {
                  final masterProvider = context.watch<MasterDataProvider>();
                  final mspOptionsList = <String>[
                    ...MspFieldUtils.optionsWith(
                      masterProvider,
                      _mspController.text,
                    ),
                    'None',
                  ];
                  return _buildAboutField(
                    'MSP',
                    'msp',
                    _mspController,
                    options: mspOptionsList,
                    onSelectedOption: (selected) {
                      setState(() {
                        _mspController.text = selected;
                      });
                      _saveCompanyChanges();
                    },
                  );
                },
              ),
              _buildAboutField(
                'Priority',
                'priority',
                TextEditingController(text: 'Medium'),
                options: const ['Low', 'Medium', 'High'],
                onSelectedOption: (selected) {
                  _saveCompanyChanges();
                },
              ),
              _buildAboutField('Industry', 'industry', _industryController),
              _buildAboutField('Type', 'type', _sizeController),
              _buildAboutField('City', 'city', _cityController),
              _buildAboutField('Last Contacted', 'lastContacted', TextEditingController(text: _lastActivityDateStr)),
              _buildAboutField('Last Activity Date', 'lastActivityDate', TextEditingController(text: _lastActivityDateStr)),
              _buildAboutField('STATE/REGION', 'state', _stateController),
              _buildAboutField('COUNTRY', 'country', _countryController),
              _buildAboutField('POSTAL CODE', 'postalCode', TextEditingController(text: '--')),
              _buildAboutField('NUMBER OF EMPLOYEES', 'companySize', _sizeController),
              _buildAboutField('ANNUAL REVENUE', 'revenue', _revenueController),
              _buildAboutField('TIME ZONE', 'timeZone', TextEditingController(text: '--')),
              _buildAboutField('DESCRIPTION', 'description', TextEditingController(text: '--')),
              _buildAboutField('LINKEDIN COMPANY PAGE', 'linkedin', TextEditingController(text: '--')),
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
          dueDate: (act['scheduledAt'] ?? act['scheduled_at'] ?? act['dueDate'] ?? act['due_date'] ?? '').toString(),
          priority: (act['priority'] ?? 'Medium').toString(),
          status: (act['status'] ?? 'PENDING').toString(),
          assignedTo: (act['ownerName'] ?? act['assignedTo'] ?? 'Admin User').toString(),
          notes: notesText,
          queue: (act['queue'] ?? 'None').toString(),
          rawMap: act,
        ),
        companyId: _recordId,
        associatedRecordName: widget.company?.name ?? 'Company',
      );
    } else if (type.contains('email')) {
      result = await CreateEmailModal.show(
        context,
        emailToEdit: act,
        companyId: _recordId,
        associatedRecordName: widget.company?.name ?? 'Company',
      );
    } else if (type.contains('note')) {
      result = await CreateNoteModal.show(
        context,
        noteToEdit: act,
        companyId: _recordId,
        associatedRecordName: widget.company?.name ?? 'Company',
      );
    } else if (type.contains('call')) {
      result = await LogCallModal.show(
        context,
        callToEdit: CallModel(
          id: actId,
          title: titleText,
          outcome: (act['outcome'] ?? 'Connected').toString(),
          duration: (act['durationMinutes'] ?? act['duration_minutes'] ?? act['duration'] ?? '').toString(),
          startTime: (act['scheduledAt'] ?? act['scheduled_at'] ?? act['startTime'] ?? '').toString(),
          notes: notesText,
          rawMap: act,
        ),
        companyId: _recordId,
        associatedRecordName: widget.company?.name ?? 'Company',
      );
    } else if (type.contains('meeting')) {
      result = await LogMeetingModal.show(
        context,
        existingMeeting: MeetingModel(
          id: actId,
          title: titleText,
          outcome: (act['outcome'] ?? 'Completed').toString(),
          duration: (act['durationMinutes'] ?? act['duration_minutes'] ?? act['duration'] ?? '').toString(),
          startTime: (act['scheduledAt'] ?? act['scheduled_at'] ?? act['startTime'] ?? '').toString(),
          notes: notesText,
          rawMap: act,
        ),
        companyId: _recordId,
        associatedRecordName: widget.company?.name ?? 'Company',
      );
    } else {
      result = await CreateNoteModal.show(
        context,
        noteToEdit: act,
        companyId: _recordId,
        associatedRecordName: widget.company?.name ?? 'Company',
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
      controller: _activitiesScrollController,
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
                    final title = act['title'] ?? act['notes'] ?? 'Activity';
                    final ownerName = act['ownerName'] ?? act['assignedTo'] ?? 'Admin User';
                    final createdAt = act['createdAt'] ?? act['scheduledAt'] ?? '';

                    IconData actIcon = Icons.task_alt_rounded;
                    if (type.contains('CALL')) actIcon = Icons.phone_outlined;
                    if (type.contains('MEETING')) actIcon = Icons.videocam_outlined;
                    if (type.contains('NOTE')) actIcon = Icons.description_outlined;
                    if (type.contains('EMAIL')) actIcon = Icons.mail_outline_rounded;

                    final bool isTask = type.contains('TASK') || act['type']?.toString().toLowerCase() == 'task';
                    final String statusVal = (act['status'] ?? 'PENDING').toString().toUpperCase();
                    final bool isTaskCompleted = statusVal == 'COMPLETED';
                    final String actId = (act['id'] ?? act['_id'] ?? '${type}_${title}_$createdAt').toString();
                    final bool isExpanded = _expandedActivityIds.contains(actId);
                    final bool isHighlighted = actId == _highlightedActivityId;

                    return InkWell(
                      // The key rides along with the highlight so the row can be
                      // scrolled to once the timeline has been built.
                      key: isHighlighted ? _highlightedActivityKey : null,
                      onTap: () {
                        setState(() {
                          // Selecting a row moves the highlight off the previous one.
                          _highlightedActivityId = actId;
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
                          color: isHighlighted ? const Color(0xFFE6F4F1) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isExpanded || isHighlighted
                                ? const Color(0xFF00A884)
                                : const Color(0xFFE2E8F0),
                            width: isExpanded || isHighlighted ? 1.5 : 1,
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
                                        // PATCH just the changed field: PUT is not a
                                        // route, and echoing the whole activity back
                                        // failed validation, so the toggle never stuck.
                                        final newStatus = newValue == true ? 'completed' : 'pending';
                                        try {
                                          await ApiService().patch(
                                            '${ApiConstants.activities}/$actId',
                                            data: {'status': newStatus},
                                          );
                                        } catch (e) {
                                          debugPrint('[UPDATE ACTIVITY STATUS ERROR]: $e');
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Failed to update task status: $e'),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        }
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
                                      if (createdAt.toString().isNotEmpty) ...[
                                        const SizedBox(width: 14),
                                        const Icon(
                                          Icons.access_time_rounded,
                                          size: 14,
                                          color: Color(0xFF64748B),
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            createdAt.toString(),
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
                                    if (isTask)
                                      TaskActivityCardDetails(
                                        activity: act,
                                        onManageAssociations: () async {
                                          final initialAssoc = _extractAssociations(
                                            act,
                                            defaultCompId: _recordId,
                                            defaultCompName: widget.company?.name,
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

                                                await api.patch('${ApiConstants.activities}/$actId', data: updatePayload);
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
                                      )
                                    else
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
                                           defaultCompId: _recordId,
                                           defaultCompName: widget.company?.name,
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

                                                // PATCH /api/activities/:id is the
                                                // documented update route.
                                                await api.patch('${ApiConstants.activities}/$actId', data: updatePayload);

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
                                                 defaultCompId: _recordId,
                                                 defaultCompName: widget.company?.name,
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
                          final companyId = _recordId;
                          if (companyId != null && companyId.isNotEmpty) {
                            _fetchAiSummary('company', companyId);
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
        // Card 2: Contacts
        _buildAssociationCard(
          title: 'Contacts',
          description: 'No contacts associated with this company.',
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
            final currentMsps = _associatedMsps
                .map((m) => (m['name'] ?? '').toString())
                .where((s) => s.isNotEmpty)
                .toList();
            final res = await AssociateMspModal.show(
              context,
              initialSelectedMsps: currentMsps,
            );
            if (res != null) {
              final newMspString = res.join(', ');
              setState(() {
                _associatedMsps = res.map((m) => {
                  'id': m,
                  'name': m,
                  'subtext': 'Managed Service Provider',
                }).toList();
              });

              final companyId = _recordId;
              if (companyId != null && companyId.isNotEmpty) {
                try {
                  final repo = CompanyRepositoryImpl();
                  await repo.updateCompany(companyId, {'msp': newMspString});
                } catch (e) {
                  debugPrint('[CompanyDetailsScreen updateCompany MSP ERROR]: $e');
                }
              }
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
            final companyId = _recordId;
            final res = await CreateTaskModal.show(context, companyId: companyId);
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
    if (id.isEmpty) return;

    // /contacts|companies|deals/details/:id — the target screen loads the
    // record from the id.
    const routeByType = {
      'contact': RouteNames.contactDetails,
      'company': RouteNames.companyDetails,
      'deal': RouteNames.dealDetails,
    };
    final routeName = routeByType[entityType];
    if (routeName == null) return;

    context.pushNamed(routeName, pathParameters: {RoutePaths.idParam: id});
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
    final companyId = _recordId;
    final name = widget.company?.name.isNotEmpty == true ? widget.company!.name : 'xyzzzz';
    dynamic result;

    if (type == 'Task') {
      result = await CreateTaskModal.show(context, companyId: companyId, associatedRecordName: name);
    } else if (type == 'Note') {
      result = await CreateNoteModal.show(context, companyId: companyId, associatedRecordName: name);
    } else if (type == 'Email') {
      result = await CreateEmailModal.show(context, companyId: companyId, associatedRecordName: name);
    } else if (type == 'Call') {
      result = await LogCallModal.show(context, companyId: companyId, associatedRecordName: name, activityType: type);
    } else if (type == 'Meeting') {
      result = await LogMeetingModal.show(context, companyId: companyId, associatedRecordName: name);
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
          'companyId': companyId,
          'company_id': companyId,
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
          'companyId': companyId,
          'company_id': companyId,
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
          'companyId': companyId,
          'company_id': companyId,
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
                    _saveCompanyChanges();
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
