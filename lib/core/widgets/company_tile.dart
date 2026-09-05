import 'package:flutter/material.dart';
import '../../features/companies/data/models/company_model.dart';

class CompanyTile extends StatelessWidget {
  final CompanyModel company;
  final VoidCallback? onTap;
  final VoidCallback? onDeleteTap;
  final bool isSelected;
  final bool showCheckbox;
  final ValueChanged<bool?>? onSelectionChanged;

  const CompanyTile({
    super.key,
    required this.company,
    this.onTap,
    this.onDeleteTap,
    this.isSelected = false,
    this.showCheckbox = true,
    this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF1F5F9) : Colors.white,
          border: const Border(
            bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (showCheckbox) ...[
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: isSelected,
                  onChanged: onSelectionChanged,
                  activeColor: const Color(0xFF00A884),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  side: const BorderSide(color: Color(0xFF94A3B8), width: 1.5),
                ),
              ),
              const SizedBox(width: 12),
            ],

            // 2. Company Details Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Company Name + Badge Row
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          company.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: company.statusBadge == 'Added'
                              ? const Color(0xFFF3F4F6)
                              : const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          company.statusBadge,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: company.statusBadge == 'Added'
                                ? const Color(0xFF4B5563)
                                : const Color(0xFF2563EB),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Industry + Website Row
                  Row(
                    children: [
                      if (company.industry.isNotEmpty) ...[
                        Flexible(
                          child: Text(
                            company.industry,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (company.website.isNotEmpty) ...[
                        const Icon(
                          Icons.language_rounded,
                          size: 13,
                          color: Color(0xFF9CA3AF),
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            company.website,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 3),

                  // Contacts count + Location Pin Row
                  Row(
                    children: [
                      const Icon(
                        Icons.people_outline_rounded,
                        size: 13,
                        color: Color(0xFF9CA3AF),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${company.contactsCount} ${company.contactsCount == 1 ? 'contact' : 'contacts'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      if (company.location != null &&
                          company.location!.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        const Icon(
                          Icons.location_on_outlined,
                          size: 13,
                          color: Color(0xFF9CA3AF),
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            company.location!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            if (onDeleteTap != null) ...[
              IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFF94A3B8),
                  size: 20,
                ),
                onPressed: onDeleteTap,
                tooltip: 'Delete Company',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
            ],

            // 3. Trailing Chevron Icon
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFD1D5DB),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
