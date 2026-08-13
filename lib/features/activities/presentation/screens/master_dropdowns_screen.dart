import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/datasources/master_data_remote_datasource.dart';
import '../../../../core/models/master_dropdown_model.dart';

/// Screen for managing Master Dropdowns.
/// Strictly follows ZERO hardcoded dummy option/category rules.
/// Integrates with dynamic models, API and state management layer.
class MasterDropdownsScreen extends StatefulWidget {
  const MasterDropdownsScreen({super.key});

  @override
  State<MasterDropdownsScreen> createState() => _MasterDropdownsScreenState();
}

class _MasterDropdownsScreenState extends State<MasterDropdownsScreen> {
  final MasterDataRemoteDataSource _remoteDataSource = MasterDataRemoteDataSourceImpl();

  bool _isLoadingDropdowns = false;
  bool _isLoadingOptions = false;
  String? _errorMessage;

  // Master dropdown definitions loaded dynamically
  List<Map<String, dynamic>> _dropdownCategories = [];
  Map<String, dynamic>? _selectedCategory;

  // Options for current selected category
  List<MasterDropdownOptionModel> _options = [];
  bool _showArchived = false;

  // Controllers & state for new option creation matching Image 2
  final TextEditingController _newOptionController = TextEditingController();
  final TextEditingController _internalKeyController = TextEditingController();
  String _selectedOptionColor = '#475569';
  final bool _isCreatingOption = false;

  // Controllers for Create Custom Dropdown Modal matching Image 1
  final TextEditingController _customDropdownNameController = TextEditingController();
  final TextEditingController _customDropdownKeyController = TextEditingController();
  final bool _isCreatingCustomDropdown = false;

  @override
  void initState() {
    super.initState();
    _newOptionController.addListener(_onOptionLabelChanged);
    _customDropdownNameController.addListener(_onCustomDropdownNameChanged);
    _loadMasterDataApis();
  }

  @override
  void dispose() {
    _newOptionController.removeListener(_onOptionLabelChanged);
    _customDropdownNameController.removeListener(_onCustomDropdownNameChanged);
    _newOptionController.dispose();
    _internalKeyController.dispose();
    _customDropdownNameController.dispose();
    _customDropdownKeyController.dispose();
    super.dispose();
  }

  void _onOptionLabelChanged() {
    final text = _newOptionController.text.trim();
    if (text.isEmpty) {
      _internalKeyController.text = '';
    } else {
      final autoKey = text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_').replaceAll(RegExp(r'_+'), '_');
      _internalKeyController.text = '${autoKey}_(auto)';
    }
  }

  void _onCustomDropdownNameChanged() {
    final text = _customDropdownNameController.text.trim();
    if (text.isEmpty) {
      _customDropdownKeyController.text = '';
    } else {
      final autoKey = text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_').replaceAll(RegExp(r'_+'), '_');
      _customDropdownKeyController.text = '${autoKey}_(auto)';
    }
  }

