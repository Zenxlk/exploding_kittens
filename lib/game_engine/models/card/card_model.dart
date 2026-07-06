import 'package:equatable/equatable.dart';
import 'card_type.dart';

class CardModel extends Equatable {
  const CardModel({
    required this.id,
    required this.type,
  });

  final String id;
  final CardType type;

  @override
  List<Object?> get props => [id, type];

  @override
  String toString() => 'Card($type, $id)';
}
