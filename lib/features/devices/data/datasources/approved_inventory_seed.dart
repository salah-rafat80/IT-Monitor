import '../../domain/services/inventory_validator.dart';

class ApprovedInventorySeed {
  /// Zero data fabrication: Returns an empty list so inventory enters the system
  /// strictly through user-imported Excel spreadsheets.
  static List<RawInventoryRow> getApprovedRawRows() {
    return const [];
  }
}
