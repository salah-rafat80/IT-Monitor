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

  static String? _resolveHeaderKey(String raw) {
    final norm = raw
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (norm.isEmpty) return null;

    // 1. Exact normalized matches for application export headers
    switch (norm) {
      case 'id':
      case 'device id':
        return 'id';
      case 'factory':
      case 'factory id':
      case 'factory code':
        return 'factory';
      case 'device name':
      case 'computername':
      case 'computer name':
      case 'pc name':
      case 'name':
        return 'name';
      case 'device type':
      case 'type':
        return 'type';
      case 'ip address':
      case 'ip':
      case 'ipv4':
      case 'ipv4 address':
        return 'ip';
      case 'owner name':
      case 'owner':
      case 'username':
      case 'user name':
      case 'user':
        return 'owner';
      case 'email':
      case 'user email':
      case 'mail':
        return 'email';
      case 'department':
      case 'dept':
        return 'department';
      case 'office location':
      case 'office':
      case 'location':
        return 'office';
      case 'mac address':
      case 'mac':
        return 'mac';
      case 'hostname':
      case 'host name':
      case 'host':
        return 'hostname';
      case 'vendor':
      case 'manufacturer':
      case 'make':
        return 'vendor';
      case 'model':
        return 'model';
      case 'operating system':
      case 'os':
        return 'os';
      case 'os version':
        return 'os_version';
      case 'os architecture':
      case 'os arch':
      case 'architecture':
        return 'os_arch';
      case 'serialnumber':
      case 'serial number':
      case 'serial':
      case 'sn':
        return 'serial';
      case 'cpu':
      case 'processor':
        return 'cpu';
      case 'cpu cores':
      case 'cores':
      case 'cpu core':
        return 'cpu_cores';
      case 'cpu threads':
      case 'threads':
      case 'cpu thread':
        return 'cpu_threads';
      case 'ram gb':
      case 'ram':
      case 'memory':
        return 'ram_gb';
      case 'ram modules':
      case 'ram module':
        return 'ram_modules';
      case 'storage':
      case 'disk':
      case 'drive':
      case 'hdd':
      case 'ssd':
        return 'storage';
      case 'gpu':
      case 'graphics':
      case 'display adapter':
      case 'video card':
        return 'gpu';
      case 'bios version':
      case 'bios ver':
      case 'bios date':
      case 'bios':
        return 'bios';
      case 'lastupdated':
      case 'last updated':
        return 'last_updated';
      case 'parent switch':
      case 'switch':
        return 'switch';
      case 'monitored':
      case 'is monitored':
        return 'monitored';
      case 'enabled':
      case 'is enabled':
        return 'enabled';
      case 'notes':
      case 'note':
      case 'comments':
      case 'comment':
        return 'notes';
    }

    // 2. Fallbacks for third-party spreadsheets.
    // Order matters: check more specific tokens before broad tokens.
    if (norm.contains('type') || norm.contains('category')) {
      return 'type';
    }
    if (norm.contains('mac')) {
      return 'mac';
    }
    if (norm.contains('ip') ||
        (norm.contains('address') && !norm.contains('mac'))) {
      return 'ip';
    }
    if (norm.contains('serial') || norm == 'sn') {
      return 'serial';
    }
    if (norm.contains('email') || norm.contains('mail')) {
      return 'email';
    }
    if (norm.contains('owner') ||
        norm.contains('user') ||
        norm.contains('assigned')) {
      return 'owner';
    }
    if (norm.contains('device') ||
        norm.contains('asset') ||
        norm.contains('computer') ||
        norm.contains('name')) {
      return 'name';
    }
    if (norm.contains('dept') || norm.contains('department')) {
      return 'department';
    }
    if (norm.contains('loc') ||
        norm.contains('office') ||
        norm.contains('room')) {
      return 'office';
    }
    if (norm.contains('host')) {
      return 'hostname';
    }
    if (norm.contains('vendor') ||
        norm.contains('make') ||
        norm.contains('mfr')) {
      return 'vendor';
    }
    if (norm.contains('model')) {
      return 'model';
    }
    // Specific hardware detail tokens MUST run before broad generic tokens:
    if (norm.contains('bios')) {
      return 'bios';
    }
    if (norm.contains('cpu core') || norm.contains('cores') || norm == 'core') {
      return 'cpu_cores';
    }
    if (norm.contains('cpu thread') || norm.contains('threads') || norm == 'thread') {
      return 'cpu_threads';
    }
    if (norm.contains('ram module') || norm.contains('modules')) {
      return 'ram_modules';
    }
    if (norm.contains('os ver') || norm.contains('os build') || norm.contains('os release')) {
      return 'os_version';
    }
    if (norm.contains('os arch') || norm.contains('architecture') || norm.contains('bitness')) {
      return 'os_arch';
    }
    if (norm.contains('operating') ||
        norm == 'os' ||
        norm.startsWith('os ') ||
        norm.endsWith(' os') ||
        norm.contains(' os ') ||
        norm.contains('os_') ||
        norm.contains('os-') ||
        norm.contains('os name')) {
      return 'os';
    }
    if (norm.contains('cpu') || norm.contains('processor')) {
      return 'cpu';
    }
    if (norm.contains('ram') || norm.contains('memory')) {
      return 'ram_gb';
    }
    if (norm.contains('storage') ||
        norm.contains('disk') ||
        norm.contains('ssd')) {
      return 'storage';
    }
    if (norm.contains('gpu') || norm.contains('graphic')) {
      return 'gpu';
    }
    if (norm.contains('switch')) {
      return 'switch';
    }
    if (norm.contains('monitor')) {
      return 'monitored';
    }
    if (norm.contains('enable')) {
      return 'enabled';
    }
    if (norm.contains('note') || norm.contains('desc')) {
      return 'notes';
    }
    if (norm.contains('id') && !norm.contains('guid')) {
      return 'id';
    }

    return null;
  }

  static Map<String, int> _buildHeaderMap(List<String> rawHeaders) {
    final headerMap = <String, int>{};
    for (int c = 0; c < rawHeaders.length; c++) {
      final key = _resolveHeaderKey(rawHeaders[c]);
      if (key != null && !headerMap.containsKey(key)) {
        headerMap[key] = c;
      }
    }
    return headerMap;
  }

  static bool? _parseNullableBool(String? val) {
    if (val == null) return null;
    final cleaned = val.trim().toLowerCase();
    if (cleaned.isEmpty) return null;
    if (cleaned == 'yes' ||
        cleaned == 'y' ||
        cleaned == 'true' ||
        cleaned == '1' ||
        cleaned == 'enabled' ||
        cleaned == 'monitored') {
      return true;
    }
    if (cleaned == 'no' ||
        cleaned == 'n' ||
        cleaned == 'false' ||
        cleaned == '0' ||
        cleaned == 'disabled' ||
        cleaned == 'unmonitored') {
      return false;
    }
    return null;
  }

  static String _cleanOwnerName(String rawOwner) {
    var owner = rawOwner.trim();
    if (owner.contains(r'\')) {
      owner = owner.split(r'\').last.trim();
    }
    if (owner.contains('/') && !owner.contains('http')) {
      owner = owner.split('/').last.trim();
    }
    if (owner.contains('.') && !owner.contains('@') && !owner.contains(' ')) {
      final parts = owner.split('.');
      if (parts.length >= 2 && parts.every((p) => p.length > 1)) {
        owner = parts
            .map(
              (p) =>
                  p.isEmpty ? '' : '${p[0].toUpperCase()}${p.substring(1)}',
            )
            .join(' ');
      }
    }
    return owner;
  }

  static String _inferDepartment({
    required String rawDept,
    required String name,
    required String owner,
    required String email,
    String? existingDept,
  }) {
    if (rawDept.trim().isNotEmpty) return rawDept.trim();
    if (existingDept != null && existingDept.trim().isNotEmpty) {
      return existingDept.trim();
    }

    final comb = '$name $owner $email'.toLowerCase();
    if (comb.contains('qc') ||
        comb.contains('qa') ||
        comb.contains('inspector') ||
        comb.contains('lab')) {
      return 'QC-QA';
    }
    if (comb.contains('whs') || comb.contains('warehouse')) {
      return 'Warehouse';
    }
    if (comb.contains('fin') ||
        comb.contains('acct') ||
        comb.contains('accounting') ||
        comb.contains('ayman') ||
        comb.contains('essam')) {
      return 'Accounting';
    }
    if (comb.contains('hr') || comb.contains('personnel')) {
      return 'HR';
    }
    if (comb.contains('pur') || comb.contains('purchas')) {
      return 'Purchasing';
    }
    if (comb.contains('ppic')) {
      return 'P.P.I.C';
    }
    if (comb.contains('prod') || comb.contains('forman')) {
      return 'Production';
    }
    if (comb.contains('maint') ||
        comb.contains('tech') ||
        comb.contains('repair')) {
      return 'Maintenance';
    }
    if (comb.contains('safety')) {
      return 'Safety';
    }
    if (comb.contains('logistic')) {
      return 'Logistics';
    }
    return 'General';
  }

  static String _composeHardwareNotes(
    Map<String, String> row, {
    String? existingNotes,
  }) {
    final parts = <String>[];
    final sn = row['serial']?.trim() ?? '';
    if (sn.isNotEmpty) parts.add('SN: $sn');

    final cpu = row['cpu']?.trim() ?? '';
    final cores = row['cpu_cores']?.trim() ?? '';
    final threads = row['cpu_threads']?.trim() ?? '';
    if (cpu.isNotEmpty) {
      var cpuClean = cpu
          .replaceAll('Intel(R) Core(TM) ', '')
          .replaceAll('CPU @ ', '@ ');
      if (cores.isNotEmpty) {
        cpuClean += threads.isNotEmpty
            ? ' ($cores C / $threads T)'
            : ' ($cores C)';
      }
      parts.add('CPU: $cpuClean');
    }

    final ramMod = row['ram_modules']?.trim() ?? '';
    final ramGb = row['ram_gb']?.trim() ?? '';
    if (ramMod.isNotEmpty) {
      parts.add('RAM: $ramMod');
    } else if (ramGb.isNotEmpty) {
      parts.add('RAM: ${ramGb}GB');
    }

    final storage = row['storage']?.trim() ?? '';
    if (storage.isNotEmpty) parts.add('Storage: $storage');

    final gpu = row['gpu']?.trim() ?? '';
    if (gpu.isNotEmpty) parts.add('GPU: $gpu');

    final bios = row['bios']?.trim() ?? '';
    if (bios.isNotEmpty) parts.add('BIOS: $bios');

    final email = row['email']?.trim() ?? '';
    if (email.isNotEmpty) parts.add('Email: $email');

    final hardwareSummary = parts.join(' | ');
    final explicitNotes = row['notes']?.trim() ?? '';
    final baseNotes = explicitNotes.isNotEmpty
        ? explicitNotes
        : (existingNotes?.trim() ?? '');

    if (parts.isEmpty) {
      return baseNotes;
    }

    if (baseNotes.isEmpty) {
      return hardwareSummary;
    }

    // Split baseNotes by '|' into clean chunks to detect duplicate parts or keys
    final existingChunks = baseNotes
        .split('|')
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toList();

    final newParts = <String>[];
    for (final part in parts) {
      final keyPrefix = part.contains(':')
          ? part.split(':').first.trim().toLowerCase()
          : '';
      final alreadyPresent = existingChunks.any((chunk) {
        if (chunk.toLowerCase() == part.toLowerCase()) return true;
        if (keyPrefix.isNotEmpty) {
          final chunkPrefix = chunk.contains(':')
              ? chunk.split(':').first.trim().toLowerCase()
              : '';
          if (chunkPrefix == keyPrefix) return true;
        }
        return false;
      });
      if (!alreadyPresent) {
        newParts.add(part);
      }
    }

    if (newParts.isEmpty) {
      return baseNotes;
    }

    return '$baseNotes | ${newParts.join(' | ')}';
  }

  static String _composeOsString(
    Map<String, String> row, {
    String? existingOs,
  }) {
    final os = row['os']?.trim() ?? '';
    final osArch = row['os_arch']?.trim() ?? '';
    final osVer = row['os_version']?.trim() ?? '';
    if (os.isEmpty && osVer.isEmpty) return existingOs ?? '';

    final primaryOs = os.isNotEmpty ? os : osVer;
    final segments = <String>[primaryOs];
    if (osArch.isNotEmpty && !primaryOs.toLowerCase().contains(osArch.toLowerCase())) {
      segments.add(osArch);
    }
    if (os.isNotEmpty && osVer.isNotEmpty && !os.contains(osVer)) {
      segments.add('($osVer)');
    }
    return segments.join(' ');
  }

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
    final headerMap = _buildHeaderMap(headerRow);

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
        'factory': getCol('factory'),
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
        'email': getCol('email'),
        'serial': getCol('serial'),
        'cpu': getCol('cpu'),
        'cpu_cores': getCol('cpu_cores'),
        'cpu_threads': getCol('cpu_threads'),
        'ram_gb': getCol('ram_gb'),
        'ram_modules': getCol('ram_modules'),
        'storage': getCol('storage'),
        'gpu': getCol('gpu'),
        'os_version': getCol('os_version'),
        'os_arch': getCol('os_arch'),
        'bios': getCol('bios'),
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

      final headerRow = sheet.rows.first
          .map((c) => c?.value?.toString().trim() ?? '')
          .toList();
      final headerMap = _buildHeaderMap(headerRow);

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
          'factory': getCol('factory'),
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
          'email': getCol('email'),
          'serial': getCol('serial'),
          'cpu': getCol('cpu'),
          'cpu_cores': getCol('cpu_cores'),
          'cpu_threads': getCol('cpu_threads'),
          'ram_gb': getCol('ram_gb'),
          'ram_modules': getCol('ram_modules'),
          'storage': getCol('storage'),
          'gpu': getCol('gpu'),
          'os_version': getCol('os_version'),
          'os_arch': getCol('os_arch'),
          'bios': getCol('bios'),
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
    // Check if first row is header
    int startIdx = 0;
    final firstCells = lines.first.split('\t').map((c) => c.trim()).toList();
    bool hasHeader = firstCells.any((c) {
      final key = _resolveHeaderKey(c);
      return key == 'ip' || key == 'name' || key == 'owner' || key == 'type';
    });
    final headerMap = hasHeader ? _buildHeaderMap(firstCells) : <String, int>{};

    if (hasHeader) {
      startIdx = 1;
    }

    for (int i = startIdx; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final cells = lines[i].split('\t');

      String getByIndexOrHeader(String key, int defaultIndex) {
        if (hasHeader) {
          final idx = headerMap[key];
          if (idx != null && idx < cells.length) return cells[idx].trim();
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
        'factory': getByIndexOrHeader('factory', 98),
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
        'email': getByIndexOrHeader('email', 90),
        'serial': getByIndexOrHeader('serial', 91),
        'cpu': getByIndexOrHeader('cpu', 92),
        'cpu_cores': getByIndexOrHeader('cpu_cores', 93),
        'cpu_threads': getByIndexOrHeader('cpu_threads', 94),
        'ram_gb': getByIndexOrHeader('ram_gb', 95),
        'ram_modules': getByIndexOrHeader('ram_modules', 96),
        'storage': getByIndexOrHeader('storage', 97),
        'gpu': getByIndexOrHeader('gpu', 89),
        'os_version': getByIndexOrHeader('os_version', 88),
        'os_arch': getByIndexOrHeader('os_arch', 87),
        'bios': getByIndexOrHeader('bios', 86),
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

    // Existing factory indexes: IP -> DeviceEntity, ID -> DeviceEntity, Name -> DeviceEntity, Hostname -> DeviceEntity
    final existingIpMap = <String, DeviceEntity>{};
    final existingIdMap = <int, DeviceEntity>{};
    final existingNameMap = <String, DeviceEntity>{};
    final existingHostnameMap = <String, DeviceEntity>{};
    for (final d in existingFactoryDevices) {
      final canon = Ipv4Utils.canonicalizeIpv4(d.ip);
      if (canon != null) existingIpMap[canon] = d;
      existingIdMap[d.id] = d;
      if (d.name.trim().isNotEmpty) {
        existingNameMap[d.name.trim().toLowerCase()] = d;
      }
      if (d.hostname != null && d.hostname!.trim().isNotEmpty) {
        existingHostnameMap[d.hostname!.trim().toLowerCase()] = d;
      }
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

      // Check if updating existing device in this factory
      final rawHostname = r['hostname']?.trim() ?? '';
      DeviceEntity? match;
      if (rawId != null && existingIdMap.containsKey(rawId)) {
        match = existingIdMap[rawId];
      } else if (existingIpMap.containsKey(canonicalIp)) {
        match = existingIpMap[canonicalIp];
      } else if (existingNameMap.containsKey(rawName.toLowerCase())) {
        match = existingNameMap[rawName.toLowerCase()];
      } else if (rawHostname.isNotEmpty &&
          existingHostnameMap.containsKey(rawHostname.toLowerCase())) {
        match = existingHostnameMap[rawHostname.toLowerCase()];
      }

      final cleanOwner = _cleanOwnerName(rawOwner);
      final effectiveOwner = cleanOwner.isNotEmpty
          ? cleanOwner
          : (match?.ownerName ?? '');

      if (effectiveOwner.isEmpty) {
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

      final rawEmail = r['email']?.trim() ?? '';
      final effectiveDept = _inferDepartment(
        rawDept: rawDept,
        name: rawName,
        owner: effectiveOwner,
        email: rawEmail,
        existingDept: match?.department,
      );

      if (effectiveDept.isEmpty) {
        invalidCount++;
        results.add(
          ExcelImportRowResult(
            rowIndex: rIndex,
            rawName: rawName,
            rawIp: rawIp,
            rawOwner: effectiveOwner,
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
            rawOwner: effectiveOwner,
            rawDepartment: effectiveDept,
            action: 'invalid',
            rejectionReason:
                'Duplicate IP $canonicalIp occurs multiple times in imported spreadsheet.',
          ),
        );
        continue;
      }

      final parsedMonitored = _parseNullableBool(r['monitored']);
      final parsedEnabled = _parseNullableBool(r['enabled']);

      final rawTypeStr = r['type']?.trim();
      final type = (rawTypeStr != null && rawTypeStr.isNotEmpty)
          ? DeviceType.fromString(rawTypeStr)
          : (match?.type ?? DeviceType.pc);

      final hardwareNotes = _composeHardwareNotes(
        r,
        existingNotes: match?.notes,
      );
      final osString = _composeOsString(
        r,
        existingOs: match?.operatingSystem,
      );

      if (match != null) {
        // Update row: unspecified/blank booleans preserve existing DB state
        final isMonitored = parsedMonitored ?? match.isMonitored;
        final isEnabled = parsedEnabled ?? match.isEnabled;

        final updated = match.copyWith(
          factoryId: targetFactoryId,
          name: rawName.isNotEmpty ? rawName : match.name,
          type: type,
          ip: canonicalIp,
          ownerName: effectiveOwner,
          department: effectiveDept,
          officeLocation: r['office']?.isNotEmpty == true
              ? r['office']
              : match.officeLocation,
          mac: r['mac']?.isNotEmpty == true ? r['mac'] : match.mac,
          hostname: r['hostname']?.isNotEmpty == true
              ? r['hostname']
              : (match.hostname ?? (rawName.isNotEmpty ? rawName : null)),
          vendor: r['vendor']?.isNotEmpty == true ? r['vendor'] : match.vendor,
          model: r['model']?.isNotEmpty == true ? r['model'] : match.model,
          operatingSystem: osString.isNotEmpty
              ? osString
              : match.operatingSystem,
          parentSwitchName: r['switch']?.isNotEmpty == true
              ? r['switch']
              : match.parentSwitchName,
          notes: hardwareNotes.isNotEmpty ? hardwareNotes : match.notes,
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
            rawOwner: effectiveOwner,
            rawDepartment: effectiveDept,
            action: 'update',
          ),
        );
      } else {
        // Insert row: unspecified booleans default to true; explicit false respected
        final isMonitored = parsedMonitored ?? true;
        final isEnabled = parsedEnabled ?? true;

        final newDev = DeviceEntity(
          id: 0, // Assigned by DB
          factoryId: targetFactoryId,
          name: rawName,
          type: type,
          ip: canonicalIp,
          ownerName: effectiveOwner,
          department: effectiveDept,
          officeLocation: r['office']?.isEmpty == true ? null : r['office'],
          mac: r['mac']?.isEmpty == true ? null : r['mac'],
          hostname: r['hostname']?.isEmpty == true ? rawName : r['hostname'],
          vendor: r['vendor']?.isEmpty == true ? null : r['vendor'],
          model: r['model']?.isEmpty == true ? null : r['model'],
          operatingSystem: osString.isEmpty ? null : osString,
          parentSwitchName: r['switch']?.isEmpty == true ? null : r['switch'],
          notes: hardwareNotes.isEmpty ? null : hardwareNotes,
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
            rawOwner: effectiveOwner,
            rawDepartment: effectiveDept,
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
