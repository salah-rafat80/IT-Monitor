import 'package:equatable/equatable.dart';

class FactoryEntity extends Equatable {
  final String id; // Stable unique identifier, e.g. 'bnf', 'rnf', 'unassigned'
  final String code; // Unique factory code, e.g. 'BNF', 'RNF'
  final String name; // Display name, e.g. 'BNF Factory', 'RNF Factory'
  final bool isActive; // Active/inactive state
  final String? gatewayIp; // Gateway IPv4 (e.g. '192.168.22.1')
  final String? subnetMask; // Subnet mask (e.g. '255.255.255.0')
  final String? expectedCidr; // Network CIDR (e.g. '192.168.22.0/24')
  final DateTime createdAt;
  final DateTime? updatedAt;

  const FactoryEntity({
    required this.id,
    required this.code,
    required this.name,
    this.isActive = true,
    this.gatewayIp,
    this.subnetMask,
    this.expectedCidr,
    required this.createdAt,
    this.updatedAt,
  });

  /// Deterministic ID generator from factory code
  static String generateId(String code) {
    return code.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');
  }

  FactoryEntity copyWith({
    String? id,
    String? code,
    String? name,
    bool? isActive,
    String? gatewayIp,
    String? subnetMask,
    String? expectedCidr,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FactoryEntity(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      gatewayIp: gatewayIp ?? this.gatewayIp,
      subnetMask: subnetMask ?? this.subnetMask,
      expectedCidr: expectedCidr ?? this.expectedCidr,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'name': name,
    'isActive': isActive,
    'gatewayIp': gatewayIp,
    'subnetMask': subnetMask,
    'expectedCidr': expectedCidr,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  factory FactoryEntity.fromJson(Map<String, dynamic> json) {
    final code = json['code'] as String? ?? 'UNASSIGNED';
    final id = json['id'] as String? ?? generateId(code);
    return FactoryEntity(
      id: id,
      code: code,
      name: json['name'] as String? ?? code,
      isActive: json['isActive'] as bool? ?? true,
      gatewayIp: json['gatewayIp'] as String? ?? json['gateway_ip'] as String?,
      subnetMask:
          json['subnetMask'] as String? ?? json['subnet_mask'] as String?,
      expectedCidr:
          json['expectedCidr'] as String? ?? json['expected_cidr'] as String?,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    );
  }

  @override
  List<Object?> get props => [
    id,
    code,
    name,
    isActive,
    gatewayIp,
    subnetMask,
    expectedCidr,
    createdAt,
    updatedAt,
  ];
}
