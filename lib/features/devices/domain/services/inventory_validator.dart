import '../../../../core/utils/ipv4_utils.dart';
import '../entities/device_entity.dart';
import '../entities/inventory_import_preview.dart';

class RawInventoryRow {
  final int rowIndex;
  final String rawName;
  final String rawType;
  final String rawIp;
  final String rawOwner;
  final String rawDepartment;
  final String? rawOffice;
  final String? rawSwitchName;
  final String? rawVendor;
  final String? rawModel;

  const RawInventoryRow({
    required this.rowIndex,
    required this.rawName,
    required this.rawType,
    required this.rawIp,
    required this.rawOwner,
    required this.rawDepartment,
    this.rawOffice,
    this.rawSwitchName,
    this.rawVendor,
    this.rawModel,
  });
}

class InventoryValidator {
  /// Canonicalizes an IPv4 string into standard dotted-decimal notation (e.g. " 192.168.01.001 " -> "192.168.1.1").
  /// Returns null if the string is empty, malformed, or not a valid IPv4 address.
  static String? canonicalizeIpv4(String ip) => Ipv4Utils.canonicalizeIpv4(ip);

  static bool isValidIpv4(String ip) {
    return canonicalizeIpv4(ip) != null;
  }

  static InventoryImportPreview validateRows({
    required List<RawInventoryRow> rows,
    Set<String> existingDatabaseIps = const {},
  }) {
    final invalidRecords = <InventoryValidationError>[];
    final excludedDuplicateIps = <String>{};
    final validCandidates = <RawInventoryRow>[];

    // Canonicalize existing database IPs
    final canonicalExistingDbIps = <String>{};
    for (final dbIp in existingDatabaseIps) {
      final canon = canonicalizeIpv4(dbIp);
      if (canon != null) {
        canonicalExistingDbIps.add(canon);
      } else if (dbIp.trim().isNotEmpty) {
        canonicalExistingDbIps.add(dbIp.trim());
      }
    }

    // Step 1: Count IP occurrences across all input rows + check against DB
    final ipCountMap = <String, int>{};
    final nameCountMap = <String, int>{};

    for (final row in rows) {
      final canonIp = canonicalizeIpv4(row.rawIp);
      final cleanName = row.rawName.trim().toLowerCase();

      if (canonIp != null) {
        ipCountMap[canonIp] = (ipCountMap[canonIp] ?? 0) + 1;
      }
      if (cleanName.isNotEmpty) {
        nameCountMap[cleanName] = (nameCountMap[cleanName] ?? 0) + 1;
      }
    }

    // Mark IPs that are duplicated in the file or already exist in DB
    for (final entry in ipCountMap.entries) {
      if (entry.value > 1 || canonicalExistingDbIps.contains(entry.key)) {
        excludedDuplicateIps.add(entry.key);
      }
    }

    // Step 2: Validate each row strictly
    for (final row in rows) {
      final name = row.rawName.trim();
      final ip = row.rawIp.trim();
      final owner = row.rawOwner.trim();
      final dept = row.rawDepartment.trim();
      final typeStr = row.rawType.trim().toLowerCase();

      // Rule: PCs and Laptops only (Reject switch, router, access point or infrastructure types)
      if (typeStr.contains('switch') ||
          typeStr.contains('router') ||
          typeStr == 'ap' ||
          typeStr.contains('access point')) {
        invalidRecords.add(
          InventoryValidationError(
            rowIndex: row.rowIndex,
            deviceName: name,
            rawIp: ip,
            reason:
                'Switch/Network infrastructure monitoring is excluded in V1 scope.',
          ),
        );
        continue;
      }

      // Rule: Mandatory fields check
      if (ip.isEmpty) {
        invalidRecords.add(
          InventoryValidationError(
            rowIndex: row.rowIndex,
            deviceName: name,
            rawIp: ip,
            reason: 'Missing IP address.',
          ),
        );
        continue;
      }

      if (!isValidIpv4(ip)) {
        invalidRecords.add(
          InventoryValidationError(
            rowIndex: row.rowIndex,
            deviceName: name,
            rawIp: ip,
            reason: 'Invalid IPv4 format.',
          ),
        );
        continue;
      }

      if (owner.isEmpty) {
        invalidRecords.add(
          InventoryValidationError(
            rowIndex: row.rowIndex,
            deviceName: name,
            rawIp: ip,
            reason: 'Missing required device owner name.',
          ),
        );
        continue;
      }

      if (dept.isEmpty) {
        invalidRecords.add(
          InventoryValidationError(
            rowIndex: row.rowIndex,
            deviceName: name,
            rawIp: ip,
            reason: 'Missing required department.',
          ),
        );
        continue;
      }

      final canonIp = canonicalizeIpv4(ip);
      // Rule: Duplicate IP Check (All instances of duplicate IP are excluded)
      if (canonIp != null && excludedDuplicateIps.contains(canonIp)) {
        invalidRecords.add(
          InventoryValidationError(
            rowIndex: row.rowIndex,
            deviceName: name,
            rawIp: ip,
            reason:
                'Duplicate IP address detected across monitoring inventory ($ip). Excluded entirely.',
          ),
        );
        continue;
      }

      // Rule: Duplicate Device Name Check
      if (name.isNotEmpty && (nameCountMap[name.toLowerCase()] ?? 0) > 1) {
        invalidRecords.add(
          InventoryValidationError(
            rowIndex: row.rowIndex,
            deviceName: name,
            rawIp: ip,
            reason: 'Duplicate device name detected ($name).',
          ),
        );
        continue;
      }

      validCandidates.add(row);
    }

    final now = DateTime.now();
    final validDevices = validCandidates
        .map(
          (r) => DeviceEntity(
            id: 0,
            name: r.rawName.trim().isEmpty
                ? 'PC-${r.rawIp.split('.').last}'
                : r.rawName.trim(),
            type: DeviceType.fromString(r.rawType),
            ip: canonicalizeIpv4(r.rawIp) ?? r.rawIp.trim(),
            ownerName: r.rawOwner.trim(),
            department: r.rawDepartment.trim(),
            officeLocation: r.rawOffice?.trim().isNotEmpty == true
                ? r.rawOffice!.trim()
                : null,
            parentSwitchId: null,
            parentSwitchName: r.rawSwitchName?.trim().isNotEmpty == true
                ? r.rawSwitchName!.trim()
                : null,
            vendor: r.rawVendor?.trim().isNotEmpty == true
                ? r.rawVendor!.trim()
                : null,
            model: r.rawModel?.trim().isNotEmpty == true
                ? r.rawModel!.trim()
                : null,
            isEnabled: true,
            createdAt: now,
          ),
        )
        .toList();

    return InventoryImportPreview(
      validDevices: validDevices,
      excludedDuplicateIps: excludedDuplicateIps.toList(),
      invalidRecords: invalidRecords,
      totalRowsProcessed: rows.length,
    );
  }
}
