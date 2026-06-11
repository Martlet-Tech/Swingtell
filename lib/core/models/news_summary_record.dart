import 'package:uuid/uuid.dart';

class NewsSummaryRecord {
  final String id;
  final String topicId;
  final String topicName;
  final String timeRange;
  final DateTime createdAt;
  final String htmlContent;
  final String plainText;
  final String? tokenInfo;

  NewsSummaryRecord({
    String? id,
    required this.topicId,
    required this.topicName,
    required this.timeRange,
    DateTime? createdAt,
    required this.htmlContent,
    required this.plainText,
    this.tokenInfo,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'topicId': topicId,
        'topicName': topicName,
        'timeRange': timeRange,
        'createdAt': createdAt.toIso8601String(),
        'htmlContent': htmlContent,
        'plainText': plainText,
        'tokenInfo': tokenInfo,
      };

  factory NewsSummaryRecord.fromJson(Map<String, dynamic> json) =>
      NewsSummaryRecord(
        id: json['id'] as String,
        topicId: json['topicId'] as String,
        topicName: json['topicName'] as String,
        timeRange: json['timeRange'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        htmlContent: json['htmlContent'] as String,
        plainText: json['plainText'] as String,
        tokenInfo: json['tokenInfo'] as String?,
      );
}
