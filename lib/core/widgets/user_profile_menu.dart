import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../features/authentication/presentation/providers/auth_provider.dart';
import '../../features/authentication/presentation/screens/login_screen.dart';

/// Reusable User Profile menu displaying avatar, name, role badge,
/// and popup menu options ("Edit Profile" and "Sign Out").
class UserProfileMenu extends StatelessWidget {
  final bool showNameAndRole;

  const UserProfileMenu({
    super.key,
    this.showNameAndRole = true,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final user = authProvider.currentUser;
        final name = (user != null && user.fullName.isNotEmpty)
            ? user.fullName
            : (authProvider.loginResponse?.user?['first_name'] != null
                ? '${authProvider.loginResponse?.user?['first_name']} ${authProvider.loginResponse?.user?['last_name']}'
                : 'Saurav Singh');
        final email = user?.email ??
            authProvider.loginResponse?.user?['email'] as String? ??
            'saurav.s@apideltech.com';
        final role = (user?.role ??
                authProvider.loginResponse?.user?['role'] as String? ??
                'ADMIN')
            .toUpperCase();
        final initial = name.isNotEmpty ? name[0].toUpperCase() : 'S';

        return Theme(
          data: Theme.of(context).copyWith(
            cardColor: Colors.white,
            popupMenuTheme: PopupMenuThemeData(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
              ),
              elevation: 10,
            ),
          ),
          child: PopupMenuButton<int>(
            offset: const Offset(0, 48),
            constraints: const BoxConstraints(minWidth: 240, maxWidth: 260),
            tooltip: 'User Profile',
            splashRadius: 20,
            itemBuilder: (context) => [
              // Header Item: User Full Name & Email
              PopupMenuItem<int>(
                enabled: false,
                padding: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const PopupMenuDivider(height: 1),
              // Field 1: Edit Profile
              PopupMenuItem<int>(
                value: 1,
                padding: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: Color(0xFF475569),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Edit Profile',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const PopupMenuDivider(height: 1),
              // Field 2: Sign Out
              PopupMenuItem<int>(
                value: 2,
                padding: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.logout_rounded,
                        size: 18,
                        color: Color(0xFFEF4444),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Sign Out',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFEF4444),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            onSelected: (value) async {
              if (value == 1) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Edit Profile clicked for $name'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: const Color(0xFF00A884),
                  ),
                );
              } else if (value == 2) {
                await authProvider.logout();
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFFEA580C),
                    child: Text(
                      initial,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (showNameAndRole) ...[
                    const SizedBox(width: 10),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.poppins(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          role,
                          style: GoogleFonts.poppins(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF10B981),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF94A3B8),
                      size: 18,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
