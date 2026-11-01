import 'package:flutter_test/flutter_test.dart';

import 'package:it_network_monitor/core/utils/result.dart';
import 'package:it_network_monitor/features/factories/domain/entities/factory_entity.dart';
import 'package:it_network_monitor/features/factories/domain/repositories/factory_repository.dart';
import 'package:it_network_monitor/features/factories/domain/services/network_detection_service.dart';
import 'package:it_network_monitor/features/factories/presentation/bloc/factory_cubit.dart';
import 'package:it_network_monitor/features/inventory/presentation/pages/unassigned_recovery_page.dart';

class _FakeFactoryRepository implements FactoryRepository {
  final List<FactoryEntity> _factories;

  _FakeFactoryRepository(this._factories);

  @override
  Future<Result<List<FactoryEntity>>> getFactories({
    bool includeInactive = false,
  }) async {
    final list = includeInactive
        ? _factories
        : _factories.where((f) => f.isActive).toList();
    return Result.success(list);
  }

  @override
  Future<Result<FactoryEntity>> getFactoryById(String id) async {
    final match = _factories.where((f) => f.id == id).firstOrNull;
    if (match != null) return Result.success(match);
    return Result.failure(Exception('Factory not found') as dynamic);
  }

  @override
  Future<Result<FactoryEntity?>> getFactoryByCode(String code) async {
    final match = _factories
        .where((f) => f.code.toUpperCase() == code.toUpperCase())
        .firstOrNull;
    return Result.success(match);
  }

  @override
  Stream<List<FactoryEntity>> watchFactories({bool includeInactive = false}) {
    return Stream.value(
      includeInactive
          ? _factories
          : _factories.where((f) => f.isActive).toList(),
    );
  }

  @override
  Future<Result<FactoryEntity>> createFactory(FactoryEntity factory) async =>
      Result.success(factory);

  @override
  Future<Result<FactoryEntity>> updateFactory(FactoryEntity factory) async =>
      Result.success(factory);

