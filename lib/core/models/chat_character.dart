class ChatCharacter {
  final String id;
  String name;
  String systemPrompt;
  DateTime createdAt;
  DateTime lastActiveAt;

  ChatCharacter({
    required this.id,
    required this.name,
    this.systemPrompt = '',
    DateTime? createdAt,
    DateTime? lastActiveAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        lastActiveAt = lastActiveAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'systemPrompt': systemPrompt,
    'createdAt': createdAt.toIso8601String(),
    'lastActiveAt': lastActiveAt.toIso8601String(),
  };

  factory ChatCharacter.fromJson(Map<String, dynamic> json) => ChatCharacter(
    id: json['id'] as String,
    name: json['name'] as String,
    systemPrompt: json['systemPrompt'] as String? ?? '',
    createdAt: DateTime.parse(json['createdAt'] as String),
    lastActiveAt: DateTime.parse(json['lastActiveAt'] as String),
  );
}
