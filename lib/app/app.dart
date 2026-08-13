import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/authentication/presentation/providers/auth_provider.dart';
import '../features/companies/presentation/providers/company_provider.dart';
import '../features/contacts/presentation/providers/contact_provider.dart';
import '../features/dashboard/presentation/providers/dashboard_provider.dart';
import '../features/deals/presentation/providers/deal_provider.dart';
import '../features/departments/presentation/providers/department_provider.dart';
import '../features/navigation/presentation/providers/navigation_provider.dart';
import '../features/notifications/presentation/providers/notification_provider.dart';
import '../core/providers/master_data_provider.dart';
import '../features/navigation/presentation/screens/splash_screen.dart';
import 'theme/app_theme.dart';

/// Root widget that initializes providers and theme for the CRM application.
class CrmApp extends StatelessWidget {
  const CrmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => DepartmentProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => DealProvider()),
        ChangeNotifierProvider(create: (_) => ContactProvider()),
        ChangeNotifierProvider(create: (_) => CompanyProvider()),
        ChangeNotifierProvider(create: (_) => MasterDataProvider()..fetchCompanyMasterData()),
      ],
      child: MaterialApp(
        title: 'APIDEL CRM',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const SplashScreen(),
      ),
    );
  }
}