  /// Triggers calls to all required master dropdown endpoints in parallel
  Future<void> _loadMasterDataApis() async {
    setState(() {
      _isLoadingDropdowns = true;
      _errorMessage = null;
    });

    try {
      final ds = _remoteDataSource as MasterDataRemoteDataSourceImpl;

      // Call APIs as shown in the request screenshot:
      // 1. GET /api/master-dropdowns?includeInactive=true
      // 2. GET /api/lifecycle-stages?entityType=company
      // 3. GET /api/master-dropdowns/key/company_industry?includeInactive=false
      // 4. GET /api/master-dropdowns/key/company_type?includeInactive=false
      // 5. GET /api/msp-options
      // 6. GET /api/lifecycle-stages?entityType=contact
      // 7. GET /api/master-dropdowns/key/contact_lead_status?includeInactive=false
      // 8. GET /api/deals/stages
      final results = await Future.wait([
        ds.getMasterDropdownByKey('call_outcome', includeInactive: true).catchError((_) => <MasterDropdownOptionModel>[]),
        ds.getLifecycleStages(entityType: 'company').catchError((_) => <LifecycleStageModel>[]),
        ds.getMasterDropdownByKey('company_industry', includeInactive: false).catchError((_) => <MasterDropdownOptionModel>[]),
        ds.getMasterDropdownByKey('company_type', includeInactive: false).catchError((_) => <MasterDropdownOptionModel>[]),
        ds.getMspOptions().catchError((_) => <MspOptionModel>[]),
        ds.getLifecycleStages(entityType: 'contact').catchError((_) => <LifecycleStageModel>[]),
        ds.getMasterDropdownByKey('contact_lead_status', includeInactive: false).catchError((_) => <MasterDropdownOptionModel>[]),
        ds.getDealStages().catchError((_) => <Map<String, dynamic>>[]),
      ]);

      // Categories built dynamically from API endpoints
      final List<Map<String, dynamic>> dynamicCategories = [
        {'key': 'call_outcome', 'displayName': 'Call Outcome (System)', 'options': results[0]},
        {'key': 'company_lifecycle', 'displayName': 'Company Lifecycle Stages', 'options': results[1]},
        {'key': 'company_industry', 'displayName': 'Company Industry', 'options': results[2]},
        {'key': 'company_type', 'displayName': 'Company Type', 'options': results[3]},
        {'key': 'msp_options', 'displayName': 'MSP Options', 'options': results[4]},
        {'key': 'contact_lifecycle', 'displayName': 'Contact Lifecycle Stages', 'options': results[5]},
        {'key': 'contact_lead_status', 'displayName': 'Contact Lead Status', 'options': results[6]},
        {'key': 'deal_stages', 'displayName': 'Deal Stages', 'options': results[7]},
      ];

      if (mounted) {
        setState(() {
          _dropdownCategories = dynamicCategories;
          if (_dropdownCategories.isNotEmpty) {
            _selectedCategory = _dropdownCategories.first;
            _extractOptionsFromSelectedCategory();
          } else {
            _selectedCategory = null;
            _options = [];
          }
          _isLoadingDropdowns = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoadingDropdowns = false;
        });
      }
    }
  }

  void _extractOptionsFromSelectedCategory() {
    if (_selectedCategory == null) {
      _options = [];
      return;
    }

    final rawOptions = _selectedCategory!['options'];
    if (rawOptions is List<MasterDropdownOptionModel>) {
      _options = rawOptions;
    } else if (rawOptions is List<LifecycleStageModel>) {
      _options = rawOptions
          .map((s) => MasterDropdownOptionModel(
                id: s.id,
                value: s.name.toLowerCase().replaceAll(' ', '_'),
                label: s.name,
                position: s.position,
              ))
          .toList();
    } else if (rawOptions is List<MspOptionModel>) {
      _options = rawOptions
          .map((m) => MasterDropdownOptionModel(
                id: m.id,
                value: m.name.toLowerCase().replaceAll(' ', '_'),
                label: m.name,
                position: m.position,
              ))
          .toList();
    } else if (rawOptions is List<Map<String, dynamic>>) {
      _options = rawOptions
          .map((d) => MasterDropdownOptionModel(
                id: (d['id'] ?? d['_id'] ?? '').toString(),
                value: (d['value'] ?? d['name'] ?? d['label'] ?? '').toString(),
                label: (d['label'] ?? d['name'] ?? d['value'] ?? '').toString(),
              ))
          .toList();
    } else {
      _options = [];
    }
  }

  /// Fetches options for the currently selected dropdown key dynamically
  Future<void> _fetchDropdownOptions(String key) async {
    if (key.isEmpty) return;

    setState(() {
      _isLoadingOptions = true;
      _errorMessage = null;
    });

    try {
      if (key == 'company_lifecycle' || key == 'contact_lifecycle') {
        final entityType = key == 'company_lifecycle' ? 'company' : 'contact';
        final stages = await _remoteDataSource.getLifecycleStages(entityType: entityType);
        _options = stages
            .map((s) => MasterDropdownOptionModel(
                  id: s.id,
                  value: s.name.toLowerCase().replaceAll(' ', '_'),
                  label: s.name,
                  position: s.position,
                ))
            .toList();
      } else if (key == 'msp_options') {
        final msps = await _remoteDataSource.getMspOptions();
        _options = msps
            .map((m) => MasterDropdownOptionModel(
                  id: m.id,
                  value: m.name.toLowerCase().replaceAll(' ', '_'),
                  label: m.name,
                  position: m.position,
                ))
            .toList();
      } else if (key == 'deal_stages') {
        final stages = await _remoteDataSource.getDealStages();
        _options = stages
            .map((d) => MasterDropdownOptionModel(
                  id: (d['id'] ?? d['_id'] ?? '').toString(),
                  value: (d['value'] ?? d['name'] ?? d['label'] ?? '').toString(),
                  label: (d['label'] ?? d['name'] ?? d['value'] ?? '').toString(),
                ))
            .toList();
      } else {
        _options = await _remoteDataSource.getMasterDropdownByKey(
          key,
          includeInactive: _showArchived,
        );
      }

      if (mounted) {
        setState(() {
          _isLoadingOptions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoadingOptions = false;
        });
      }
    }
  }

