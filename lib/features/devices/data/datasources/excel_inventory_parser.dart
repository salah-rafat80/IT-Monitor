import 'dart:convert';
import 'package:excel/excel.dart';
import '../../domain/services/inventory_validator.dart';

class ExcelInventoryParser {
  static List<RawInventoryRow> parseFile(List<int> bytes, String filename) {
    if (filename.toLowerCase().endsWith('.csv')) {
      return _parseCsv(bytes);
    } else {
      return _parseExcel(bytes);
    }
  }

  static List<RawInventoryRow> _parseExcel(List<int> bytes) {
    final excel = Excel.decodeBytes(bytes);
    final rows = <RawInventoryRow>[];

    for (final table in excel.tables.keys) {
      final sheet = excel.tables[table];
      if (sheet == null || sheet.maxRows <= 1) continue;

      // Header detection (Row 0)
      final headerRow = sheet.rows.first;
      final headerMap = <String, int>{};
      for (int c = 0; c < headerRow.length; c++) {
        final cellVal =
            headerRow[c]?.value?.toString().toLowerCase().trim() ?? '';
        if (cellVal.contains('owner') ||
            cellVal.contains('user') ||
            cellVal.contains('employee') ||
            cellVal.contains('person') ||
            cellVal.contains('assigned')) {
          headerMap['owner'] = c;
        } else if (cellVal.contains('dept') || cellVal.contains('department')) {
          headerMap['department'] = c;
        } else if (cellVal.contains('device') ||
            cellVal.contains('name') ||
            cellVal.contains('host')) {
          headerMap['name'] = c;
        } else if (cellVal.contains('ip')) {
          headerMap['ip'] = c;
        } else if (cellVal.contains('office') ||
            cellVal.contains('location') ||
            cellVal.contains('site')) {
          headerMap['office'] = c;
        } else if (cellVal.contains('switch')) {
          headerMap['switch'] = c;
        } else if (cellVal.contains('type')) {
          headerMap['type'] = c;
        } else if (cellVal.contains('vendor')) {
          headerMap['vendor'] = c;
        } else if (cellVal.contains('model')) {
          headerMap['model'] = c;
        }
      }

      for (int r = 1; r < sheet.rows.length; r++) {
        final row = sheet.rows[r];
        if (row.isEmpty) continue;

        String getVal(String key) {
          final idx = headerMap[key];
          if (idx == null || idx >= row.length) return '';
          return row[idx]?.value?.toString().trim() ?? '';
        }

        final ip = getVal('ip');
        final owner = getVal('owner');
        final dept = getVal('department');
        final name = getVal('name');

        // Skip completely empty rows
        if (ip.isEmpty && owner.isEmpty && dept.isEmpty && name.isEmpty) {
          continue;
        }

        rows.add(
          RawInventoryRow(
            rowIndex: r + 1,
            rawName: name,
            rawType: getVal('type'),
            rawIp: ip,
            rawOwner: owner,
            rawDepartment: dept,
            rawOffice: getVal('office'),
            rawSwitchName: getVal('switch'),
            rawVendor: getVal('vendor'),
            rawModel: getVal('model'),
          ),
        );
      }
    }

    return rows;
  }

  static List<RawInventoryRow> _parseCsv(List<int> bytes) {
    final content = utf8.decode(bytes);
    final lines = const LineSplitter().convert(content);
    final rows = <RawInventoryRow>[];

    if (lines.length <= 1) return rows;

    final headerCols = lines.first
        .split(',')
        .map((e) => e.toLowerCase().trim())
        .toList();
    final headerMap = <String, int>{};

    for (int c = 0; c < headerCols.length; c++) {
      final cellVal = headerCols[c];
      if (cellVal.contains('owner') ||
          cellVal.contains('user') ||
          cellVal.contains('employee') ||
          cellVal.contains('person') ||
          cellVal.contains('assigned')) {
        headerMap['owner'] = c;
      } else if (cellVal.contains('dept') || cellVal.contains('department')) {
        headerMap['department'] = c;
      } else if (cellVal.contains('device') ||
          cellVal.contains('name') ||
          cellVal.contains('host')) {
        headerMap['name'] = c;
      } else if (cellVal.contains('ip')) {
        headerMap['ip'] = c;
      } else if (cellVal.contains('office') || cellVal.contains('location')) {
        headerMap['office'] = c;
      } else if (cellVal.contains('switch')) {
        headerMap['switch'] = c;
      } else if (cellVal.contains('type')) {
        headerMap['type'] = c;
      }
    }

    for (int r = 1; r < lines.length; r++) {
      final line = lines[r].trim();
      if (line.isEmpty) continue;

      final cols = line.split(',').map((e) => e.trim()).toList();

      String getVal(String key) {
        final idx = headerMap[key];
        if (idx == null || idx >= cols.length) return '';
        return cols[idx];
      }

      final ip = getVal('ip');
      final owner = getVal('owner');
      final dept = getVal('department');
      final name = getVal('name');

      if (ip.isEmpty && owner.isEmpty && dept.isEmpty && name.isEmpty) continue;

      rows.add(
        RawInventoryRow(
          rowIndex: r + 1,
          rawName: name,
          rawType: getVal('type'),
          rawIp: ip,
          rawOwner: owner,
          rawDepartment: dept,
          rawOffice: getVal('office'),
          rawSwitchName: getVal('switch'),
        ),
      );
    }

    return rows;
  }
}
