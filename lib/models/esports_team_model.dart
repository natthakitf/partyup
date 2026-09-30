import 'package:cloud_firestore/cloud_firestore.dart';

class EsportsTeamModel {
  const EsportsTeamModel({
    required this.id,
    required this.title,
    required this.gameName,
    required this.requiredRank,
    required this.role,
    required this.playStyle,
    required this.practiceTime,
    required this.maxPlayers,
    required this.currentPlayers,
    required this.createdBy,
    required this.createdAt,
    this.isActive = true,
  });

  final String id, title, gameName, requiredRank, role, playStyle;
  final String practiceTime, createdBy;
  final int maxPlayers, currentPlayers;
  final DateTime createdAt;
  final bool isActive;

  Map<String, dynamic> toMap() => {
    'title': title,
    'gameName': gameName,
    'requiredRank': requiredRank,
    'role': role,
    'playStyle': playStyle,
    'practiceTime': practiceTime,
    'maxPlayers': maxPlayers,
    'currentPlayers': currentPlayers,
    'createdBy': createdBy,
    'createdAt': Timestamp.fromDate(createdAt),
    'isActive': isActive,
  };

  factory EsportsTeamModel.fromMap(String id, Map<String, dynamic> data) =>
      EsportsTeamModel(
        id: id,
        title: data['title']?.toString() ?? '',
        gameName: data['gameName']?.toString() ?? '',
        requiredRank: data['requiredRank']?.toString() ?? 'ทุกแรงค์',
        role: data['role']?.toString() ?? 'ไม่ระบุตำแหน่ง',
        playStyle: data['playStyle']?.toString() ?? '',
        practiceTime: data['practiceTime']?.toString() ?? '',
        maxPlayers: (data['maxPlayers'] as num?)?.toInt() ?? 5,
        currentPlayers: (data['currentPlayers'] as num?)?.toInt() ?? 1,
        createdBy: data['createdBy']?.toString() ?? 'ทีม eSports',
        createdAt: switch (data['createdAt']) {
          Timestamp value => value.toDate(),
          int value => DateTime.fromMillisecondsSinceEpoch(value),
          _ => DateTime.now(),
        },
        isActive: data['isActive'] as bool? ?? true,
      );
}
