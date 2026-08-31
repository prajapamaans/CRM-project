// ============================================================================
// FILE PURPOSE & ARCHITECTURE OVERVIEW:
// ============================================================================
// What does this file do?
// -----------------------
// `login_screen.dart` is the main authentication user interface for the APIDEL CRM
// Flutter application. It renders a clean, responsive sign-in card where users enter
// their email and password to log into the system.
//
// How does the application workflow work in this file?
// ---------------------------------------------------
// 1. **Email Input & Live Verification**:
//    - As the user types their email address, `_onEmailChanged` detects a valid format
//      and triggers `_fetchUserEmailDetails`.
//    - It calls `AuthProvider.fetchEmailDetails` (POST /auth/email-details) to look up
//      the user's role and assigned department before submission.
//    - If the user is a regular user (non-admin), a read-only assigned department box
//      `_buildReadOnlyDepartmentField` is displayed.
// 2. **Form Submission & Authentication**:
//    - When the user taps "Sign In" (`_handleSignIn`), `_formKey.currentState!.validate()`
//      runs validation rules on the email and password text fields.
//    - `AuthProvider.login` submits credentials to POST /auth/login and GET /auth/me.
// 3. **Department State Initialization & Seamless Navigation**:
//    - Upon successful login, `DepartmentProvider.initFromUser` initializes the active
//      department selection from user profile data.
//    - The user is smoothly navigated to `InitialDataLoaderScreen` where all initial
//      application data (Dashboard, Contacts, Companies, Deals, Reports) is pre-fetched
//      before revealing `MainLayoutScreen`.
// 4. **Error Handling**:
//    - If authentication fails, `_showError` renders a floating red SnackBar displaying
//      the error returned by backend APIs.
//
// Explanation of Key Flutter & Project Keywords / Concepts:
// --------------------------------------------------------
// • `StatefulWidget`: A Flutter widget that has mutable state (`_LoginScreenState`).
//   It allows the screen to dynamically update its UI when data changes (e.g. typing email).
// • `State<_LoginScreenState>`: Holds the mutable variables, logic, and lifecycle hooks
//   (`initState`, `dispose`, `build`) for `LoginScreen`.
// • `GlobalKey<FormState>`: A unique reference key used to validate all child `TextFormField`
//   widgets in the `Form` container simultaneously.
// • `TextEditingController`: Manages text editing buffers for input fields (`_emailController`,
//   `_passwordController`), allowing reading, setting, or listening to user input.
// • `AuthProvider`: Provider state manager handling user login, JWT tokens, and auth session state.
// • `DepartmentProvider`: Provider managing active department choices and department switching.
// • `DepartmentConstants`: Holds central constant fallback values (e.g., `apacId`).
// • `mounted`: A boolean getter on `State`. Checking `if (mounted)` ensures the widget is still
//   active in the element tree before calling `setState()` or `Navigator` after async API gaps.
// • `context.read<T>()`: Obtains provider `T` without listening to UI rebuilds (ideal for callbacks).
// • `context.watch<T>()`: Obtains provider `T` and subscribes `build()` to rebuild when `T` changes.
// • `AutovalidateMode.onUserInteraction`: Triggers validation automatically as user types into fields.
// ============================================================================

import 'package:go_router/go_router.dart';
import '../../../../core/navigation/route_names.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../departments/presentation/providers/department_provider.dart';
import '../../../navigation/presentation/screens/initial_data_loader_screen.dart';
import '../providers/auth_provider.dart';

