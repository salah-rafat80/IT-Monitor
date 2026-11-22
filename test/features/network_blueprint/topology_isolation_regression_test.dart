import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:it_network_monitor/core/router/app_router.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/device_status_entity.dart';
import 'package:it_network_monitor/features/topology/domain/entities/enterprise_topology_models.dart';
import 'package:it_network_monitor/features/topology/presentation/widgets/enterprise_topology_canvas.dart';

void main() {
  group('Topology Isolation & Dual Route Protection', () {
    test('both /topology and /network-blueprint exist as independent routes in AppRouter', () {
      final router = AppRouter.router;
      final shellRoute = router.configuration.routes.whereType<ShellRoute>().first;

      final paths = shellRoute.routes.whereType<GoRoute>().map((r) => r.path).toList();

      expect(paths, contains('/topology'), reason: 'Original /topology route MUST be preserved');
      expect(paths, contains('/network-blueprint'), reason: 'New /network-blueprint route MUST exist');

      // Verify ordering: Network Blueprint immediately follows Topology
      final topologyIdx = paths.indexOf('/topology');
      final blueprintIdx = paths.indexOf('/network-blueprint');
      expect(blueprintIdx, equals(topologyIdx + 1),
          reason: 'Network Blueprint must immediately follow Topology in route sequence');
    });

    test('Phase 1.2 Topology Link Color resolver rules are completely preserved', () {
      const switchNode = EnterpriseTopologyNode(
        id: 'sw_0',
        title: 'Switch 0',
        level: 1,
        category: TopologyDeviceCategory.switchDevice,
        status: DeviceStatusEnum.up,
        position: Offset(100, 100),
      );

      const upDevice = EnterpriseTopologyNode(
        id: 'dev_up',
        title: 'Workstation Up',
        level: 2,
        category: TopologyDeviceCategory.pc,
        status: DeviceStatusEnum.up,
        position: Offset(200, 100),
      );

      const downDevice = EnterpriseTopologyNode(
        id: 'dev_down',
        title: 'Workstation Down',
        level: 2,
        category: TopologyDeviceCategory.pc,
        status: DeviceStatusEnum.down,
        position: Offset(300, 100),
      );

      // Rule 1: Inferred links are always gray (#64748B)
      const inferredLink = EnterpriseTopologyLink(
        id: 'link_inferred',
        fromNodeId: 'sw_0',
        toNodeId: 'dev_down',
        isInferred: true,
        status: DeviceStatusEnum.down,
      );
      final grayColor = EnterpriseLinksPainter.resolveLinkColor(
        fromNode: switchNode,
        toNode: downDevice,
        link: inferredLink,
      );
      expect(grayColor, equals(const Color(0xFF64748B)));

      // Rule 2: Verified physical link with DOWN endpoint is RED (#EF4444)
      const downPhysicalLink = EnterpriseTopologyLink(
        id: 'link_phys_down',
        fromNodeId: 'sw_0',
        toNodeId: 'dev_down',
        isInferred: false,
        status: DeviceStatusEnum.down,
      );
      final redColor = EnterpriseLinksPainter.resolveLinkColor(
        fromNode: switchNode,
        toNode: downDevice,
        link: downPhysicalLink,
      );
      expect(redColor, equals(const Color(0xFFEF4444)));

      // Rule 3: Verified physical link where both endpoints and link are UP is GREEN (#10B981)
      const greenPhysicalLink = EnterpriseTopologyLink(
        id: 'link_phys_green',
        fromNodeId: 'sw_0',
        toNodeId: 'dev_up',
        isInferred: false,
        status: DeviceStatusEnum.up,
      );
      final greenColor = EnterpriseLinksPainter.resolveLinkColor(
        fromNode: switchNode,
        toNode: upDevice,
        link: greenPhysicalLink,
      );
      expect(greenColor, equals(const Color(0xFF10B981)));
    });
  });
}
