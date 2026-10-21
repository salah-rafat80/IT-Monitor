import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:it_network_monitor/features/devices/domain/entities/device_entity.dart';
import 'package:it_network_monitor/features/infrastructure/domain/entities/unifi_device_entity.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/device_status_entity.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/monitored_device.dart';
import 'package:it_network_monitor/features/topology/domain/services/enterprise_topology_builder.dart';
import 'package:it_network_monitor/features/topology/presentation/widgets/enterprise_topology_canvas.dart';
import 'package:it_network_monitor/features/topology/presentation/widgets/enterprise_topology_summary_bar.dart';

void main() {
  testWidgets('Render and capture enterprise topology screenshot at 1080p', (
    tester,
  ) async {
    const builder = EnterpriseTopologyBuilder();

    final realAps = [
      UniFiDeviceEntity(
        id: 1,
        name: 'Packing Area AP',
        ip: '192.168.7.6',
        role: UniFiDeviceRole.accessPoint,
        location: 'Factory Administration Upper Area',
        isCriticalInfrastructure: true,
        requiresAdminConfirmation: false,
        linkedSubnets: const ['192.168.7.0/24'],
        siteName: 'Factory Administration Upper Area',
        isEnabled: true,
        isReadOnly: false,
        createdAt: DateTime(2026),
      ),
      UniFiDeviceEntity(
        id: 2,
        name: 'Meeting Room AP',
        ip: '192.168.7.4',
        role: UniFiDeviceRole.accessPoint,
        location: 'Factory Administration Upper Area',
        isCriticalInfrastructure: true,
        requiresAdminConfirmation: false,
        linkedSubnets: const ['192.168.7.0/24'],
        siteName: 'Factory Administration Upper Area',
        isEnabled: true,
        isReadOnly: false,
        createdAt: DateTime(2026),
      ),
      UniFiDeviceEntity(
        id: 3,
        name: 'FM Office AP',
        ip: '192.168.7.2',
        role: UniFiDeviceRole.accessPoint,
        location: 'Factory Administration Upper Area',
        isCriticalInfrastructure: true,
        requiresAdminConfirmation: false,
        linkedSubnets: const ['192.168.7.0/24'],
        siteName: 'Factory Administration Upper Area',
        isEnabled: true,
        isReadOnly: false,
        createdAt: DateTime(2026),
      ),
      UniFiDeviceEntity(
        id: 4,
        name: 'IoT_Palitizer AP',
        ip: '192.168.8.5',
        role: UniFiDeviceRole.accessPoint,
        location: 'Lower Area',
        isCriticalInfrastructure: true,
        requiresAdminConfirmation: false,
        linkedSubnets: const ['192.168.8.0/24'],
        siteName: 'Lower Area',
        isEnabled: true,
        isReadOnly: false,
        createdAt: DateTime(2026),
      ),
    ];

    final realEndpoints = [
      // Main Office (Multi-column branch demonstration)
      for (int i = 1; i <= 8; i++)
        MonitoredDevice(
          device: DeviceEntity(
            id: 10 + i,
            name: i % 2 == 0 ? 'Laptop-Main-$i' : 'PC-Main-$i',
            type: i % 2 == 0 ? DeviceType.laptop : DeviceType.pc,
            ip: '192.168.27.${20 + i}',
            ownerName: 'Staff $i',
            department: 'Main Office',
            officeLocation: 'Main Office',
            createdAt: DateTime(2026),
          ),
          status: DeviceStatusEntity(
            deviceId: 10 + i,
            status: DeviceStatusEnum.up,
            statusChangedAt: DateTime(2026),
            lastLatencyMs: 1 + (i % 3),
          ),
        ),
      // Warehouse
      for (int i = 1; i <= 4; i++)
        MonitoredDevice(
          device: DeviceEntity(
            id: 30 + i,
            name: 'WHS-Station-0$i',
            type: DeviceType.pc,
            ip: '192.168.22.${10 + i}',
            ownerName: 'Warehouse Staff $i',
            department: 'Warehouse',
            officeLocation: 'Warehouse',
            createdAt: DateTime(2026),
          ),
          status: DeviceStatusEntity(
            deviceId: 30 + i,
            status: DeviceStatusEnum.up,
            statusChangedAt: DateTime(2026),
            lastLatencyMs: 2 + i,
          ),
        ),
      // Production Floor
      MonitoredDevice(
        device: DeviceEntity(
          id: 51,
          name: 'Prod-PLC-01',
          type: DeviceType.pc,
          ip: '192.168.27.71',
          ownerName: 'Operator A',
          department: 'Production Floor',
          officeLocation: 'Production Floor',
          createdAt: DateTime(2026),
        ),
        status: DeviceStatusEntity(
          deviceId: 51,
          status: DeviceStatusEnum.up,
          statusChangedAt: DateTime(2026),
          lastLatencyMs: 1,
        ),
      ),
      MonitoredDevice(
        device: DeviceEntity(
          id: 52,
          name: 'Prod-PLC-02',
          type: DeviceType.pc,
          ip: '192.168.27.72',
          ownerName: 'Operator B',
          department: 'Production Floor',
          officeLocation: 'Production Floor',
          createdAt: DateTime(2026),
        ),
        status: DeviceStatusEntity(
          deviceId: 52,
          status: DeviceStatusEnum.up,
          statusChangedAt: DateTime(2026),
          lastLatencyMs: 1,
        ),
      ),
      // Quality Office
      MonitoredDevice(
        device: DeviceEntity(
          id: 61,
          name: 'QA-Tester-01',
          type: DeviceType.laptop,
          ip: '192.168.22.85',
          ownerName: 'QA Lead',
          department: 'Quality Office',
          officeLocation: 'Quality Office',
          createdAt: DateTime(2026),
        ),
        status: DeviceStatusEntity(
          deviceId: 61,
          status: DeviceStatusEnum.up,
          statusChangedAt: DateTime(2026),
          lastLatencyMs: 3,
        ),
      ),
    ];

    final graph = builder.build(
      monitoredDevices: realEndpoints,
      infraDevices: realAps,
    );

    final repaintBoundaryKey = GlobalKey();

    await tester.binding.setSurfaceSize(const Size(1920, 1080));

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        home: Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          body: RepaintBoundary(
            key: repaintBoundaryKey,
            child: Container(
              color: const Color(0xFF0F172A),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  EnterpriseTopologySummaryBar(
                    stats: graph.categoryStats,
                    searchQuery: '',
                    onSearchChanged: (_) {},
                    onClearSearch: () {},
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    color: const Color(0xFF1E293B),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.account_tree_rounded,
                          size: 18,
                          color: Color(0xFF38BDF8),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Network Infrastructure Topology — Compact Layout Diagram',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFF8FAFC),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: EnterpriseTopologyCanvas(
                      graph: graph,
                      searchQuery: '',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(repaintBoundaryKey),
      matchesGoldenFile('goldens/topology_layout_desktop.png'),
    );
  });
}
