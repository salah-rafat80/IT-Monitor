enum ClassificationConfidence {
  high,
  medium,
  low,
  unknown;

  static ClassificationConfidence fromString(String value) {
    switch (value.toLowerCase()) {
      case 'high':
        return ClassificationConfidence.high;
      case 'medium':
        return ClassificationConfidence.medium;
      case 'low':
        return ClassificationConfidence.low;
      default:
        return ClassificationConfidence.unknown;
    }
  }

  String toValue() => name;

  String get displayName {
    switch (this) {
      case ClassificationConfidence.high:
        return 'High Confidence';
      case ClassificationConfidence.medium:
        return 'Medium Confidence';
      case ClassificationConfidence.low:
        return 'Low Confidence';
      case ClassificationConfidence.unknown:
        return 'Unknown';
    }
  }
}
