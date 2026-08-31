import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/master_data_provider.dart';
import '../../../../core/utils/msp_field_utils.dart';
import '../../../../core/widgets/searchable_dropdown_form_field.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../companies/presentation/providers/company_provider.dart';
import '../providers/contact_provider.dart';

class CreateContactModal extends StatefulWidget {
  const CreateContactModal({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CreateContactModal(),
    );
  }

  @override
  State<CreateContactModal> createState() => _CreateContactModalState();
}

class _CreateContactModalState extends State<CreateContactModal> {
  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _jobTitleController = TextEditingController();

  String? _selectedCompanyId;
  String? _selectedOwnerId;
  String _selectedLifecycleStage = 'Added';
  String? _selectedLeadStatus;
  String? _selectedMsp;

  bool _isSubmitting = false;

  final List<String> _defaultLifecycleStages = const [
    'Added',
    'Subscriber',
    'Lead',
    'Marketing Qualified Lead',
    'Sales Qualified Lead',
    'Opportunity',
    'Customer',
    'Evangelist',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CompanyProvider>().fetchCompanies();
      context.read<MasterDataProvider>().fetchAllMasterData();
      // The form has an MSP field — make sure GET /api/msp-options ran.
      context.read<MasterDataProvider>().ensureMspOptionsLoaded();
      final auth = context.read<AuthProvider>();
      if (auth.currentUser != null) {
        setState(() {
          _selectedOwnerId = auth.currentUser!.id;
        });
      }
      auth.fetchTeamMembers();
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _jobTitleController.dispose();
    super.dispose();
  }

