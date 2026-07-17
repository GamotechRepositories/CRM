extension StringExtensions on String {
  bool get isNullOrEmpty => trim().isEmpty;

  String get capitalize {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  String truncate(int maxLength, {String suffix = '…'}) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength)}$suffix';
  }
}

extension NullableStringExtensions on String? {
  bool get isNullOrBlank => this == null || this!.trim().isEmpty;
}
