class PartyModel {
  const PartyModel({
    required this.id,
    required this.title,
    required this.gameName,
    required this.requiredRank,
    required this.playStyle,
    required this.playTime,
    required this.maxPlayers,
    required this.currentPlayers,
    required this.createdBy,
    required this.createdAt,
    this.isActive = true,
  });

  final String id,
      title,
      gameName,
      requiredRank,
      playStyle,
      playTime,
      createdBy;
  final int maxPlayers, currentPlayers;
  final DateTime createdAt;
  final bool isActive;

  Map<String, dynamic> toMap() => {
    'title': title,
    'gameName': gameName,
    'requiredRank': requiredRank,
    'playStyle': playStyle,
    'playTime': playTime,
    'maxPlayers': maxPlayers,
    'currentPlayers': currentPlayers,
    'createdBy': createdBy,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'isActive': isActive,
  };

  factory PartyModel.fromMap(String id, Map<String, dynamic> map) => PartyModel(
    id: id,
    title: map['title'] as String? ?? '',
    gameName: map['gameName'] as String? ?? '',
    requiredRank: map['requiredRank'] as String? ?? 'ทุกแรงค์',
    playStyle: map['playStyle'] as String? ?? 'เล่นชิล ๆ',
    playTime: map['playTime'] as String? ?? 'คืนนี้',
    maxPlayers: (map['maxPlayers'] as num?)?.toInt() ?? 5,
    currentPlayers: (map['currentPlayers'] as num?)?.toInt() ?? 1,
    createdBy: map['createdBy'] as String? ?? 'Player',
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      (map['createdAt'] as num?)?.toInt() ?? 0,
    ),
    isActive: map['isActive'] as bool? ?? true,
  );
}
