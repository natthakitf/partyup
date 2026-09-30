import '../models/esports_team_model.dart';
import '../models/party_model.dart';

/// ข้อมูลตัวอย่างที่ใช้เมื่อเปิดแอปโดยยังไม่ได้เชื่อม Firebase
class DemoData {
  static List<EsportsTeamModel> esportsTeams(DateTime now) => [
    EsportsTeamModel(
      id: 't1',
      title: 'หา Controller เข้าทีมลง Premier',
      gameName: 'VALORANT',
      requiredRank: 'Ascendant+',
      role: 'Controller',
      playStyle: 'ทีมจริงจัง ซ้อมและลงแข่ง',
      practiceTime: 'จ.-พฤ. 20:00',
      maxPlayers: 5,
      currentPlayers: 4,
      createdBy: 'NOVA Esports',
      createdAt: now,
    ),
    EsportsTeamModel(
      id: 't2',
      title: 'ทีม LoL หา Support ประจำทีม',
      gameName: 'League of Legends',
      requiredRank: 'Diamond+',
      role: 'Support',
      playStyle: 'ซ้อมทีมและลงรายการ amateur',
      practiceTime: 'เสาร์-อาทิตย์ 19:00',
      maxPlayers: 5,
      currentPlayers: 4,
      createdBy: 'Lunar Five',
      createdAt: now.subtract(const Duration(minutes: 18)),
    ),
  ];

  static List<PartyModel> parties(DateTime now) => [
    PartyModel(
      id: 'd1',
      title: 'หาคนเติมให้ครบทีม แรงค์ไม่ซี',
      gameName: 'VALORANT',
      requiredRank: 'Gold – Diamond',
      playStyle: 'จริงจังแต่ไม่หัวร้อน',
      playTime: 'คืนนี้ 20:00',
      maxPlayers: 5,
      currentPlayers: 3,
      createdBy: 'mook#TH',
      createdAt: now,
    ),
    PartyModel(
      id: 'd2',
      title: 'ตีแรงค์ชิล ๆ คุยได้ทุกเรื่อง',
      gameName: 'League of Legends',
      requiredRank: 'Platinum+',
      playStyle: 'เน้นทีมเวิร์ก',
      playTime: 'วันนี้ · ตอนนี้',
      maxPlayers: 5,
      currentPlayers: 4,
      createdBy: 'minty',
      createdAt: now.subtract(const Duration(minutes: 12)),
    ),
    PartyModel(
      id: 'd3',
      title: 'ซ้อม aim ก่อนลงแข่ง',
      gameName: 'Overwatch 2',
      requiredRank: 'ทุกแรงค์',
      playStyle: 'ซ้อมจริงจัง',
      playTime: 'พรุ่งนี้ 19:30',
      maxPlayers: 5,
      currentPlayers: 2,
      createdBy: 'nine',
      createdAt: now.subtract(const Duration(minutes: 38)),
    ),
    PartyModel(
      id: 'd4',
      title: 'หาทีมลง ranked สัก 2 เกม',
      gameName: 'Apex Legends',
      requiredRank: 'Gold+',
      playStyle: 'เล่นสนุก ไม่ toxic',
      playTime: 'คืนนี้ 21:00',
      maxPlayers: 3,
      currentPlayers: 2,
      createdBy: 'pond.exe',
      createdAt: now.subtract(const Duration(hours: 1)),
    ),
  ];
}
