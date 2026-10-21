import 'package:equatable/equatable.dart';

class LocationEntity extends Equatable {
  final int id;
  final String name;
  final String? description;

  const LocationEntity({
    required this.id,
    required this.name,
    this.description,
  });

  @override
  List<Object?> get props => [id, name, description];
}
