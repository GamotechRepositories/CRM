abstract final class Validators {
  static String? required(String? value, {String field = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$field is required';
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!regex.hasMatch(value.trim())) return 'Enter a valid email';
    return null;
  }

  static String? minLength(
    String? value,
    int min, {
    String field = 'This field',
  }) {
    if (value == null || value.length < min) {
      return '$field must be at least $min characters';
    }
    return null;
  }

  /// Indian 10-digit mobile (optional +91 / 0 prefix stripped).
  static String? mobile(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Mobile number is required';
    }
    final digits = value.replaceAll(RegExp(r'\D'), '');
    var normalized = digits;
    if (normalized.startsWith('91') && normalized.length == 12) {
      normalized = normalized.substring(2);
    } else if (normalized.startsWith('0') && normalized.length == 11) {
      normalized = normalized.substring(1);
    }
    if (normalized.length != 10) {
      return 'Enter a valid 10-digit mobile number';
    }
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(normalized)) {
      return 'Enter a valid mobile number';
    }
    return null;
  }

  static String normalizeMobile(String value) {
    var digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('91') && digits.length == 12) {
      digits = digits.substring(2);
    } else if (digits.startsWith('0') && digits.length == 11) {
      digits = digits.substring(1);
    }
    return digits;
  }

  static bool isValidMobile(String? value) => mobile(value) == null;

  static String? otp(String? value, {int length = 6}) {
    if (value == null || value.length != length) {
      return 'Enter the $length-digit OTP';
    }
    if (!RegExp(r'^\d+$').hasMatch(value)) {
      return 'OTP must contain only digits';
    }
    return null;
  }
}
