import '../../../../core/utils/result.dart';
import '../entities/report_entity.dart';

abstract class ReportRepository {
  Future<Result<ReportSummaryEntity>> generateReport(
    ReportPeriod period, {
    String? factoryId,
  });
  Future<Result<String>> exportReportToCsv(
    ReportSummaryEntity report, [
    String? outputDirectoryPath,
    String? factoryId,
  ]);
  Future<Result<int>> purgeCheckResultsOlderThanDays(int days);
}