  @override
  Future<Result<void>> deleteFactory(String id) async => Result.success(null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FactoryEntity rnfFactory;
  late FactoryEntity bnfFactory;
  late List<FactoryEntity> defaultFactories;

  setUp(() {
    rnfFactory = FactoryEntity(
      id: 'rnf',
      code: 'RNF',
      name: 'RNF Factory',
      isActive: true,
      gatewayIp: '192.168.22.1',
      subnetMask: '255.255.255.0',
      expectedCidr: '192.168.22.0/24',
      createdAt: DateTime.now(),
    );

    bnfFactory = FactoryEntity(
      id: 'bnf',
      code: 'BNF',
      name: 'BNF Factory',
      isActive: true,
      gatewayIp: '192.168.21.1',
      subnetMask: '255.255.255.0',
      expectedCidr: '192.168.21.0/24',
      createdAt: DateTime.now(),
    );

    defaultFactories = [rnfFactory, bnfFactory];
  });

  group('Issue 3: Automatic Network Change Detection in FactoryCubit', () {
    test(
      '3.1: Automatically detects movement from RNF to BNF and updates selected factory',
      () async {
        final fakeRepo = _FakeFactoryRepository(defaultFactories);
        final detectionService = NetworkDetectionServiceImpl();
        final cubit = FactoryCubit(fakeRepo, detectionService);

        // Initial load with RNF IP
        await cubit.loadFactories(mockLocalIps: ['192.168.22.50']);
        expect(cubit.state.selectedFactory?.id, equals('rnf'));
        expect(
          cubit.state.detectionResult?.status,
          equals(FactoryDetectionStatus.detected),
        );

        // Network changes: movement from RNF to BNF LAN
        await cubit.checkNetworkInterfaces(mockLocalIps: ['192.168.21.80']);
        expect(cubit.state.selectedFactory?.id, equals('bnf'));
        expect(
          cubit.state.detectionResult?.status,
          equals(FactoryDetectionStatus.detected),
        );
        expect(cubit.state.detectionResult?.detectedFactory?.id, equals('bnf'));

        await cubit.close();
      },
    );

    test('3.2: Automatically detects movement from BNF to RNF', () async {
      final fakeRepo = _FakeFactoryRepository(defaultFactories);
      final detectionService = NetworkDetectionServiceImpl();
      final cubit = FactoryCubit(fakeRepo, detectionService);

      // Initial load with BNF IP
      await cubit.loadFactories(mockLocalIps: ['192.168.21.100']);
      expect(cubit.state.selectedFactory?.id, equals('bnf'));

      // Movement to RNF
      await cubit.checkNetworkInterfaces(mockLocalIps: ['192.168.22.100']);
      expect(cubit.state.selectedFactory?.id, equals('rnf'));

      await cubit.close();
    });

    test(
      '3.3: Does not silently change to All Factories when network becomes unknown or ambiguous',
      () async {
        final fakeRepo = _FakeFactoryRepository(defaultFactories);
        final detectionService = NetworkDetectionServiceImpl();
        final cubit = FactoryCubit(fakeRepo, detectionService);

        // Start on RNF
        await cubit.loadFactories(mockLocalIps: ['192.168.22.50']);
        expect(cubit.state.selectedFactory?.id, equals('rnf'));

        // Move to unknown external network (e.g. home/coffee shop)
        await cubit.checkNetworkInterfaces(mockLocalIps: ['10.88.99.100']);

        // Selected factory must NOT silently clear to null / All Factories
        expect(
          cubit.state.selectedFactory?.id,
          equals('rnf'),
          reason: 'Must preserve context rather than silently dumping to All',
        );
        expect(
          cubit.state.detectionResult?.status,
          equals(FactoryDetectionStatus.unknown),
        );

        await cubit.close();
      },
    );

    test(
      '3.4: Administrator manual override is strictly preserved until explicitly cleared',
      () async {
        final fakeRepo = _FakeFactoryRepository(defaultFactories);
        final detectionService = NetworkDetectionServiceImpl();
        final cubit = FactoryCubit(fakeRepo, detectionService);

        // Start on RNF
        await cubit.loadFactories(mockLocalIps: ['192.168.22.50']);
        expect(cubit.state.selectedFactory?.id, equals('rnf'));

        // Admin manually overrides and selects BNF
        cubit.selectFactory(bnfFactory, isManual: true);
        expect(cubit.state.selectedFactory?.id, equals('bnf'));
        expect(cubit.state.isManualOverride, isTrue);

        // Physical network remains on RNF or changes
        await cubit.checkNetworkInterfaces(mockLocalIps: ['192.168.22.77']);
        // Selection MUST remain BNF because manual override is in effect
        expect(
          cubit.state.selectedFactory?.id,
          equals('bnf'),
          reason: 'Manual override must be preserved',
        );
        expect(cubit.state.isManualOverride, isTrue);

        // Admin clears manual override
        await cubit.clearManualOverride(mockLocalIps: ['192.168.22.77']);
        expect(cubit.state.isManualOverride, isFalse);
        expect(cubit.state.selectedFactory?.id, equals('rnf'));

        await cubit.close();
      },
    );

    test(
      '3.5: Avoids unnecessary repeated re-scans when interface IPs are identical',
      () async {
        final fakeRepo = _FakeFactoryRepository(defaultFactories);
        final detectionService = NetworkDetectionServiceImpl();
        final cubit = FactoryCubit(fakeRepo, detectionService);

        await cubit.loadFactories(mockLocalIps: ['192.168.22.50']);
        final firstResult = cubit.state.detectionResult;

        // Call checkNetworkInterfaces with exact same IP
        await cubit.checkNetworkInterfaces(mockLocalIps: ['192.168.22.50']);

        // Detection result reference is identical (no re-evaluation was performed)
        expect(identical(cubit.state.detectionResult, firstResult), isTrue);

        await cubit.close();
      },
    );
  });

  group('Issue 6: Unassigned Recovery Ambiguity Handling', () {
    test('6.1: Exactly one matching factory returns single suggestion', () {
      final resultRnf = UnassignedRecoveryPage.suggestFactoryForIp(
        '192.168.22.45',
        defaultFactories,
      );
      expect(resultRnf.isSingle, isTrue);
      expect(resultRnf.matchedFactory?.id, equals('rnf'));

      final resultBnf = UnassignedRecoveryPage.suggestFactoryForIp(
        '192.168.21.99',
        defaultFactories,
      );
      expect(resultBnf.isSingle, isTrue);
      expect(resultBnf.matchedFactory?.id, equals('bnf'));
    });

    test('6.2: No matching factory returns none / No Match', () {
      final resultNone = UnassignedRecoveryPage.suggestFactoryForIp(
        '10.10.10.10',
        defaultFactories,
      );
      expect(resultNone.isNone, isTrue);
      expect(resultNone.matchedFactory, isNull);
      expect(resultNone.matchedCandidates.isEmpty, isTrue);
    });

    test(
      '6.3: Multiple matching factories returns Ambiguous and never picks the first match',
      () {
        final broadFactory = FactoryEntity(
          id: 'corp_broad',
          code: 'CORP',
          name: 'Corporate Supernet',
          isActive: true,
          gatewayIp: '192.168.0.1',
          expectedCidr: '192.168.0.0/16', // Overlaps 192.168.22.0/24!
          createdAt: DateTime.now(),
        );

        final overlappingFactories = [broadFactory, rnfFactory, bnfFactory];

        final ambiguousResult = UnassignedRecoveryPage.suggestFactoryForIp(
          '192.168.22.33',
          overlappingFactories,
        );
        expect(ambiguousResult.isAmbiguous, isTrue);
        expect(
          ambiguousResult.matchedFactory,
          isNull,
          reason: 'Must NEVER pick the first matching factory when ambiguous',
        );
        expect(ambiguousResult.matchedCandidates.length, equals(2));
        expect(
          ambiguousResult.matchedCandidates.map((f) => f.id),
          containsAll(['corp_broad', 'rnf']),
        );
      },
    );

    test('6.4: Invalid or malformed IP returns none safely', () {
      final resultMalformed = UnassignedRecoveryPage.suggestFactoryForIp(
        'not.an.ip.address',
        defaultFactories,
      );
      expect(resultMalformed.isNone, isTrue);
      expect(resultMalformed.matchedFactory, isNull);
    });
  });
}
