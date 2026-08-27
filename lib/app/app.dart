// ============================================================================
// FILE PURPOSE & ARCHITECTURE OVERVIEW:
// ============================================================================
// What does this file do?
// -----------------------
// `app.dart` defines the root widget (`CrmApp`) for the entire APIDEL CRM Flutter application.
// It acts as the global state wrapper and configuration center, setting up all dependency injection
// providers, dynamic theme scaling, text scaling override, and launching the initial `SplashScreen`.
//
// How does the application workflow work in this file?
// ---------------------------------------------------
// 1. **MultiProvider Initialization**:
//    - `CrmApp` instantiates `MultiProvider` at the top level of the widget tree.
//    - Initializes all state providers (`FontSizeProvider`, `AuthProvider`, `NavigationProvider`,
//      `NotificationProvider`, `DepartmentProvider`, `DashboardProvider`, `DealProvider`,
//      `ContactProvider`, `CompanyProvider`, `MasterDataProvider`).
// 2. **Dynamic Font Scaling & Theme Binding**:
//    - Listens to `FontSizeProvider` via `Consumer<FontSizeProvider>`.
//    - Computes `userScale` relative to standard 16px text base.
//    - Applies `AppTheme.getThemeWithFontSize(fontProvider.fontSize)` to `MaterialApp`.
//    - Overrides `MediaQuery.textScaler` so user-selected font size applies across all screens.
// 3. **Home Route Dispatch**:
//    - Sets `home: const SplashScreen()` as the initial application screen.
//
// Explanation of Key Flutter & Project Keywords / Concepts:
// --------------------------------------------------------
// • `StatelessWidget`: A immutable Flutter widget whose UI configuration depends only on construction arguments.
// • `MultiProvider`: A Provider widget that merges multiple `ChangeNotifierProvider` declarations into a single tree node.
// • `ChangeNotifierProvider`: Creates and manages the lifecycle of a `ChangeNotifier` object, notifying listeners on state change.
// • `Consumer<T>`: A widget that subscribes to provider `T` and rebuilds only its child builder function when `T` calls `notifyListeners()`.
// • `MaterialApp`: Root widget for Material Design applications, providing routing, theme data, and locale configuration.
// • `TextScaler.linear`: Controls font scaling linearly across all `Text` widgets in the application.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/providers/font_size_provider.dart';
import '../core/providers/master_data_provider.dart';
import '../features/activities/presentation/providers/meeting_scheduler_provider.dart';
import '../features/authentication/presentation/providers/auth_provider.dart';
import '../features/companies/presentation/providers/company_provider.dart';
import '../features/contacts/presentation/providers/contact_provider.dart';
import '../features/dashboard/presentation/providers/dashboard_provider.dart';
import '../features/deals/presentation/providers/deal_provider.dart';
import '../features/departments/presentation/providers/department_provider.dart';
import '../features/navigation/presentation/providers/navigation_provider.dart';
import '../features/navigation/presentation/screens/splash_screen.dart';
import '../features/notifications/presentation/providers/notification_provider.dart';
import 'theme/app_theme.dart';

/// Root Application Widget configuring providers, theme scaling, and initial home route.
class CrmApp extends StatelessWidget {
  const CrmApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Wrap the entire application tree in MultiProvider for global dependency access
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FontSizeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => DepartmentProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => DealProvider()),
        ChangeNotifierProvider(create: (_) => ContactProvider()),
        ChangeNotifierProvider(create: (_) => CompanyProvider()),
        ChangeNotifierProvider(create: (_) => MasterDataProvider()..fetchCompanyMasterData()),
        ChangeNotifierProvider(create: (_) => MeetingSchedulerProvider()),
      ],
      // 2. Consume FontSizeProvider to dynamically re-theme and re-scale text across all screens
      child: Consumer<FontSizeProvider>(
        builder: (context, fontProvider, child) {
          final userScale = fontProvider.fontSize / 16.0;

          return MaterialApp(
            title: 'APIDEL CRM',
            debugShowCheckedModeBanner: false,
            // Apply customized theme with selected base font size
            theme: AppTheme.getThemeWithFontSize(fontProvider.fontSize),
            builder: (context, child) {
              final mediaQuery = MediaQuery.of(context);
              // Override textScaler globally so all Text widgets follow fontProvider
              return MediaQuery(
                data: mediaQuery.copyWith(
                  textScaler: TextScaler.linear(userScale),
                ),
                child: child!,
              );
            },
            // Set initial screen route to SplashScreen
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