/// Full-screen responsive login form with email/password validation,
/// dynamic email role lookup, and backend API authentication.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Form key used to trigger global form field validation
  final _formKey = GlobalKey<FormState>();

  // Text controllers managing user input for email address and password
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Toggles password visibility in text field (true = hidden dots, false = visible text)
  bool _obscurePassword = true;

  // Selected department ID (defaults to APAC Team ID)
  String? _selectedDepartmentId = DepartmentConstants.apacId;

  // State flags for background email role verification
  bool _isFetchingEmailDetails = false;
  bool _isEmailChecked = false;
  String? _userRole;
  String? _assignedDeptName;

  // Primary brand color tokens used across the login card
  static const _tealDark = Color(0xFF0F5C5B);
  static const _tealLight = Color(0xFF2CA6A4);
  static const _bgGray = Color(0xFFF0F1F3);
  static const _borderGray = Color(0xFFE1E3E6);
  static const _hintGray = Color(0xFFB0B3B8);

  /// Helper getter evaluating if the verified user role is a regular non-admin user
  bool get _isRegularUser {
    if (_userRole == null) return false;
    final r = _userRole!.toUpperCase().replaceAll(' ', '_');
    return r != 'SUPER_ADMIN' && r != 'SUPERADMIN' && r != 'ADMIN';
  }

  @override
  void initState() {
    super.initState();
    // Attach listener to email input field to auto-verify email on typing
    _emailController.addListener(_onEmailChanged);
  }

  @override
  void dispose() {
    // Dispose text controllers to prevent memory leaks when screen is destroyed
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Triggered whenever user types into the Email text field.
  /// Automatically calls `_fetchUserEmailDetails` when a valid email format is entered.
  void _onEmailChanged() {
    final email = _emailController.text.trim();
    if (_validateEmail(email) == null) {
      _fetchUserEmailDetails(email);
    } else {
      if (_isEmailChecked) {
        setState(() {
          _isEmailChecked = false;
          _userRole = null;
          _assignedDeptName = null;
        });
      }
    }
  }

  /// Calls `AuthProvider.fetchEmailDetails` (POST /auth/email-details) to pre-fetch user role
  /// and department assignment before form submission.
  Future<void> _fetchUserEmailDetails(String email) async {
    if (_isFetchingEmailDetails) return;
    setState(() => _isFetchingEmailDetails = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final details = await authProvider.fetchEmailDetails(email);
      if (details != null && mounted) {
        setState(() {
          _isEmailChecked = true;
          _userRole = details.role;
          _assignedDeptName = details.departmentName;
          if (details.departmentId != null && details.departmentId!.isNotEmpty) {
            _selectedDepartmentId = details.departmentId;
          }
        });

        if (_isRegularUser && (details.data?.departments == null || details.data!.departments.isEmpty) && (details.departmentId == null || details.departmentId!.isEmpty)) {
          _showError('Access denied: You do not have permission to access the department.');
        }
      }
    } catch (e) {
      debugPrint('[LoginScreen fetchEmailDetails error]: $e');
    } finally {
      if (mounted) setState(() => _isFetchingEmailDetails = false);
    }
  }

  /// Returns a validation error string for the email field, or null if valid.
  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) return 'Enter a valid email address';
    return null;
  }

  /// Returns a validation error string for the password field, or null if valid.
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Password must be at least 8 characters';
    return null;
  }

  /// Validates form inputs, delegates authentication to [AuthProvider.login],
  /// initializes user department state, and navigates to [InitialDataLoaderScreen] on success.
  Future<void> _handleSignIn() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(
      _emailController.text.trim(),
      _passwordController.text,
      departmentId: _selectedDepartmentId,
    );

    if (!mounted) return;

    if (success) {
      final user = authProvider.currentUser;
      if (user != null) {
        await context.read<DepartmentProvider>().initFromUser(user);
      }
      if (!mounted) return;
      // Pre-fetch initial application data. `go` replaces login rather than
      // stacking on it, so Back from the dashboard never returns here.
      context.goNamed(RouteNames.dataLoader);
    } else {
      _showError(authProvider.error ?? 'Login failed');
    }
  }

  /// Displays a floating red SnackBar with the given error [message].
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch AuthProvider to update UI during loading state
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: _bgGray,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.fromLTRB(28, 40, 28, 32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildLogo(),
                    const SizedBox(height: 36),
                    _buildFieldLabel('EMAIL ADDRESS'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _emailController,
                      hint: 'name@company.com',
                      keyboardType: TextInputType.emailAddress,
                      validator: _validateEmail,
                      suffixIcon: _isFetchingEmailDetails
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _tealLight,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 20),

                    // Show read-only Department box ONLY if email is verified AND user is a regular 'User'
                    if (_isEmailChecked && _isRegularUser) ...[
                      _buildFieldLabel('DEPARTMENT'),
                      const SizedBox(height: 8),
                      _buildReadOnlyDepartmentField(),
                      const SizedBox(height: 20),
                    ],

                    _buildFieldLabel('PASSWORD'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _passwordController,
                      hint: 'Enter your password',
                      obscureText: _obscurePassword,
                      validator: _validatePassword,
                      suffixIcon: GestureDetector(
                        onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                        child: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 20,
                          color: _hintGray,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    _buildSignInButton(authProvider.isLoading || _isFetchingEmailDetails),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Renders the APIDEL brand logo image.
  Widget _buildLogo() {
    return Column(
      children: [
        Image.asset(
          'assets/images/apidel_logo.png',
          height: 65,
          width: 220,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Text(
              'APIDEL CRM',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: _tealDark,
                letterSpacing: 1.5,
              ),
            );
          },
        ),
      ],
    );
  }

  /// Renders a styled uppercase field label (e.g. "EMAIL ADDRESS").
  Widget _buildFieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: Color(0xFF2D3339),
      ),
    );
  }

  /// Builds read-only assigned department field for Normal User
  Widget _buildReadOnlyDepartmentField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _borderGray),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          const Icon(
            Icons.apartment_rounded,
            size: 18,
            color: Color(0xFF64748B),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _assignedDeptName ?? 'Assigned Department',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
          ),
          const Icon(Icons.lock_outline_rounded, size: 16, color: Color(0xFF94A3B8)),
        ],
      ),
    );
  }

  /// Builds a themed [TextFormField] with optional password visibility toggle.
  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      autofillHints: obscureText ? [AutofillHints.password] : [AutofillHints.email],
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _hintGray, fontSize: 14),
        suffixIcon: suffixIcon != null
            ? Padding(padding: const EdgeInsets.only(right: 12), child: suffixIcon)
            : null,
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _borderGray),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _borderGray),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _tealLight, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        errorStyle: const TextStyle(fontSize: 11),
      ),
    );
  }

  /// Gradient "Sign In" button. Shows a [CircularProgressIndicator] when [isLoading] is true.
  Widget _buildSignInButton(bool isLoading) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          colors: [_tealLight, _tealDark],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: isLoading ? null : _handleSignIn,
          child: Center(
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    'Sign In',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      letterSpacing: 0.3,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