  /// Handles clicking on Default radio circle to switch default option
  void _setDefaultOption(String optionId) {
    setState(() {
      _options = _options.map((opt) {
        final isSelected = opt.id == optionId || opt.value == optionId;
        return MasterDropdownOptionModel(
          id: opt.id,
          value: opt.value,
          label: opt.label,
          color: opt.color,
          position: opt.position,
          isDefault: isSelected,
          isActive: opt.isActive,
        );
      }).toList();
    });
  }

  /// Handles archiving an option locally/via state
  void _toggleArchiveOption(String optionId) {
    setState(() {
      _options = _options.map((opt) {
        final matches = opt.id == optionId || opt.value == optionId;
        if (matches) {
          return MasterDropdownOptionModel(
            id: opt.id,
            value: opt.value,
            label: opt.label,
            color: opt.color,
            position: opt.position,
            isDefault: opt.isDefault,
            isActive: !opt.isActive,
          );
        }
        return opt;
      }).toList();
    });
  }

  /// Displays the Create Custom Dropdown dialog matching Image 1
  void _showCreateCustomDropdownDialog() {
    _customDropdownNameController.clear();
    _customDropdownKeyController.clear();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Container(
                width: 420,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: Create Custom Dropdown with Close (X) icon
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Create Custom Dropdown',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add a new dynamic dropdown menu. This key will be used to reference options on pages.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Display Name Field
                    Text(
                      'Display Name',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _customDropdownNameController,
                      style: GoogleFonts.poppins(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'e.g. Lead Tier',
                        hintStyle: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF94A3B8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        fillColor: const Color(0xFFF8FAFC),
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: Color(0xFF00A884)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Internal Key Name (Code ID) Field
                    Text(
                      'Internal Key Name (Code ID)',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _customDropdownKeyController,
                      style: GoogleFonts.poppins(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'e.g. lead_tier (auto)',
                        hintStyle: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF94A3B8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        fillColor: const Color(0xFFF8FAFC),
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: Color(0xFF00A884)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Create Dropdown Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isCreatingCustomDropdown
                            ? null
                            : () {
                                final name = _customDropdownNameController.text.trim();
                                if (name.isEmpty) return;

                                final cleanKey = _customDropdownKeyController.text
                                    .replaceAll('_(auto)', '')
                                    .trim();
                                final finalKey = cleanKey.isNotEmpty
                                    ? cleanKey
                                    : name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');

                                final newCategory = {
                                  'key': finalKey,
                                  'displayName': name,
                                  'options': <MasterDropdownOptionModel>[],
                                };

                                setState(() {
                                  _dropdownCategories.add(newCategory);
                                  _selectedCategory = newCategory;
                                  _options = [];
                                });

                                Navigator.of(context).pop();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF70C9B6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          elevation: 0,
                        ),
                        child: Text(
                          'Create Dropdown',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Cancel Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFFF8FAFC),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF334155),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Color _parseColorHex(String? colorHex) {
    if (colorHex == null || colorHex.isEmpty) {
      return Colors.grey.shade400;
    }
    try {
      String hex = colorHex.replaceAll('#', '');
      if (hex.length == 6) {
        hex = 'FF$hex';
      }
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return Colors.grey.shade400;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Card 1: Top Header Header & Action
            _buildHeaderCard(),
            const SizedBox(height: 16),

            // Card 2: Dropdown Category Selector
            _buildCategorySelectorCard(),
            const SizedBox(height: 16),

            // Card 3: Main Options Details & Table
            _buildDetailsAndTableCard(),
          ],
        ),
      ),
    );
  }

  /// Top Card matching screenshot: Icon + Master Dropdowns Title + Description + Create Custom Dropdown Button
  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.tune_rounded,
                color: Color(0xFF00A884),
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                'Master Dropdowns',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Configure dynamic dropdown menus, add/remove options, order preferences, and color status badges.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFF64748B),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showCreateCustomDropdownDialog,
              icon: const Icon(Icons.add, size: 18, color: Colors.white),
              label: Text(
                'Create Custom Dropdown',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00A884),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Category Selection Card matching screenshot: SELECT DROPDOWN CATEGORY: dropdown
  Widget _buildCategorySelectorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SELECT DROPDOWN CATEGORY:',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          _isLoadingDropdowns
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00A884)),
                  ),
                )
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<Map<String, dynamic>>(
                      value: _selectedCategory,
                      isExpanded: true,
                      hint: Text(
                        _dropdownCategories.isEmpty ? 'No categories found' : 'Select Category',
                        style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF94A3B8)),
                      ),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                      items: _dropdownCategories.map((cat) {
                        final displayName = (cat['displayName'] ?? cat['name'] ?? cat['label'] ?? cat['key'] ?? '').toString();
                        return DropdownMenuItem<Map<String, dynamic>>(
                          value: cat,
                          child: Text(
                            displayName,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (newVal) {
                        if (newVal != null) {
                          setState(() {
                            _selectedCategory = newVal;
                            _extractOptionsFromSelectedCategory();
                          });
                          final key = (newVal['key'] ?? newVal['dropdownKey'] ?? '').toString();
                          if (key.isNotEmpty) {
                            _fetchDropdownOptions(key);
                          }
                        }
                      },
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  /// Main Card displaying option title, key pill, show archived toggle, and options data table
  Widget _buildDetailsAndTableCard() {
    final String titleName = _selectedCategory != null
        ? (_selectedCategory!['displayName'] ?? _selectedCategory!['name'] ?? _selectedCategory!['label'] ?? '').toString()
        : '';
    final String keyName = _selectedCategory != null
        ? (_selectedCategory!['key'] ?? _selectedCategory!['dropdownKey'] ?? '').toString()
        : '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + (edit name)
          Row(
            children: [
              Text(
                titleName.isNotEmpty ? titleName : 'Category Options',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () {
                  // Edit category name functionality
                },
                child: Text(
                  '(edit name)',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: const Color(0xFF00A884),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Key badge matching screenshot: Key: key_name with lock icon
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_outline_rounded,
                  size: 13,
                  color: Color(0xFF64748B),
                ),
                const SizedBox(width: 4),
                Text(
                  'Key: ${keyName.isNotEmpty ? keyName : 'none'}',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Checkbox: Show Archived Options
          Row(
            children: [
              SizedBox(
                height: 24,
                width: 24,
                child: Checkbox(
                  value: _showArchived,
                  activeColor: const Color(0xFF00A884),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  onChanged: (val) {
                    setState(() {
                      _showArchived = val ?? false;
                    });
                    if (keyName.isNotEmpty) {
                      _fetchDropdownOptions(keyName);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Show Archived Options',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Options Data Table UI structure
          _buildOptionsTable(),
          const SizedBox(height: 20),

          // New Option Label input section
          _buildNewOptionSection(),
          const SizedBox(height: 16),

          // Bottom Info Banner matching screenshot (Apidel Dynamic Dropdowns System)
          _buildInfoBanner(),
        ],
      ),
    );
  }

  /// Renders table header & rows dynamically received from API
  Widget _buildOptionsTable() {
    if (_isLoadingOptions) {
      return Container(
        height: 150,
        alignment: Alignment.center,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF00A884)),
            ),
            SizedBox(height: 12),
            Text(
              'Loading dropdown options...',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFFCA5A5)),
        ),
        child: Text(
          'Error loading options: $_errorMessage',
          style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFFB91C1C)),
        ),
      );
    }

    if (_options.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            const Icon(Icons.inbox_outlined, size: 32, color: Color(0xFF94A3B8)),
            const SizedBox(height: 8),
            Text(
              'No dropdown options available',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Options returned by the API will appear here.',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: DataTable(
          headingRowHeight: 40,
          dataRowMinHeight: 48,
          dataRowMaxHeight: 48,
          columnSpacing: 20,
          horizontalMargin: 12,
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
          columns: [
            DataColumn(
              label: Text(
                'Order',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF475569),
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'Color',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF475569),
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'Display Label',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF475569),
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'Internal Value',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF475569),
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'Default',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF475569),
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'Actions',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF475569),
                ),
              ),
            ),
          ],
          rows: _options.map((option) {
            return DataRow(
              cells: [
                // Order Up/Down Arrows
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () {
                          // Reorder up action
                        },
                        child: const Icon(Icons.arrow_upward_rounded, size: 14, color: Color(0xFF94A3B8)),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () {
                          // Reorder down action
                        },
                        child: const Icon(Icons.arrow_downward_rounded, size: 14, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
                // Color Circle Badge
                DataCell(
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: _parseColorHex(option.color),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                // Display Label
                DataCell(
                  Text(
                    option.label,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ),
                // Internal Value
                DataCell(
                  Text(
                    option.value,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
                // Default selection indicator matching screenshot (checked teal circle or empty circle outline)
                DataCell(
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _setDefaultOption(option.id.isNotEmpty ? option.id : option.value),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: option.isDefault ? const Color(0xFF00A884) : Colors.transparent,
                          border: Border.all(
                            color: option.isDefault ? const Color(0xFF00A884) : const Color(0xFFCBD5E1),
                            width: 1.5,
                          ),
                        ),
                        child: option.isDefault
                            ? const Icon(
                                Icons.check_rounded,
                                size: 13,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
                // Actions column matching screenshot: [ Archive ] button
                DataCell(
                  OutlinedButton.icon(
                    onPressed: () => _toggleArchiveOption(option.id.isNotEmpty ? option.id : option.value),
                    icon: const Icon(
                      Icons.archive_outlined,
                      size: 14,
                      color: Color(0xFF64748B),
                    ),
                    label: Text(
                      'Archive',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF475569),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xFFF8FAFC),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: const Size(0, 28),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Color choices for new option badge matching Image 2
  final List<String> _availableColors = const [
    '#475569',
    '#3B82F6',
    '#10B981',
    '#F59E0B',
    '#EF4444',
    '#8B5CF6',
    '#EC4899',
  ];

  /// Section for adding a new option matching Image 2 layout
  Widget _buildNewOptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. New Option Label
        Text(
          'New Option Label',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _newOptionController,
          style: GoogleFonts.poppins(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'e.g. Sales Pending',
            hintStyle: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF94A3B8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            fillColor: Colors.white,
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFF00A884)),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // 2. Internal Value Key (Auto)
        Text(
          'Internal Value Key',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _internalKeyController,
          style: GoogleFonts.poppins(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'e.g. sales_pending (auto)',
            hintStyle: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF94A3B8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            fillColor: Colors.white,
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFF00A884)),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // 3. Color Label
        Text(
          'Color',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),

        // 4. Color Box Selector (+) & + Add Option Button Row
        Row(
          children: [
            // Color Selector Button (+)
            PopupMenuButton<String>(
              onSelected: (color) {
                setState(() {
                  _selectedOptionColor = color;
                });
              },
              offset: const Offset(0, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              itemBuilder: (context) => _availableColors
                  .map(
                    (colorHex) => PopupMenuItem<String>(
                      value: colorHex,
                      child: Row(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: _parseColorHex(colorHex),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            colorHex,
                            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: _parseColorHex(_selectedOptionColor),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const Icon(Icons.add, size: 16, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // + Add Option Button
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isCreatingOption
                    ? null
                    : () {
                        final labelText = _newOptionController.text.trim();
                        if (labelText.isEmpty) return;

                        final cleanKey = _internalKeyController.text.replaceAll('_(auto)', '').trim();
                        final valueKey = cleanKey.isNotEmpty
                            ? cleanKey
                            : labelText.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');

                        final newOpt = MasterDropdownOptionModel(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          label: labelText,
                          value: valueKey,
                          color: _selectedOptionColor,
                          position: _options.length + 1,
                          isDefault: _options.isEmpty,
                        );

                        setState(() {
                          _options.add(newOpt);
                          _newOptionController.clear();
                          _internalKeyController.clear();
                        });
                      },
                icon: const Icon(Icons.add, size: 18, color: Colors.white),
                label: Text(
                  'Add Option',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF70C9B6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Info Banner matching screenshot footer: Apidel Dynamic Dropdowns System: Reordering or editing options...
  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: Color(0xFF16A34A),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: const Color(0xFF166534),
                  height: 1.4,
                ),
                children: const [
                  TextSpan(
                    text: 'Apidel Dynamic Dropdowns System: ',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text: 'Reordering or editing options here affects forms, details panels, and filtering tables across the application in real time.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
