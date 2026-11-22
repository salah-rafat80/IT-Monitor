import '../../../../core/utils/result.dart';
import '../entities/blueprint_page_entity.dart';

abstract class NetworkBlueprintRepository {
  /// Loads all floor blueprint pages from the Draw.io source file.
  Future<Result<List<BlueprintPageEntity>>> loadBlueprintPages();

  /// Reloads with refreshed device monitoring statuses.
  Future<Result<List<BlueprintPageEntity>>> refreshMonitoringStatuses();
}
