import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../navigation/presentation/screens/main_layout_screen.dart';
import '../../../departments/presentation/providers/department_provider.dart';
import '../providers/auth_provider.dart';

/// Full-screen login form with email/password validation and API submission.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  String? _selectedDepartmentId = DepartmentConstants.apacId;

  static const _tealDark = Color(0xFF0F5C5B);
  static const _tealLight = Color(0xFF2CA6A4);
  static const _bgGray = Color(0xFFF0F1F3);
  static const _borderGray = Color(0xFFE1E3E6);
  static const _hintGray = Color(0xFFB0B3B8);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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

  /// Validates the form, delegates the login call to [AuthProvider],
  /// then navigates to [MainLayoutScreen] on success or shows a SnackBar on failure.
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
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainLayoutScreen()),
      );
    } else {
      _showError(authProvider.error ?? 'Login failed');
    }
  }

  /// Displays a floating red SnackBar with the given [message].
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
                              child: CircularProgressIndicator(strokeWidth: 2, color: _tealLight),
                            )
                          : null,
                    ),
                    const SizedBox(height: 20),

                    // Show Department field ONLY if email is checked AND user is regular 'User'
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
                          _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
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
          height: 60,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [_tealLight, _tealDark],
              ).createShader(bounds),
              child: const Text(
                'APIDEL',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
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

  bool _isFetchingEmailDetails = false;
  bool _isEmailChecked = false;
  String? _userRole;
  String? _assignedDeptName;

  bool get _isRegularUser {
    if (_userRole == null) return false;
    final r = _userRole!.toUpperCase().replaceAll(' ', '_');
    return r != 'SUPER_ADMIN' && r != 'SUPERADMIN' && r != 'ADMIN';
  }

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_onEmailChanged);
  }

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
      }
    } catch (e) {
      debugPrint('[LoginScreen fetchEmailDetails error]: $e');
    } finally {
      if (mounted) setState(() => _isFetchingEmailDetails = false);
    }
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

  /// Builds styled department selection dropdown or assigned department field.
  Widget _buildDepartmentDropdown(DepartmentProvider deptProvider) {
    final normalizedRole = _userRole?.toUpperCase().replaceAll(' ', '_');
    final isRegularUser = normalizedRole != null &&
        normalizedRole != 'SUPER_ADMIN' &&
        normalizedRole != 'SUPERADMIN' &&
        normalizedRole != 'ADMIN';

    // 1. If Normal User (and assigned department name exists), show read-only assigned department display
    if (isRegularUser && _assignedDeptName != null && _assignedDeptName!.isNotEmpty) {
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
                _assignedDeptName!,
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

    // 2. Default dropdown for Super Admin, Admin, or unverified email
    final depts = deptProvider.availableDepartments;

    final validSelected = depts.any((d) => d.id == _selectedDepartmentId)
        ? _selectedDepartmentId
        : (depts.isNotEmpty ? depts.first.id : null);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _borderGray),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: validSelected,
          isExpanded: true,
          icon: _isFetchingEmailDetails
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _tealLight))
              : const Icon(Icons.keyboard_arrow_down_rounded, color: _hintGray),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(12),
          items: depts.map((dept) {
            return DropdownMenuItem<String>(
              value: dept.id,
              child: Row(
                children: [
                  const Icon(
                    Icons.apartment_rounded,
                    size: 18,
                    color: _tealLight,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      dept.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (String? value) {
            if (value != null) {
              setState(() {
                _selectedDepartmentId = value;
              });
            }
          },
        ),
      ),
    );
  }

  /// Gradient "Sign In" button. Shows a [CircularProgressIndicator] when [isLoading].
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
