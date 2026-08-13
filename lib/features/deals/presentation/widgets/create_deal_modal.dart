import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/master_data_provider.dart';
import '../../../../core/widgets/searchable_dropdown_form_field.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../companies/presentation/providers/company_provider.dart';
import '../../../contacts/presentation/providers/contact_provider.dart';
import '../providers/deal_provider.dart';

class CreateDealModal extends StatefulWidget {
  const CreateDealModal({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CreateDealModal(),
    );
  }

  @override
  State<CreateDealModal> createState() => _CreateDealModalState();
}

class _CreateDealModalState extends State<CreateDealModal> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  late final TextEditingController _closeDateController;

  static String _formatDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    return '$d-$m-$y';
  }

  String _selectedPipeline = 'default';
  String _selectedDealStage = 'Prospect';
  String? _selectedOwnerId;
  String? _selectedDealType;
  String? _selectedPriority;
  String? _selectedAssociatedContactId;
  String? _selectedAssociatedCompanyId;

  bool _isSubmitting = false;

  final List<String> _pipelines = const [
    'default',
    'Sales Pipeline',
    'Enterprise Pipeline',
  ];

  final List<String> _dealStages = const [
    'Prospect',
    'Capability Statement',
    'RFI',
    'RFP/RFQ',
    'MSA',
    'Closed Won',
    'Closed Lost',
  ];

  final List<String> _dealTypes = const [
    'New Business',
    'Existing Business',
  ];

  final List<String> _priorities = const [
    'Low',
    'Medium',
    'High',
  ];

  @override
  void initState() {
    super.initState();
    _closeDateController =
        TextEditingController(text: _formatDate(DateTime.now()));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ContactProvider>().fetchContacts();
      context.read<CompanyProvider>().fetchCompanies();
      context.read<MasterDataProvider>().fetchAllMasterData();
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
    _nameController.dispose();
    _amountController.dispose();
    _closeDateController.dispose();
    super.dispose();
  }

  Future<void> _selectCloseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF00A884),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _closeDateController.text = _formatDate(picked);
      });
    }
  }

  Future<bool> _submitForm() async {
    if (!_formKey.currentState!.validate()) return false;

    setState(() {
      _isSubmitting = true;
    });

    final amountNum = double.tryParse(_amountController.text.trim());

    final payload = <String, dynamic>{
      'title': _nameController.text.trim(),
      'name': _nameController.text.trim(),
      'pipeline': _selectedPipeline,
      'stage': _selectedDealStage,
      if (amountNum != null) 'amount': amountNum,
      if (_closeDateController.text.trim().isNotEmpty)
        'closeDate': _closeDateController.text.trim(),
      if (_selectedOwnerId != null && _selectedOwnerId!.isNotEmpty)
        'ownerId': _selectedOwnerId,
      if (_selectedDealType != null && _selectedDealType!.isNotEmpty)
        'dealType': _selectedDealType,
      if (_selectedPriority != null && _selectedPriority!.isNotEmpty)
        'priority': _selectedPriority,
      if (_selectedAssociatedContactId != null &&
          _selectedAssociatedContactId!.isNotEmpty)
        'contactId': _selectedAssociatedContactId,
      if (_selectedAssociatedCompanyId != null &&
          _selectedAssociatedCompanyId!.isNotEmpty)
        'companyId': _selectedAssociatedCompanyId,
    };

    final messenger = ScaffoldMessenger.of(context);
    final dealProvider = context.read<DealProvider>();

    final success = await dealProvider.createDeal(payload);

    if (!mounted) return success;

    setState(() {
      _isSubmitting = false;
    });

    if (success) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Deal created successfully!',
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          backgroundColor: const Color(0xFF00A884),
        ),
      );
    } else {
      final err = dealProvider.error;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            err ?? 'Failed to create deal',
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }

    return success;
  }

  void _clearFields() {
    _nameController.clear();
    _amountController.clear();
    setState(() {
      _selectedPipeline = 'default';
      _selectedDealStage = 'Prospect';
      _selectedOwnerId = null;
      _selectedDealType = null;
      _selectedPriority = null;
      _selectedAssociatedContactId = null;
      _selectedAssociatedCompanyId = null;
      _closeDateController.text = _formatDate(DateTime.now());
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final contactProvider = context.watch<ContactProvider>();
    final companyProvider = context.watch<CompanyProvider>();

    final teamMembers = authProvider.teamMembers;
    final contacts = contactProvider.contacts;
    final companies = companyProvider.companies;

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
                  'Create Deal',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 24),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // 2. Form Body in EXACT REQUESTED SEQUENCE
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 1. Deal name (mandatory)
                  _buildLabel('Deal name', isRequired: true),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nameController,
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF1E293B),
                    ),
                    decoration: _inputDecoration('Enter deal name'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Deal name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // 2. Pipeline (Mandatory)
                  _buildLabel('Pipeline', isRequired: true),
                  const SizedBox(height: 6),
                  SearchableDropdownFormField<String>(
                    initialValue: _selectedPipeline,
                    hintText: 'Select pipeline',
                    items: _pipelines
                        .map(
                          (p) => DropdownSearchItem<String>(
                            value: p,
                            label: p,
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null && val.isNotEmpty) {
                        setState(() {
                          _selectedPipeline = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // 3. Deal Stage (Mandatory - matching 1st screenshot)
                  _buildLabel('Deal stage', isRequired: true),
                  const SizedBox(height: 6),
                  SearchableDropdownFormField<String>(
                    initialValue: _selectedDealStage,
                    hintText: 'Select deal stage',
                    items: _dealStages
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
                          _selectedDealStage = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // 4. Amount
                  _buildLabel('Amount'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF1E293B),
                    ),
                    decoration: _inputDecoration('Enter amount'),
                  ),
                  const SizedBox(height: 12),

                  // 5. close date
                  _buildLabel('Close date'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _closeDateController,
                    readOnly: true,
                    onTap: _selectCloseDate,
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF1E293B),
                    ),
                    decoration: _inputDecoration('Select close date').copyWith(
                      suffixIcon: const Icon(
                        Icons.calendar_today_outlined,
                        color: Color(0xFF334155),
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 6. deal owner (fetch contacts/team members)
                  _buildLabel('Deal owner'),
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
                        ...contacts.map(
                          (c) => DropdownSearchItem(
                            value: c.id,
                            label: c.name,
                            subtext: c.email,
                          ),
                        ),
                      ];

                      return SearchableDropdownFormField<String>(
                        initialValue: _selectedOwnerId ??
                            (authProvider.currentUser?.id ?? ''),
                        hintText: 'Select deal owner',
                        items: ownerItems,
                        onChanged: (val) {
                          setState(() {
                            _selectedOwnerId = val;
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // 7. Deal type (matching 2nd screenshot with "No type", "New Business", "Existing Business")
                  _buildLabel('Deal type'),
                  const SizedBox(height: 6),
                  SearchableDropdownFormField<String>(
                    initialValue: _selectedDealType ?? '',
                    hintText: 'Select a type',
                    items: [
                      DropdownSearchItem<String>(
                        value: '',
                        label: 'No type',
                      ),
                      ..._dealTypes.map(
                        (t) => DropdownSearchItem<String>(
                          value: t,
                          label: t,
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedDealType = val;
                      });
                    },
                  ),
                  const SizedBox(height: 12),

                  // 8. priority (matching 3rd screenshot with "No priority", "Low", "Medium", "High")
                  _buildLabel('Priority'),
                  const SizedBox(height: 6),
                  SearchableDropdownFormField<String>(
                    initialValue: _selectedPriority ?? '',
                    hintText: 'Select priority',
                    items: [
                      DropdownSearchItem<String>(
                        value: '',
                        label: 'No priority',
                      ),
                      ..._priorities.map(
                        (p) => DropdownSearchItem<String>(
                          value: p,
                          label: p,
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedPriority = val;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Section Header: Associate deal with
                  Text(
                    'Associate deal with',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Associate deal with -> contacts(fetch contacts)
                  _buildLabel('Contact'),
                  const SizedBox(height: 6),
                  SearchableDropdownFormField<String>(
                    initialValue: _selectedAssociatedContactId ?? '',
                    hintText: 'Select a contact',
                    items: [
                      DropdownSearchItem<String>(
                        value: '',
                        label: 'No contact',
                      ),
                      ...contacts.map(
                        (c) => DropdownSearchItem<String>(
                          value: c.id,
                          label: c.name,
                          subtext: c.email,
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedAssociatedContactId = val;
                      });
                    },
                  ),
                  const SizedBox(height: 12),

                  // Associate deal with -> companies(fetch companies)
                  _buildLabel('Company'),
                  const SizedBox(height: 6),
                  SearchableDropdownFormField<String>(
                    initialValue: _selectedAssociatedCompanyId ?? '',
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
                        _selectedAssociatedCompanyId = val;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
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
                            'Create and add another',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 11.5,
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