  Future<bool> _submitForm() async {
    if (!_formKey.currentState!.validate()) return false;

    setState(() {
      _isSubmitting = true;
    });

    final payload = <String, dynamic>{
      'firstName': _firstNameController.text.trim(),
      if (_lastNameController.text.trim().isNotEmpty)
        'lastName': _lastNameController.text.trim(),
      if (_emailController.text.trim().isNotEmpty)
        'email': _emailController.text.trim(),
      if (_phoneController.text.trim().isNotEmpty)
        'phone': _phoneController.text.trim(),
      if (_jobTitleController.text.trim().isNotEmpty)
        'jobTitle': _jobTitleController.text.trim(),
      if (_selectedCompanyId != null && _selectedCompanyId!.isNotEmpty)
        'companyId': _selectedCompanyId,
      if (_selectedOwnerId != null && _selectedOwnerId!.isNotEmpty)
        'ownerId': _selectedOwnerId,
      'lifecycleStage': _selectedLifecycleStage,
      if (_selectedLeadStatus != null && _selectedLeadStatus!.isNotEmpty)
        'leadStatus': _selectedLeadStatus,
      if (_selectedMsp != null && _selectedMsp!.isNotEmpty)
        'msp': _selectedMsp,
    };

    final messenger = ScaffoldMessenger.of(context);
    final contactProvider = context.read<ContactProvider>();

    final success = await contactProvider.createContact(payload);

    if (!mounted) return success;

    setState(() {
      _isSubmitting = false;
    });

    if (success) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Contact created successfully!',
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          backgroundColor: const Color(0xFF00A884),
        ),
      );
    } else {
      final err = contactProvider.error;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            err ?? 'Failed to create contact',
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }

    return success;
  }

  void _clearFields() {
    _firstNameController.clear();
    _lastNameController.clear();
    _emailController.clear();
    _phoneController.clear();
    _jobTitleController.clear();
    setState(() {
      _selectedCompanyId = null;
      _selectedOwnerId = null;
      _selectedLifecycleStage = 'Added';
      _selectedLeadStatus = null;
      _selectedMsp = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final companyProvider = context.watch<CompanyProvider>();
    final authProvider = context.watch<AuthProvider>();

    final companies = companyProvider.companies;
    final teamMembers = authProvider.teamMembers;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // 1. Modal Teal Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFF00A884),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Create Contact',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _firstNameController.clear();
                          _lastNameController.clear();
                          _emailController.clear();
                          _phoneController.clear();
                          _jobTitleController.clear();
                          _selectedCompanyId = null;
                          _selectedMsp = null;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Contact form data refreshed'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
                      tooltip: 'Refresh Form Data',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Form Body in EXACT SEQUENCE requested
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // 1. First name(mandatory)
                  _buildLabel('First name', isRequired: true),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _firstNameController,
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF1E293B),
                    ),
                    decoration: _inputDecoration('Enter first name'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'First name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // 2. Last name
                  _buildLabel('Last name'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _lastNameController,
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF1E293B),
                    ),
                    decoration: _inputDecoration('Enter last name'),
                  ),
                  const SizedBox(height: 16),

                  // 3. Email
                  _buildLabel('Email'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF1E293B),
                    ),
                    decoration: _inputDecoration('Enter email address'),
                  ),
                  const SizedBox(height: 16),

                  // 4. phone number
                  _buildLabel('Phone number'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF1E293B),
                    ),
                    decoration: _inputDecoration('Enter phone number'),
                  ),
                  const SizedBox(height: 16),

                  // 5. job title
                  _buildLabel('Job title'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _jobTitleController,
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF1E293B),
                    ),
                    decoration: _inputDecoration('Enter job title'),
                  ),
                  const SizedBox(height: 16),

                  // 6. company (fetch companies)
                  _buildLabel('Company'),
                  const SizedBox(height: 6),
                  SearchableDropdownFormField<String>(
                    initialValue: _selectedCompanyId ?? '',
                    hintText: 'Select a company',
                    items: [
                      DropdownSearchItem<String>(
                        value: '',
                        label: 'No company',
                      ),
                      ...companies.map(
                        (c) => DropdownSearchItem<String>(
                          value: c.id,
                          label: c.name,
                          subtext: c.domain ?? c.websiteUrl,
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedCompanyId = val;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // 7. contact owner(fetch contacts/owners)
                  _buildLabel('Contact owner'),
                  const SizedBox(height: 6),
                  Builder(
                    builder: (context) {
                      final ownerItems = <DropdownSearchItem<String>>[
                        DropdownSearchItem(
                          value: '',
                          label: 'No owner',
                        ),
                        if (authProvider.currentUser != null)
                          DropdownSearchItem(
                            value: authProvider.currentUser!.id,
                            label: authProvider.currentUser!.fullName.isNotEmpty
                                ? authProvider.currentUser!.fullName
                                : 'Admin User',
                            subtext: authProvider.currentUser!.email,
                          ),
                        ...teamMembers.map(
                          (m) => DropdownSearchItem(
                            value: m.id,
                            label: m.fullName,
                            subtext: m.email,
                          ),
                        ),
                      ];

                      return SearchableDropdownFormField<String>(
                        initialValue: _selectedOwnerId ??
                            (authProvider.currentUser?.id ?? ''),
                        hintText: 'Select contact owner',
                        items: ownerItems,
                        onChanged: (val) {
                          setState(() {
                            _selectedOwnerId = val;
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // 8. Lifecycle Stage(fetch all stage)
                  _buildLabel('Lifecycle stage'),
                  const SizedBox(height: 6),
                  Consumer<MasterDataProvider>(
                    builder: (context, masterProvider, child) {
                      final dynamicStages = masterProvider.contactLifecycleStages
                          .map((e) => e.name)
                          .toList();
                      final stageList = dynamicStages.isNotEmpty
                          ? dynamicStages
                          : _defaultLifecycleStages;

                      return SearchableDropdownFormField<String>(
                        initialValue: _selectedLifecycleStage,
                        hintText: 'Select lifecycle stage',
                        items: stageList
                            .map(
                              (stage) => DropdownSearchItem<String>(
                                value: stage,
                                label: stage,
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null && val.isNotEmpty) {
                            setState(() {
                              _selectedLifecycleStage = val;
                            });
                          }
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // 9. Lead Status (4th image matching design with colored dots)
                  _buildLabel('Lead status'),
                  const SizedBox(height: 6),
                  Consumer<MasterDataProvider>(
                    builder: (context, masterProvider, _) {
                      final options = masterProvider.contactLeadStatusOptions;

                      Color getColorForStatus(String label) {
                        final lower = label.toLowerCase();
                        if (lower.contains('new')) return const Color(0xFF0EA5E9);
                        if (lower.contains('open') && !lower.contains('opp')) return const Color(0xFF10B981);
                        if (lower.contains('progress')) return const Color(0xFFF59E0B);
                        if (lower.contains('opportunity')) return const Color(0xFFF59E0B);
                        if (lower.contains('unqualified')) return const Color(0xFF64748B);
                        return const Color(0xFF00A884);
                      }

                      final statusItems = <DropdownSearchItem<String>>[
                        DropdownSearchItem(
                          value: '',
                          label: 'None',
                        ),
                        if (options.isNotEmpty)
                          ...options.map(
                            (opt) => DropdownSearchItem(
                              value: opt.value,
                              label: opt.label,
                              dotColor: getColorForStatus(opt.label),
                            ),
                          )
                        else ...[
                          DropdownSearchItem(value: 'New', label: 'New', dotColor: const Color(0xFF0EA5E9)),
                          DropdownSearchItem(value: 'Open', label: 'Open', dotColor: const Color(0xFF10B981)),
                          DropdownSearchItem(value: 'In Progress', label: 'In Progress', dotColor: const Color(0xFFF59E0B)),
                          DropdownSearchItem(value: 'Open Opportunity', label: 'Open Opportunity', dotColor: const Color(0xFFF59E0B)),
                          DropdownSearchItem(value: 'Unqualified', label: 'Unqualified', dotColor: const Color(0xFF64748B)),
                        ]
                      ];

                      return SearchableDropdownFormField<String>(
                        initialValue: _selectedLeadStatus ?? '',
                        hintText: 'Select lead status',
                        items: statusItems,
                        onChanged: (val) {
                          setState(() {
                            _selectedLeadStatus = val;
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // 10. MSP(fetch MSP)
                  _buildLabel('MSP'),
                  const SizedBox(height: 6),
                  Consumer<MasterDataProvider>(
                    builder: (context, masterProvider, child) {
                      final apiMsps =
                          MspFieldUtils.optionsWith(masterProvider, _selectedMsp);
                      final placeholder = MspFieldUtils.placeholder(masterProvider);

                      final mspItems = [
                        DropdownSearchItem<String>(
                          value: '',
                          label: placeholder,
                        ),
                        ...apiMsps.map(
                          (msp) => DropdownSearchItem<String>(
                            value: msp,
                            label: msp,
                          ),
                        ),
                        DropdownSearchItem<String>(
                          value: MspFieldUtils.addCustomMspValue,
                          label: MspFieldUtils.addCustomMspLabel,
                        ),
                      ];

                      return SearchableDropdownFormField<String>(
                        initialValue: _selectedMsp ?? '',
                        hintText: placeholder,
                        items: mspItems,
                        onChanged: (val) async {
                          if (val == MspFieldUtils.addCustomMspValue) {
                            final newMsp = await MspFieldUtils.showAddCustomMspDialog(context);
                            if (newMsp != null && mounted) {
                              setState(() {
                                _selectedMsp = newMsp;
                              });
                            }
                          } else {
                            setState(() {
                              _selectedMsp = val;
                            });
                          }
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // 3. Action Buttons Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: _isSubmitting
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF00A884)),
                  )
                : Row(
                    children: [
                      // Create Button
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final navigator = Navigator.of(context);
                            final ok = await _submitForm();
                            if (ok) {
                              navigator.pop(true);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00A884),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: Text(
                            'Create',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Create and add another Button
                      Expanded(
                        flex: 1,
                        child: OutlinedButton(
                          onPressed: () async {
                            final ok = await _submitForm();
                            if (ok) {
                              _clearFields();
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF00A884),
                            side: const BorderSide(color: Color(0xFF00A884)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: Text(
                            'Create & Add',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Cancel Button
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text, {bool isRequired = false}) {
    return RichText(
      text: TextSpan(
        text: text,
        style: GoogleFonts.poppins(
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF1E293B),
        ),
        children: [
          if (isRequired)
            TextSpan(
              text: ' *',
              style: GoogleFonts.poppins(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(
        color: const Color(0xFF94A3B8),
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF00A884), width: 1.5),
      ),
    );
  }
}
