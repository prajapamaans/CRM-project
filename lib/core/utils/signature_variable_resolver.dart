import '../../features/authentication/data/models/user_model.dart';

/// Centralized utility for resolving dynamic `{{sender.*}}` placeholders inside email signatures and templates.
class SignatureVariableResolver {
  // Placeholder Constants
  static const String varFullName = '{{sender.fullName}}';
  static const String varFirstName = '{{sender.firstName}}';
  static const String varLastName = '{{sender.lastName}}';
  static const String varEmail = '{{sender.email}}';
  static const String varPhone = '{{sender.phone}}';
  static const String varPosition = '{{sender.position}}';
  static const String varDepartmentName = '{{sender.departmentName}}';

  /// List of supported variables for the "Insert Variable" dropdown menu.
  static const List<Map<String, String>> menuItems = [
    {'label': 'Full Name', 'value': varFullName},
    {'label': 'First Name', 'value': varFirstName},
    {'label': 'Last Name', 'value': varLastName},
    {'label': 'Email', 'value': varEmail},
    {'label': 'Phone', 'value': varPhone},
    {'label': 'Position', 'value': varPosition},
    {'label': 'Department', 'value': varDepartmentName},
  ];

  /// Resolves all `{{sender.*}}` variables in [content] using [currentUser] details from `/api/auth/me`.
  ///
  /// Preserves HTML formatting intact and replaces missing/null fields with empty strings.
  static String resolve(String content, UserModel? currentUser) {
    if (content.isEmpty) return '';

    final firstName = currentUser?.firstName.trim() ?? '';
    final lastName = currentUser?.lastName.trim() ?? '';

    // Construct Full Name safely without "null null"
    String fullName = '';
    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      fullName = '$firstName $lastName';
    } else if (firstName.isNotEmpty) {
      fullName = firstName;
    } else if (lastName.isNotEmpty) {
      fullName = lastName;
    }

    final email = currentUser?.email.trim() ?? '';
    final phone = currentUser?.phone?.trim() ?? '';
    final position = currentUser?.position?.trim() ?? '';
    final departmentName = currentUser?.departmentName?.trim() ?? '';

    String result = content;

    // Replace Full Name & legacy variants
    result = _replaceAll(result, ['{{sender.fullName}}', '{{sender.full_name}}', '{{sender.name}}'], fullName);

    // Replace First Name & legacy variants
    result = _replaceAll(result, ['{{sender.firstName}}', '{{sender.first_name}}'], firstName);

    // Replace Last Name & legacy variants
    result = _replaceAll(result, ['{{sender.lastName}}', '{{sender.last_name}}'], lastName);

    // Replace Email
    result = _replaceAll(result, ['{{sender.email}}'], email);

    // Replace Phone & legacy variants
    result = _replaceAll(result, ['{{sender.phone}}', '{{sender.phoneNumber}}', '{{sender.phone_number}}'], phone);

    // Replace Position & legacy variants
    result = _replaceAll(result, ['{{sender.position}}', '{{sender.title}}', '{{sender.jobTitle}}', '{{sender.job_title}}'], position);

    // Replace Department Name & legacy variants
    result = _replaceAll(result, ['{{sender.departmentName}}', '{{sender.department_name}}', '{{sender.department}}'], departmentName);

    return result;
  }

  /// Returns a clean text representation of [content] for preview display without raw HTML tags like `<p>` or `</p>`.
  static String cleanPreviewText(String content, UserModel? currentUser) {
    final resolved = resolve(content, currentUser);
    return resolved
        .replaceAll(RegExp(r'</?p\s*/?>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .trim();
  }

  static String _replaceAll(String target, List<String> placeholders, String replacement) {
    String output = target;
    for (final p in placeholders) {
      output = output.replaceAll(p, replacement);
    }
    return output;
  }
}
