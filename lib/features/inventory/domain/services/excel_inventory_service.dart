import 'dart:convert';
import 'package:excel/excel.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/utils/ipv4_utils.dart';
import '../../../devices/domain/entities/device_entity.dart';
import '../../../devices/domain/entities/device_import_commit_payload.dart';

class ExcelImportRowResult {
  final int rowIndex;
  final DeviceEntity? device;
  final String rawName;
  final String rawIp;
  final String rawOwner;
  final String rawDepartment;
  final String action; // 'insert', 'update', 'invalid', 'skip'
  final String? rejectionReason;

  const ExcelImportRowResult({
    required this.rowIndex,
    this.device,
    this.rawName = '',
    this.rawIp = '',
    this.rawOwner = '',
    this.rawDepartment = '',
    required this.action,
    this.rejectionReason,
  });

  bool get isValid => action == 'insert' || action == 'update';
  bool get isInvalid => action == 'invalid';
}

class ExcelImportSummary {
  final List<ExcelImportRowResult> rows;
  final String targetFactoryId;
  final int insertCount;
  final int updateCount;
  final int invalidCount;
  final int skippedCount;

  const ExcelImportSummary({
    required this.rows,
    required this.targetFactoryId,
    required this.insertCount,
    required this.updateCount,
    required this.invalidCount,
    required this.skippedCount,
  });

  List<DeviceEntity> get validDevices => rows
      .where((r) => r.isValid && r.device != null)
      .map((r) => r.device!)
      .toList();

  List<DeviceEntity> get insertDevices => rows
      .where((r) => r.action == 'insert' && r.device != null)
      .map((r) => r.device!)
      .toList();

  List<DeviceEntity> get updateDevices => rows
      .where((r) => r.action == 'update' && r.device != null)
      .map((r) => r.device!)
      .toList();

  DeviceImportCommitPayload toCommitPayload() => DeviceImportCommitPayload(
    inserts: insertDevices,
    updates: updateDevices,
    targetFactoryId: targetFactoryId,
  );
}

abstract class ExcelInventoryService {
  List<int> exportToExcel({
    required List<DeviceEntity> devices,
    required String factoryCode,
  });

  List<int> generateTemplate({required String factoryCode});

  ExcelImportSummary parseAndValidateFile({
    required List<int> bytes,
    required String fileName,
    required String targetFactoryId,
    required List<DeviceEntity> existingFactoryDevices,
  });

  ExcelImportSummary parseAndValidateExcel({
    required List<int> bytes,
    required String targetFactoryId,
    required List<DeviceEntity> existingFactoryDevices,
  });

  ExcelImportSummary parseTabularTsv({
    required String tsvText,
    required String targetFactoryId,
    required List<DeviceEntity> existingFactoryDevices,
  });

  String exportToTsv(List<DeviceEntity> devices);
}

@LazySingleton(as: ExcelInventoryService)
class ExcelInventoryServiceImpl implements ExcelInventoryService {
  static const List<String> headers = [
    'ID',
    'Factory',
    'Device Name',
    'Device Type',
    'IP Address',
    'Owner Name',
    'Department',
    'Office Location',
    'MAC Address',
    'Hostname',
    'Vendor',
    'Model',
    'Operating System',
    'Parent Switch',
    'Monitored',
    'Enabled',
    'Notes',
  ];

  @override
  List<int> exportToExcel({
    required List<DeviceEntity> devices,
    required String factoryCode,
  }) {
    final excel = Excel.createExcel();
    final sheetName = '${factoryCode.toUpperCase()}_Inventory';
    final sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);

    // Remove default Sheet1 if different
    if (excel.tables.containsKey('Sheet1') && sheetName != 'Sheet1') {
      excel.delete('Sheet1');
    }

    // Header row
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

