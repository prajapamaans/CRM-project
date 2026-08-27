import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/master_data_provider.dart';
import '../../../../core/utils/msp_field_utils.dart';
import '../../../../core/widgets/searchable_dropdown_form_field.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../contacts/presentation/providers/contact_provider.dart';
import '../providers/company_provider.dart';

class CreateCompanyModal extends StatefulWidget {
  const CreateCompanyModal({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CreateCompanyModal(),
    );
  }

  @override
  State<CreateCompanyModal> createState() => _CreateCompanyModalState();
}

class _CreateCompanyModalState extends State<CreateCompanyModal> {
  final _formKey = GlobalKey<FormState>();

  final _domainController = TextEditingController(text: 'test.com');
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _numEmployeesController = TextEditingController();
  final _annualRevenueController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _linkedinController = TextEditingController();

  String? _selectedMsp;
  String? _selectedContactId;
  String? _selectedOwnerId;
  String? _selectedIndustry;
  String? _selectedType;
  String? _selectedTimeZone;

  bool _isSubmitting = false;

  final List<String> _defaultIndustryOptions = const [
    'Technology',
    'Finance',
    'Healthcare',
    'Education',
    'Retail',
    'Manufacturing',
    'Other',
  ];

  final List<String> _defaultTypeOptions = const [
    'Prospect',
    'Partner',
    'Reseller',
    'Vendor',
    'Other',
  ];

  final List<String> _timeZoneOptions = const [
    'UTC',
    'EST',
    'PST',
    'IST',
    'CST',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ContactProvider>().fetchContacts();
      context.read<MasterDataProvider>().fetchCompanyMasterData();
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
    _domainController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalCodeController.dispose();
    _numEmployeesController.dispose();
    _annualRevenueController.dispose();
    _descriptionController.dispose();
    _linkedinController.dispose();
    super.dispose();
  }

