// domain/entities/group_update_result.dart
import 'package:equatable/equatable.dart';

class GroupUpdateResult extends Equatable {
  final int id;
  final String? name;
  final String? avatar;
  final String type;

  const GroupUpdateResult({
    required this.id,
    this.name,
    this.avatar,
    required this.type,
  });

  @override
  List<Object?> get props => [id, name, avatar, type];
}