    for (final d in devices) {
      sheet.appendRow([
        IntCellValue(d.id),
        TextCellValue(d.factoryId.toUpperCase()),
        TextCellValue(d.name),
        TextCellValue(d.type.displayName),
        TextCellValue(d.ip),
        TextCellValue(d.ownerName),
        TextCellValue(d.department),
        TextCellValue(d.officeLocation ?? ''),
        TextCellValue(d.mac ?? ''),
        TextCellValue(d.hostname ?? ''),
        TextCellValue(d.vendor ?? ''),
        TextCellValue(d.model ?? ''),
        TextCellValue(d.operatingSystem ?? ''),
        TextCellValue(d.parentSwitchName ?? ''),
        TextCellValue(d.isMonitored ? 'Yes' : 'No'),
        TextCellValue(d.isEnabled ? 'Yes' : 'No'),
        TextCellValue(d.notes ?? ''),
      ]);
    }

    return excel.encode() ?? <int>[];
  }

  @override
  List<int> generateTemplate({required String factoryCode}) {
    final excel = Excel.createExcel();
    final sheetName = '${factoryCode.toUpperCase()}_Template';
    final sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);

    if (excel.tables.containsKey('Sheet1') && sheetName != 'Sheet1') {
      excel.delete('Sheet1');
    }

    // Header row only — untouched template imports zero devices
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

    return excel.encode() ?? <int>[];
  }

  @override
  ExcelImportSummary parseAndValidateFile({
    required List<int> bytes,
    required String fileName,
    required String targetFactoryId,
    required List<DeviceEntity> existingFactoryDevices,
  }) {
    final lower = fileName.toLowerCase().trim();
    if (lower.endsWith('.csv')) {
      return _parseAndValidateCsv(
        bytes: bytes,
        targetFactoryId: targetFactoryId,
        existingFactoryDevices: existingFactoryDevices,
      );
    }

    if (lower.endsWith('.xls') && !lower.endsWith('.xlsx')) {
      return ExcelImportSummary(
        rows: const [
          ExcelImportRowResult(
            rowIndex: 1,
            action: 'invalid',
            rejectionReason:
                'Legacy binary .xls format is not supported. Please save or export your file as modern .xlsx or standard .csv.',
          ),
        ],
        targetFactoryId: targetFactoryId,
        insertCount: 0,
        updateCount: 0,
        invalidCount: 1,
        skippedCount: 0,
      );
    }

    return parseAndValidateExcel(
      bytes: bytes,
      targetFactoryId: targetFactoryId,
      existingFactoryDevices: existingFactoryDevices,
    );
  }

  ExcelImportSummary _parseAndValidateCsv({
    required List<int> bytes,
    required String targetFactoryId,
    required List<DeviceEntity> existingFactoryDevices,
  }) {
    final text = utf8.decode(bytes, allowMalformed: true);
    final rawLines = text.split(RegExp(r'\r\n|\r|\n'));
    final rawDataRows = <Map<String, String>>[];

    List<List<String>> csvRecords = [];
    for (final line in rawLines) {
      if (line.trim().isEmpty) continue;
      final record = <String>[];
      final buffer = StringBuffer();
      bool inQuotes = false;
      for (int i = 0; i < line.length; i++) {
        final c = line[i];
        if (c == '"') {
          if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
            buffer.write('"');
            i++;
          } else {
            inQuotes = !inQuotes;
          }
        } else if ((c == ',' || c == ';') && !inQuotes) {
          record.add(buffer.toString().trim());
          buffer.clear();
        } else {
          buffer.write(c);
        }
      }
      record.add(buffer.toString().trim());
      csvRecords.add(record);
    }

    if (csvRecords.isEmpty) {
      return ExcelImportSummary(
        rows: const [],
        targetFactoryId: targetFactoryId,
        insertCount: 0,
        updateCount: 0,
        invalidCount: 0,
        skippedCount: 0,
      );
    }

    final headerRow = csvRecords.first;
    final headerMap = <String, int>{};
    for (int c = 0; c < headerRow.length; c++) {
      final val = headerRow[c].toLowerCase().trim();
      if (val.contains('id') && !val.contains('guid')) {
        headerMap['id'] = c;
      } else if (val.contains('device') ||
          val.contains('asset') ||
          val == 'name') {
        headerMap['name'] = c;
      } else if (val.contains('ip')) {
        headerMap['ip'] = c;
      } else if (val.contains('owner') ||
          val.contains('user') ||
          val.contains('assigned')) {
        headerMap['owner'] = c;
      } else if (val.contains('dept') || val.contains('department')) {
        headerMap['department'] = c;
      } else if (val.contains('loc') ||
          val.contains('office') ||
          val.contains('room')) {
        headerMap['office'] = c;
      } else if (val.contains('type') || val.contains('category')) {
        headerMap['type'] = c;
      } else if (val.contains('mac')) {
        headerMap['mac'] = c;
      } else if (val.contains('host')) {
        headerMap['hostname'] = c;
      } else if (val.contains('vendor') || val.contains('make')) {
        headerMap['vendor'] = c;
      } else if (val.contains('model')) {
        headerMap['model'] = c;
      } else if (val.contains('os') || val.contains('operating')) {
        headerMap['os'] = c;
      } else if (val.contains('switch')) {
        headerMap['switch'] = c;
      } else if (val.contains('monitor')) {
        headerMap['monitored'] = c;
      } else if (val.contains('enable')) {
        headerMap['enabled'] = c;
      } else if (val.contains('note')) {
        headerMap['notes'] = c;
      }
    }

    for (int r = 1; r < csvRecords.length; r++) {
      final row = csvRecords[r];
      if (row.isEmpty) continue;

      String getCol(String key) {
        final idx = headerMap[key];
        if (idx == null || idx >= row.length) return '';
        return row[idx].trim();
      }

      final ip = getCol('ip');
      final name = getCol('name');
      final owner = getCol('owner');
      final dept = getCol('department');

      if (ip.isEmpty && name.isEmpty && owner.isEmpty && dept.isEmpty) {
        continue;
      }

      rawDataRows.add({
        'rowIndex': (r + 1).toString(),
        'id': getCol('id'),
        'name': name,
        'ip': ip,
        'owner': owner,
        'department': dept,
        'office': getCol('office'),
        'type': getCol('type'),
        'mac': getCol('mac'),
        'hostname': getCol('hostname'),
        'vendor': getCol('vendor'),
        'model': getCol('model'),
        'os': getCol('os'),
        'switch': getCol('switch'),
        'monitored': getCol('monitored'),
        'enabled': getCol('enabled'),
        'notes': getCol('notes'),
      });
    }

    return _validateRawRows(
      rawRows: rawDataRows,
      targetFactoryId: targetFactoryId,
      existingFactoryDevices: existingFactoryDevices,
    );
  }

  @override
  ExcelImportSummary parseAndValidateExcel({
    required List<int> bytes,
    required String targetFactoryId,
    required List<DeviceEntity> existingFactoryDevices,
  }) {
    Excel excel;
    try {
      excel = Excel.decodeBytes(bytes);
    } catch (e) {
      return ExcelImportSummary(
        rows: [
          ExcelImportRowResult(
            rowIndex: 1,
            action: 'invalid',
            rejectionReason:
                'Failed to decode spreadsheet file: ensure the file is a valid, uncorrupted .xlsx workbook. ($e)',
          ),
        ],
        targetFactoryId: targetFactoryId,
        insertCount: 0,
        updateCount: 0,
        invalidCount: 1,
        skippedCount: 0,
      );
    }
    final rawDataRows = <Map<String, String>>[];

    for (final table in excel.tables.keys) {
      final sheet = excel.tables[table];
      if (sheet == null || sheet.maxRows <= 1) continue;

      final headerRow = sheet.rows.first;
      final headerMap = <String, int>{};

      for (int c = 0; c < headerRow.length; c++) {
        final val = headerRow[c]?.value?.toString().toLowerCase().trim() ?? '';
        if (val.contains('id') && !val.contains('guid')) {
          headerMap['id'] = c;
        } else if (val.contains('device') ||
            val.contains('asset') ||
            val == 'name') {
          headerMap['name'] = c;
        } else if (val.contains('ip')) {
          headerMap['ip'] = c;
        } else if (val.contains('owner') ||
            val.contains('user') ||
            val.contains('assigned')) {
          headerMap['owner'] = c;
        } else if (val.contains('dept') || val.contains('department')) {
          headerMap['department'] = c;
        } else if (val.contains('loc') ||
            val.contains('office') ||
            val.contains('room')) {
          headerMap['office'] = c;
        } else if (val.contains('type') || val.contains('category')) {
          headerMap['type'] = c;
        } else if (val.contains('mac')) {
          headerMap['mac'] = c;
        } else if (val.contains('host')) {
          headerMap['hostname'] = c;
        } else if (val.contains('vendor') || val.contains('make')) {
          headerMap['vendor'] = c;
        } else if (val.contains('model')) {
          headerMap['model'] = c;
        } else if (val.contains('os') || val.contains('operating')) {
          headerMap['os'] = c;
        } else if (val.contains('switch')) {
          headerMap['switch'] = c;
        } else if (val.contains('monitor')) {
          headerMap['monitored'] = c;
        } else if (val.contains('enable')) {
          headerMap['enabled'] = c;
        } else if (val.contains('note')) {
          headerMap['notes'] = c;
        }
      }

      for (int r = 1; r < sheet.rows.length; r++) {
        final row = sheet.rows[r];
        if (row.isEmpty) continue;

        String getCol(String key) {
          final idx = headerMap[key];
          if (idx == null || idx >= row.length) return '';
          return row[idx]?.value?.toString().trim() ?? '';
        }

        final ip = getCol('ip');
        final name = getCol('name');
        final owner = getCol('owner');
        final dept = getCol('department');

        if (ip.isEmpty && name.isEmpty && owner.isEmpty && dept.isEmpty) {
          continue; // skip completely empty row
        }

        rawDataRows.add({
          'rowIndex': (r + 1).toString(),
          'id': getCol('id'),
          'name': name,
          'ip': ip,
          'owner': owner,
          'department': dept,
          'office': getCol('office'),
          'type': getCol('type'),
          'mac': getCol('mac'),
          'hostname': getCol('hostname'),
          'vendor': getCol('vendor'),
          'model': getCol('model'),
          'os': getCol('os'),
          'switch': getCol('switch'),
          'monitored': getCol('monitored'),
          'enabled': getCol('enabled'),
          'notes': getCol('notes'),
        });
      }
    }

    return _validateRawRows(
      rawRows: rawDataRows,
      targetFactoryId: targetFactoryId,
      existingFactoryDevices: existingFactoryDevices,
    );
  }

  @override
  ExcelImportSummary parseTabularTsv({
    required String tsvText,
    required String targetFactoryId,
    required List<DeviceEntity> existingFactoryDevices,
  }) {
    final lines = const LineSplitter().convert(tsvText);
    final rawDataRows = <Map<String, String>>[];
    if (lines.isEmpty) {
      return ExcelImportSummary(
        rows: const [],
        targetFactoryId: targetFactoryId,
        insertCount: 0,
        updateCount: 0,
        invalidCount: 0,
        skippedCount: 0,
      );
    }

    // Check if first row is header
    int startIdx = 0;
    final firstCells = lines.first
        .split('\t')
        .map((c) => c.trim().toLowerCase())
        .toList();
    bool hasHeader = firstCells.any(
      (c) => c.contains('ip') || c.contains('name') || c.contains('owner'),
    );
    final headerMap = <String, int>{};

    if (hasHeader) {
      startIdx = 1;
      for (int c = 0; c < firstCells.length; c++) {
        final val = firstCells[c];
        if (val.contains('id')) {
          headerMap['id'] = c;
        } else if (val.contains('device') ||
            val.contains('asset') ||
            val == 'name') {
          headerMap['name'] = c;
        } else if (val.contains('ip')) {
          headerMap['ip'] = c;
        } else if (val.contains('owner') || val.contains('user')) {
          headerMap['owner'] = c;
        } else if (val.contains('dept') || val.contains('department')) {
          headerMap['department'] = c;
        } else if (val.contains('loc') || val.contains('office')) {
          headerMap['office'] = c;
        } else if (val.contains('type')) {
          headerMap['type'] = c;
        } else if (val.contains('mac')) {
          headerMap['mac'] = c;
        } else if (val.contains('host')) {
          headerMap['hostname'] = c;
        }
      }
    }

    for (int i = startIdx; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final cells = lines[i].split('\t');

      String getByIndexOrHeader(String key, int defaultIndex) {
        if (hasHeader && headerMap.containsKey(key)) {
          final idx = headerMap[key]!;
          if (idx < cells.length) return cells[idx].trim();
          return '';
        }
        if (defaultIndex < cells.length) return cells[defaultIndex].trim();
        return '';
      }

      // Default column layout fallback if headerless:
      // 0: Name, 1: IP, 2: Owner, 3: Dept, 4: Office, 5: Type
      rawDataRows.add({
        'rowIndex': (i + 1).toString(),
        'id': getByIndexOrHeader('id', 99),
        'name': getByIndexOrHeader('name', 0),
        'ip': getByIndexOrHeader('ip', 1),
        'owner': getByIndexOrHeader('owner', 2),
        'department': getByIndexOrHeader('department', 3),
        'office': getByIndexOrHeader('office', 4),
        'type': getByIndexOrHeader('type', 5),
        'mac': getByIndexOrHeader('mac', 6),
        'hostname': getByIndexOrHeader('hostname', 7),
        'vendor': getByIndexOrHeader('vendor', 8),
        'model': getByIndexOrHeader('model', 9),
        'os': getByIndexOrHeader('os', 10),
        'switch': getByIndexOrHeader('switch', 11),
        'monitored': getByIndexOrHeader('monitored', 12),
        'enabled': getByIndexOrHeader('enabled', 13),
        'notes': getByIndexOrHeader('notes', 14),
      });
    }

    return _validateRawRows(
      rawRows: rawDataRows,
      targetFactoryId: targetFactoryId,
      existingFactoryDevices: existingFactoryDevices,
    );
  }

  @override
  String exportToTsv(List<DeviceEntity> devices) {
    final buffer = StringBuffer();
    buffer.writeln(headers.join('\t'));
    for (final d in devices) {
      buffer.writeln(
        [
          d.id,
          d.factoryId.toUpperCase(),
          d.name,
          d.type.displayName,
          d.ip,
          d.ownerName,
          d.department,
          d.officeLocation ?? '',
          d.mac ?? '',
          d.hostname ?? '',
          d.vendor ?? '',
          d.model ?? '',
          d.operatingSystem ?? '',
          d.parentSwitchName ?? '',
          d.isMonitored ? 'Yes' : 'No',
          d.isEnabled ? 'Yes' : 'No',
          d.notes ?? '',
        ].join('\t'),
      );
    }
    return buffer.toString();
  }

  ExcelImportSummary _validateRawRows({
    required List<Map<String, String>> rawRows,
    required String targetFactoryId,
    required List<DeviceEntity> existingFactoryDevices,
  }) {
    final results = <ExcelImportRowResult>[];
    int insertCount = 0;
    int updateCount = 0;
    int invalidCount = 0;
    int skippedCount = 0;

    // Existing factory indexes: IP -> DeviceEntity, ID -> DeviceEntity
    final existingIpMap = <String, DeviceEntity>{};
    final existingIdMap = <int, DeviceEntity>{};
    for (final d in existingFactoryDevices) {
      final canon = Ipv4Utils.canonicalizeIpv4(d.ip);
      if (canon != null) existingIpMap[canon] = d;
      existingIdMap[d.id] = d;
    }

    // Detect duplicate IPs within the import batch itself
    final batchIpCounts = <String, int>{};
    for (final r in rawRows) {
      final ip = Ipv4Utils.canonicalizeIpv4(r['ip'] ?? '');
      if (ip != null) {
        batchIpCounts[ip] = (batchIpCounts[ip] ?? 0) + 1;
      }
    }

    for (final r in rawRows) {
      final rIndex = int.tryParse(r['rowIndex'] ?? '0') ?? 0;
      final rawName = r['name']?.trim() ?? '';
      final rawIp = r['ip']?.trim() ?? '';
      final rawOwner = r['owner']?.trim() ?? '';
      final rawDept = r['department']?.trim() ?? '';
      final rawId = int.tryParse(r['id']?.trim() ?? '');

      // Validation 0: Skip demonstration / template guidance example rows
      final lowerName = rawName.toLowerCase();
      final lowerIp = rawIp.toLowerCase();
      if (lowerName.contains('ws-eng-01') ||
          lowerName.contains('lp-fin-02') ||
          lowerName.startsWith('leave empty') ||
          lowerName.contains('[example]') ||
          lowerName.contains('sample guidance') ||
          lowerIp.startsWith('leave empty')) {
        skippedCount++;
        results.add(
          ExcelImportRowResult(
            rowIndex: rIndex,
            rawName: rawName,
            rawIp: rawIp,
            rawOwner: rawOwner,
            rawDepartment: rawDept,
            action: 'skip',
            rejectionReason: 'Template example/guidance row ignored.',
          ),
        );
        continue;
      }

      // Validation 1: Required fields
      if (rawName.isEmpty) {
        invalidCount++;
        results.add(
          ExcelImportRowResult(
            rowIndex: rIndex,
            rawName: rawName,
            rawIp: rawIp,
            rawOwner: rawOwner,
            rawDepartment: rawDept,
            action: 'invalid',
            rejectionReason: 'Missing required device name.',
          ),
        );
        continue;
      }

      if (rawIp.isEmpty) {
        invalidCount++;
        results.add(
          ExcelImportRowResult(
            rowIndex: rIndex,
            rawName: rawName,
            rawIp: rawIp,
            rawOwner: rawOwner,
            rawDepartment: rawDept,
            action: 'invalid',
            rejectionReason: 'Missing required IP address.',
          ),
        );
        continue;
      }

      final canonicalIp = Ipv4Utils.canonicalizeIpv4(rawIp);
      if (canonicalIp == null) {
        invalidCount++;
        results.add(
          ExcelImportRowResult(
            rowIndex: rIndex,
            rawName: rawName,
            rawIp: rawIp,
            rawOwner: rawOwner,
            rawDepartment: rawDept,
            action: 'invalid',
            rejectionReason: 'Invalid IPv4 address format: "$rawIp".',
          ),
        );
        continue;
      }

      if (rawOwner.isEmpty) {
        invalidCount++;
        results.add(
          ExcelImportRowResult(
            rowIndex: rIndex,
            rawName: rawName,
            rawIp: rawIp,
            rawOwner: rawOwner,
            rawDepartment: rawDept,
            action: 'invalid',
            rejectionReason: 'Missing required owner/user name.',
          ),
        );
        continue;
      }

      if (rawDept.isEmpty) {
        invalidCount++;
        results.add(
          ExcelImportRowResult(
            rowIndex: rIndex,
            rawName: rawName,
            rawIp: rawIp,
            rawOwner: rawOwner,
            rawDepartment: rawDept,
            action: 'invalid',
            rejectionReason: 'Missing required department.',
          ),
        );
        continue;
      }

      // Validation 2: Duplicate IP within the batch file itself
      if ((batchIpCounts[canonicalIp] ?? 0) > 1) {
        invalidCount++;
        results.add(
          ExcelImportRowResult(
            rowIndex: rIndex,
            rawName: rawName,
            rawIp: rawIp,
            rawOwner: rawOwner,
            rawDepartment: rawDept,
            action: 'invalid',
            rejectionReason:
                'Duplicate IP $canonicalIp occurs multiple times in imported spreadsheet.',
          ),
        );
        continue;
      }

      // Check if updating existing device in this factory
      DeviceEntity? match;
      if (rawId != null && existingIdMap.containsKey(rawId)) {
        match = existingIdMap[rawId];
      } else if (existingIpMap.containsKey(canonicalIp)) {
        match = existingIpMap[canonicalIp];
      }

      final isMonitored = r['monitored']?.toLowerCase() != 'no';
      final isEnabled = r['enabled']?.toLowerCase() != 'no';
      final type = DeviceType.fromString(r['type'] ?? 'pc');

      if (match != null) {
        // Update row
        final updated = match.copyWith(
          factoryId: targetFactoryId,
          name: rawName,
          type: type,
          ip: canonicalIp,
          ownerName: rawOwner,
          department: rawDept,
          officeLocation: r['office']?.isNotEmpty == true
              ? r['office']
              : match.officeLocation,
          mac: r['mac']?.isNotEmpty == true ? r['mac'] : match.mac,
          hostname: r['hostname']?.isNotEmpty == true
              ? r['hostname']
              : match.hostname,
          vendor: r['vendor']?.isNotEmpty == true ? r['vendor'] : match.vendor,
          model: r['model']?.isNotEmpty == true ? r['model'] : match.model,
          operatingSystem: r['os']?.isNotEmpty == true
              ? r['os']
              : match.operatingSystem,
          parentSwitchName: r['switch']?.isNotEmpty == true
              ? r['switch']
              : match.parentSwitchName,
          notes: r['notes']?.isNotEmpty == true ? r['notes'] : match.notes,
          isMonitored: isMonitored,
          isEnabled: isEnabled,
          updatedAt: DateTime.now(),
        );

        updateCount++;
        results.add(
          ExcelImportRowResult(
            rowIndex: rIndex,
            device: updated,
            rawName: rawName,
            rawIp: rawIp,
            rawOwner: rawOwner,
            rawDepartment: rawDept,
            action: 'update',
          ),
        );
      } else {
        // Insert row
        final newDev = DeviceEntity(
          id: 0, // Assigned by DB
          factoryId: targetFactoryId,
          name: rawName,
          type: type,
          ip: canonicalIp,
          ownerName: rawOwner,
          department: rawDept,
          officeLocation: r['office']?.isEmpty == true ? null : r['office'],
          mac: r['mac']?.isEmpty == true ? null : r['mac'],
          hostname: r['hostname']?.isEmpty == true ? null : r['hostname'],
          vendor: r['vendor']?.isEmpty == true ? null : r['vendor'],
          model: r['model']?.isEmpty == true ? null : r['model'],
          operatingSystem: r['os']?.isEmpty == true ? null : r['os'],
          parentSwitchName: r['switch']?.isEmpty == true ? null : r['switch'],
          notes: r['notes']?.isEmpty == true ? null : r['notes'],
          isMonitored: isMonitored,
          isEnabled: isEnabled,
          createdAt: DateTime.now(),
        );

        insertCount++;
        results.add(
          ExcelImportRowResult(
            rowIndex: rIndex,
            device: newDev,
            rawName: rawName,
            rawIp: rawIp,
            rawOwner: rawOwner,
            rawDepartment: rawDept,
            action: 'insert',
          ),
        );
      }
    }

    return ExcelImportSummary(
      rows: results,
      targetFactoryId: targetFactoryId,
      insertCount: insertCount,
      updateCount: updateCount,
      invalidCount: invalidCount,
      skippedCount: skippedCount,
    );
  }
}
