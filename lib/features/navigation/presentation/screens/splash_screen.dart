// ============================================================================
// FILE PURPOSE & ARCHITECTURE OVERVIEW:
// ============================================================================
// What does this file do?
// -----------------------
// `splash_screen.dart` presents an animated launch screen featuring the APIDEL logo,
// background radial accents, and a teal progress indicator. It displays the Apidel logo
// for a minimum splash duration of 5 seconds while concurrently pre-fetching required CRM
// data (authentication, departments, contacts, companies, deals, master data) in the
// background before navigating to MainLayoutScreen or LoginScreen.
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/master_data_provider.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../authentication/presentation/screens/login_screen.dart';
import '../../../companies/presentation/providers/company_provider.dart';
import '../../../contacts/presentation/providers/contact_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../deals/presentation/providers/deal_provider.dart';
import '../../../departments/presentation/providers/department_provider.dart';
import 'main_layout_screen.dart';

/// Animated splash screen displaying Apidel branding for min 5s while pre-loading initial CRM data.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // 1. Setup entrance animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );

    _animationController.forward();

    // 2. Schedule startup initialization after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAppInitialization();
    });
  }

  /// Runs minimum 5-second splash duration concurrently with CRM data pre-fetching.
  Future<void> _startAppInitialization() async {
    final minSplashTimer = Future.delayed(const Duration(seconds: 5));
    bool isLoggedIn = false;

    final initTask = Future<void>(() async {
      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        isLoggedIn = authProvider.isAuthenticated;

        if (isLoggedIn) {
          final currentUser = authProvider.currentUser;
          if (currentUser != null) {
            await context.read<DepartmentProvider>().initFromUser(currentUser);
          }

          if (!mounted) return;

          final deptProvider = context.read<DepartmentProvider>();
          final currentDeptId = deptProvider.selectedDepartmentId;
          final currentDeptName = deptProvider.selectedDepartmentName;

          await Future.wait<void>([
            context.read<DashboardProvider>().loadDashboardData(
                  departmentId: currentDeptId,
                  departmentName: currentDeptName,
                ),
            context.read<ContactProvider>().fetchContacts(
                  refresh: true,
                  departmentId: currentDeptId,
                ),
            context.read<CompanyProvider>().fetchCompanies(
                  refresh: true,
                  departmentId: currentDeptId,
                ),
            context.read<DealProvider>().fetchDeals(
                  refresh: true,
                  departmentId: currentDeptId,
                ),
            context.read<DealProvider>().fetchDealStats(
                  departmentId: currentDeptId,
                ),
            context.read<MasterDataProvider>().fetchAllMasterData(
                  departmentId: currentDeptId,
                ),
          ]);
        }
      } catch (e) {
        debugPrint('[SplashScreen Initialization Error]: $e');
      }
    });

    // Wait for both minimum 5-second timer AND background initialization to complete
    await Future.wait([minSplashTimer, initTask]);

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (context, animation, secondaryAnimation) => FadeTransition(
          opacity: animation,
          child: isLoggedIn ? const MainLayoutScreen() : const LoginScreen(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Top-right background radial accent
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color(0x1F00A884),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Bottom-left background radial accent
            Positioned(
              bottom: -80,
              left: -80,
              child: Container(
                width: 250,
                height: 250,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color(0x1400A884),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Main Center Content
            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // APIDEL Brand Logo Image
                        Image.asset(
                          'assets/images/apidel_logo.png',
                          width: 280,
                          height: 75,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Image.asset(
                              'assets/images/apidel_logo.png',
                              fit: BoxFit.contain,
                            );
                          },
                        ),
                        const SizedBox(height: 48),

                        // Circular Teal Loading Indicator
                        const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.8,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFF00A884),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }
}
