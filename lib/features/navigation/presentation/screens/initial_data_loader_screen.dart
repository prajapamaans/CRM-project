// ============================================================================
// FILE PURPOSE & ARCHITECTURE OVERVIEW:
// ============================================================================
// What does this file do?
// -----------------------
// `initial_data_loader_screen.dart` is a global pre-fetching screen that runs immediately after
// user login or app authentication before navigating to `MainLayoutScreen`. It renders a smooth
// progress loader, executes concurrent initial API calls for all CRM modules (Departments,
// Dashboard reports, Contacts, Companies, Deals, Master Data), and presents a Retry screen if network
// requests fail.
//
// How does the application workflow work in this file?
// ---------------------------------------------------
// 1. **Post-Frame Pre-Fetch Callback**:
//    - `initState()` schedules `_loadAllData()` via `WidgetsBinding.instance.addPostFrameCallback`.
// 2. **Department Initialization**:
//    - Obtains active user profile from `AuthProvider`.
//    - Initializes active department ID via `DepartmentProvider.initFromUser`.
// 3. **Concurrent Data Pre-Fetching**:
//    - Runs `Future.wait` to fetch initial data simultaneously across providers:
//      - `DashboardProvider.loadDashboardData`
//      - `ContactProvider.fetchContacts`
//      - `CompanyProvider.fetchCompanies`
//      - `DealProvider.fetchDeals` & `fetchDealStats`
//      - `MasterDataProvider.fetchAllMasterData`
// 4. **Graceful Navigation & Exception Handling**:
//    - On success ──► Navigates smoothly to `MainLayoutScreen`.
//    - On exception ──► Halts loading and displays error state with a **Retry** button.
//
// Explanation of Key Flutter & Project Keywords / Concepts:
// --------------------------------------------------------
// • `WidgetsBinding.instance.addPostFrameCallback`: Schedules a callback to execute after the first frame build completes.
// • `Future.wait`: Runs multiple asynchronous Futures concurrently, waiting for all of them to complete.
// • `context.read<T>()`: Accesses provider instance `T` without subscribing to widget build updates.
// • `mounted`: Ensures widget is active in element tree before calling `setState()` or `Navigator`.
// • `PageRouteBuilder` & `FadeTransition`: Creates a custom smooth route transition.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/master_data_provider.dart';
import '../../../../theme/app_theme.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../companies/presentation/providers/company_provider.dart';
import '../../../contacts/presentation/providers/contact_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../deals/presentation/providers/deal_provider.dart';
import '../../../departments/presentation/providers/department_provider.dart';
import 'main_layout_screen.dart';

/// Full-screen initial data loader that pre-fetches all required CRM data
/// after user login or app authentication before navigating to [MainLayoutScreen].
class InitialDataLoaderScreen extends StatefulWidget {
  const InitialDataLoaderScreen({super.key});

  @override
  State<InitialDataLoaderScreen> createState() => _InitialDataLoaderScreenState();
}

class _InitialDataLoaderScreenState extends State<InitialDataLoaderScreen> {
  // Loading state flag and error message container
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Schedule _loadAllData to execute after the initial frame finishes building
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllData();
    });
  }

  /// Executes concurrent initial data pre-fetching across all core feature providers.
  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Fetch current authenticated user profile
      final authProvider = context.read<AuthProvider>();
      final currentUser = authProvider.currentUser;

      if (currentUser != null) {
        await context.read<DepartmentProvider>().initFromUser(currentUser);
      }

      if (!mounted) return;

      // 2. Extract selected department parameters
      final deptProvider = context.read<DepartmentProvider>();
      final currentDeptId = deptProvider.selectedDepartmentId;
      final currentDeptName = deptProvider.selectedDepartmentName;

      final dashboardProvider = context.read<DashboardProvider>();
      final contactProvider = context.read<ContactProvider>();
      final companyProvider = context.read<CompanyProvider>();
      final dealProvider = context.read<DealProvider>();
      final masterDataProvider = context.read<MasterDataProvider>();

      // 3. Pre-fetch all initial screen data concurrently using Future.wait
      await Future.wait<void>([
        dashboardProvider.loadDashboardData(
          departmentId: currentDeptId,
          departmentName: currentDeptName,
        ),
        contactProvider.fetchContacts(
          refresh: true,
          departmentId: currentDeptId,
        ),
        companyProvider.fetchCompanies(
          refresh: true,
          departmentId: currentDeptId,
        ),
        dealProvider.fetchDeals(
          refresh: true,
          departmentId: currentDeptId,
        ),
        dealProvider.fetchDealStats(
          departmentId: currentDeptId,
        ),
        masterDataProvider.fetchAllMasterData(
          departmentId: currentDeptId,
        ),
      ]);

      if (!mounted) return;

      // 4. Navigate smoothly to MainLayoutScreen once all data is fully loaded
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (context, animation, secondaryAnimation) => FadeTransition(
            opacity: animation,
            child: const MainLayoutScreen(),
          ),
        ),
      );
    } catch (e) {
      debugPrint('[InitialDataLoaderScreen Error]: $e');
      if (!mounted) return;
      // On exception, show error state with retry option
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Failed to load application data. Please verify your connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: _isLoading
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // APIDEL Brand Logo Image
                      Image.asset(
                        'assets/images/apidel_logo.png',
                        width: 240,
                        height: 65,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 28),
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: AppColors.primaryTeal,
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Cloud error icon
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: const Icon(
                          Icons.cloud_off_rounded,
                          size: 40,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Initialization Failed',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E293B),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _errorMessage ?? 'An error occurred during data load.',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: const Color(0xFF64748B),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),
                      // Retry Button to re-trigger _loadAllData
                      SizedBox(
                        width: 180,
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: _loadAllData,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: Text(
                            'Retry',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryTeal,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
