import 'package:freezed_annotation/freezed_annotation.dart';

part 'reaction_model.freezed.dart';
part 'reaction_model.g.dart';

@freezed
class ReactionModel with _$ReactionModel {
  const ReactionModel._();

  const factory ReactionModel({
    @JsonKey(name: 'message_id') required String messageId,
    @JsonKey(name: 'user_id') required String userId,
    required String emoji,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _ReactionModel;

  factory ReactionModel.fromJson(Map<String, dynamic> json) =>
      _$ReactionModelFromJson(json);

  Map<String, Object?> toDb() => <String, Object?>{
        'message_id': messageId,
        'user_id': userId,
        'emoji': emoji,
        'created_at': createdAt?.millisecondsSinceEpoch,
      };

  factory ReactionModel.fromDb(Map<String, Object?> row) => ReactionModel(
        messageId: row['message_id']! as String,
        userId: row['user_id']! as String,
        emoji: row['emoji']! as String,
        createdAt: row['created_at'] is int
            ? DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int)
            : null,
      );
}
