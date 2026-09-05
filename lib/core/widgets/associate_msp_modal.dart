import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/master_data_provider.dart';

class AssociateMspModal extends StatefulWidget {
  final String? initialMsp;
  final List<String>? initialSelectedMsps;

  const AssociateMspModal({
    super.key,
    this.initialMsp,
    this.initialSelectedMsps,
  });

  static Future<List<String>?> show(
    BuildContext context, {
    String? initialMsp,
    List<String>? initialSelectedMsps,
  }) {
    return showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AssociateMspModal(
        initialMsp: initialMsp,
        initialSelectedMsps: initialSelectedMsps,
      ),
    );
  }

  @override
  State<AssociateMspModal> createState() => _AssociateMspModalState();
}

class _AssociateMspModalState extends State<AssociateMspModal> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customMspController = TextEditingController();

  /// Options that are not part of the API list: values already stored on the
  /// record plus any custom option added here. The API list itself is never
  /// duplicated locally.
  final List<String> _extraOptions = [];

  final Set<String> _selectedMsps = {};
  bool _isAddingCustom = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MasterDataProvider>().ensureMspOptionsLoaded();
    });
    if (widget.initialMsp != null && widget.initialMsp!.isNotEmpty) {
      _extraOptions.add(widget.initialMsp!);
      _selectedMsps.add(widget.initialMsp!);
    }
    if (widget.initialSelectedMsps != null) {
      for (final item in widget.initialSelectedMsps!) {
        if (item.isNotEmpty) {
          if (!_extraOptions.contains(item)) {
            _extraOptions.add(item);
          }
          _selectedMsps.add(item);
        }
      }
    }
  }

  /// API options first, then values only this record knows about.
  List<String> _allOptions(List<String> apiMsps) {
    final options = <String>[...apiMsps];
    for (final extra in _extraOptions) {
      if (!options.contains(extra)) options.add(extra);
    }
    return options;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customMspController.dispose();
    super.dispose();
  }

  void _addCustomOption() {
    final text = _customMspController.text.trim();
    if (text.isNotEmpty) {
      context.read<MasterDataProvider>().addCustomMspOption(text);
      setState(() {
        final apiMsps = context.read<MasterDataProvider>().mspNames;
        if (!apiMsps.contains(text) && !_extraOptions.contains(text)) {
          _extraOptions.add(text);
        }
        _selectedMsps.add(text);
        _customMspController.clear();
        _isAddingCustom = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final masterProvider = context.watch<MasterDataProvider>();
    final allOptions = _allOptions(masterProvider.mspNames);

    final filteredOptions = allOptions.where((opt) {
      if (_searchQuery.isEmpty) return true;
      return opt.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Associate MSPs',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded,
                      color: Color(0xFF64748B), size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Field
                Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF00A884), width: 1.5),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.trim();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search Managed Service Providers...',
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
                const SizedBox(height: 14),

                // Checkbox Options List Container
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      if (masterProvider.isMspLoading && allOptions.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF00A884),
                            ),
                          ),
                        )
                      else if (masterProvider.mspError != null && allOptions.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Column(
                            children: [
                              Text(
                                masterProvider.mspError!,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: const Color(0xFFDC2626),
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextButton(
                                onPressed: () => masterProvider.fetchMspOptions(force: true),
                                child: Text(
                                  'Retry',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF00A884),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (filteredOptions.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'No MSP options found',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        )
                      else
                        ...filteredOptions.map((option) {
                          final isChecked = _selectedMsps.contains(option);
                          return InkWell(
                            onTap: () {
                              setState(() {
                                if (isChecked) {
                                  _selectedMsps.remove(option);
                                } else {
                                  _selectedMsps.add(option);
                                }
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: Checkbox(
                                      value: isChecked,
                                      activeColor: const Color(0xFF00A884),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      onChanged: (val) {
                                        setState(() {
                                          if (val == true) {
                                            _selectedMsps.add(option);
                                          } else {
                                            _selectedMsps.remove(option);
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    option,
                                    style: GoogleFonts.poppins(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF1E293B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Add Custom MSP Option Button / Field
                if (!_isAddingCustom)
                  InkWell(
                    onTap: () {
                      setState(() {
                        _isAddingCustom = true;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.add_rounded,
                            color: Color(0xFF00A884),
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Add custom MSP option',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF00A884),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: TextField(
                            controller: _customMspController,
                            autofocus: true,
                            decoration: InputDecoration(
                              hintText: 'Enter MSP option name...',
                              hintStyle: GoogleFonts.poppins(
                                  fontSize: 12.5, color: const Color(0xFF94A3B8)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: const BorderSide(color: Color(0xFF00A884)),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _addCustomOption,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00A884),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: Text(
                          'Add',
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _isAddingCustom = false;
                            _customMspController.clear();
                          });
                        },
                        icon: const Icon(Icons.close_rounded,
                            size: 18, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Bottom Action Buttons: Save & Cancel
          Center(
            child: Column(
              children: [
                SizedBox(
                  width: 120,
                  height: 38,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(_selectedMsps.toList());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00A884),
                      elevation: 0,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Save',
                      style: GoogleFonts.poppins(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 120,
                  height: 36,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xFFF1F5F9),
                      side: BorderSide.none,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF475569),
                      ),
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
}