  Future<bool> _submitForm() async {
    if (!_formKey.currentState!.validate()) return false;

    setState(() {
      _isSubmitting = true;
    });

    final payload = <String, dynamic>{
      'name': _nameController.text.trim(),
      if (_domainController.text.trim().isNotEmpty)
        'domain': _domainController.text.trim(),
      if (_selectedMsp != null && _selectedMsp!.isNotEmpty)
        'msp': _selectedMsp,
      if (_phoneController.text.trim().isNotEmpty)
        'phone': _phoneController.text.trim(),
      if (_selectedContactId != null && _selectedContactId!.isNotEmpty)
        'contactId': _selectedContactId,
      if (_selectedOwnerId != null && _selectedOwnerId!.isNotEmpty)
        'ownerId': _selectedOwnerId,
      if (_selectedIndustry != null && _selectedIndustry!.isNotEmpty)
        'industry': _selectedIndustry,
      if (_selectedType != null && _selectedType!.isNotEmpty)
        'type': _selectedType,
      if (_cityController.text.trim().isNotEmpty)
        'city': _cityController.text.trim(),
      if (_stateController.text.trim().isNotEmpty)
        'state': _stateController.text.trim(),
      if (_postalCodeController.text.trim().isNotEmpty)
        'postalCode': _postalCodeController.text.trim(),
      if (_numEmployeesController.text.trim().isNotEmpty)
        'numberOfEmployees': _numEmployeesController.text.trim(),
      if (_annualRevenueController.text.trim().isNotEmpty)
        'annualRevenue': _annualRevenueController.text.trim(),
      if (_selectedTimeZone != null && _selectedTimeZone!.isNotEmpty)
        'timeZone': _selectedTimeZone,
      if (_descriptionController.text.trim().isNotEmpty)
        'description': _descriptionController.text.trim(),
      if (_linkedinController.text.trim().isNotEmpty)
        'linkedinPage': _linkedinController.text.trim(),
    };

    final messenger = ScaffoldMessenger.of(context);
    final companyProvider = context.read<CompanyProvider>();

    final success = await companyProvider.createCompany(payload);

    if (!mounted) return success;

    setState(() {
      _isSubmitting = false;
    });

    if (success) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Company created successfully!',
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          backgroundColor: const Color(0xFF00A884),
        ),
      );
    } else {
      final err = companyProvider.error;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            err ?? 'Failed to create company',
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }

    return success;
  }

  void _clearFields() {
    _domainController.clear();
    _nameController.clear();
    _phoneController.clear();
    _cityController.clear();
    _stateController.clear();
    _postalCodeController.clear();
    _numEmployeesController.clear();
    _annualRevenueController.clear();
    _descriptionController.clear();
    _linkedinController.clear();
    setState(() {
      _selectedMsp = null;
      _selectedContactId = null;
      _selectedOwnerId = null;
      _selectedIndustry = null;
      _selectedType = null;
      _selectedTimeZone = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final contactProvider = context.watch<ContactProvider>();
    final authProvider = context.watch<AuthProvider>();
    final contacts = contactProvider.contacts;
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
                  'Create Company',
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
                        _clearFields();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Company form data refreshed'),
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

          // 2. Form Body in EXACT REQUESTED SEQUENCE
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 1. company domain name * (with Enrich)
                  _buildLabel('Company domain name', isRequired: true),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _domainController,
                          style: GoogleFonts.poppins(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF1E293B),
                          ),
                          decoration: _inputDecoration('Enter domain name'),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Company domain name is required';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Enriching company domain...',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF00A884),
                          side: const BorderSide(color: Color(0xFF64D2B7)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Enrich',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 2. company name *
                  _buildLabel('Company name', isRequired: true),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nameController,
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF1E293B),
                    ),
                    decoration: _inputDecoration('Enter company name'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Company name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // 3. MSP(fetch MSP)
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
                      ];

                      return SearchableDropdownFormField<String>(
                        initialValue: _selectedMsp ?? '',
                        hintText: placeholder,
                        items: mspItems,
                        onChanged: (val) {
                          setState(() {
                            _selectedMsp = val;
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),

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
                  const SizedBox(height: 12),

                  // 5. contact(fetch contacts)
                  _buildLabel('Contact'),
                  const SizedBox(height: 6),
                  SearchableDropdownFormField<String>(
                    initialValue: _selectedContactId ?? '',
                    hintText: 'Select a contact',
                    items: [
                      DropdownSearchItem<String>(
                        value: '',
                        label: 'Select a contact',
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
                        _selectedContactId = val;
                      });
                    },
                  ),
                  const SizedBox(height: 12),

                  // 6. company owner
                  _buildLabel('Company owner'),
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
                        hintText: 'Select an owner',
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

                  // 7. industry
                  _buildLabel('Industry'),
                  const SizedBox(height: 6),
                  Consumer<MasterDataProvider>(
                    builder: (context, masterProvider, child) {
                      final dynamicOptions = masterProvider.companyIndustryOptions
                          .map((e) => e.label)
                          .toList();
                      final list = dynamicOptions.isNotEmpty
                          ? dynamicOptions
                          : _defaultIndustryOptions;

                      final industryItems = [
                        DropdownSearchItem<String>(
                          value: '',
                          label: 'Select an industry',
                        ),
                        ...list.map(
                          (item) => DropdownSearchItem<String>(
                            value: item,
                            label: item,
                          ),
                        ),
                      ];

                      return SearchableDropdownFormField<String>(
                        initialValue: _selectedIndustry ?? '',
                        hintText: 'Select an industry',
                        items: industryItems,
                        onChanged: (val) {
                          setState(() {
                            _selectedIndustry = val;
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // 8. type
                  _buildLabel('Type'),
                  const SizedBox(height: 6),
                  Consumer<MasterDataProvider>(
                    builder: (context, masterProvider, child) {
                      final dynamicOptions = masterProvider.companyTypeOptions
                          .map((e) => e.label)
                          .toList();
                      final list = dynamicOptions.isNotEmpty
                          ? dynamicOptions
                          : _defaultTypeOptions;

                      final typeItems = [
                        DropdownSearchItem<String>(
                          value: '',
                          label: 'Select a type',
                        ),
                        ...list.map(
                          (item) => DropdownSearchItem<String>(
                            value: item,
                            label: item,
                          ),
                        ),
                      ];

                      return SearchableDropdownFormField<String>(
                        initialValue: _selectedType ?? '',
                        hintText: 'Select a type',
                        items: typeItems,
                        onChanged: (val) {
                          setState(() {
                            _selectedType = val;
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // 9. city
                  _buildLabel('City'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _cityController,
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF1E293B),
                    ),
                    decoration: _inputDecoration('Enter city'),
                  ),
                  const SizedBox(height: 12),

                  // 10. state/region
                  _buildLabel('State/Region'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _stateController,
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF1E293B),
                    ),
                    decoration: _inputDecoration('Enter state or region'),
                  ),
                  const SizedBox(height: 12),

                  // 11. postal code
                  _buildLabel('Postal code'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _postalCodeController,
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF1E293B),
                    ),
                    decoration: _inputDecoration('Enter postal code'),
                  ),
                  const SizedBox(height: 12),

                  // 12. number of employees
                  _buildLabel('Number of employees'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _numEmployeesController,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF1E293B),
                    ),
                    decoration: _inputDecoration('Enter number of employees'),
                  ),
                  const SizedBox(height: 12),

                  // 13. annual revenue
                  _buildLabel('Annual revenue'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _annualRevenueController,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF1E293B),
                    ),
                    decoration: _inputDecoration('Enter annual revenue'),
                  ),
                  const SizedBox(height: 12),

                  // 14. Time zone
                  _buildLabel('Time zone'),
                  const SizedBox(height: 6),
                  SearchableDropdownFormField<String>(
                    initialValue: _selectedTimeZone ?? '',
                    hintText: 'Select a time zone',
                    items: [
                      DropdownSearchItem<String>(
                        value: '',
                        label: 'Select a time zone',
                      ),
                      ..._timeZoneOptions.map(
                        (tz) => DropdownSearchItem<String>(
                          value: tz,
                          label: tz,
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedTimeZone = val;
                      });
                    },
                  ),
                  const SizedBox(height: 12),

                  // 15. description
                  _buildLabel('Description'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 4,
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF1E293B),
                    ),
                    decoration: _inputDecoration('Enter description'),
                  ),
                  const SizedBox(height: 12),

                  // 16. linkedin company page
                  _buildLabel('LinkedIn company page'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _linkedinController,
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF1E293B),
                    ),
                    decoration:
                        _inputDecoration('Enter LinkedIn company page URL'),
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
