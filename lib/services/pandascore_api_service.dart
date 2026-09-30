import 'dart:convert';

import 'package:http/http.dart' as http;

class PandaScoreApiService {
  static const _apiKey = String.fromEnvironment('PANDASCORE_API_KEY');
  static const hasApiKey = _apiKey != '';

  static const _gamesInApp = {
    'valorant': ['valorant'],
    'league of legends': ['league of legends', 'lol'],
    'overwatch 2': ['overwatch 2', 'overwatch'],
    'apex legends': ['apex legends', 'apex'],
    'counter-strike 2': ['counter-strike 2', 'counter-strike', 'csgo'],
    'pubg': ['pubg', 'playerunknowns battlegrounds'],
    'rov': ['rov', 'arena of valor'],
  };

  Future<List<Map<String, dynamic>>> getMatches() async {
    if (!hasApiKey) {
      return _demoMatches;
    }

    final videogames = await _fetchList('/videogames');
    final requests = <Future<List<Map<String, dynamic>>?>>[];

    for (final game in videogames) {
      final name = _normalize(game['name']?.toString() ?? '');
      final isInApp = _gamesInApp.values.any(
        (aliases) => aliases.any((alias) => _normalize(alias) == name),
      );
      final slug = game['slug']?.toString();
      if (!isInApp || slug == null || slug.isEmpty) continue;

      requests
        ..add(_tryFetchMatches('/$slug/matches/running', 'LIVE'))
        ..add(_tryFetchMatches('/$slug/matches/upcoming', 'UPCOMING'));
    }

    if (requests.isEmpty) {
      throw StateError('PandaScore ยังไม่มีข้อมูลเกมที่อยู่ในแอป');
    }

    final responses = await Future.wait(requests);
    final matches = responses
        .whereType<List<Map<String, dynamic>>>()
        .expand((items) => items)
        .toList();
    if (matches.isEmpty && responses.every((items) => items == null)) {
      throw StateError('โหลดตารางแข่งไม่สำเร็จ ตรวจสอบ API key และลองอีกครั้ง');
    }
    matches.sort((a, b) {
      if (a['_displayStatus'] != b['_displayStatus']) {
        return a['_displayStatus'] == 'LIVE' ? -1 : 1;
      }
      final aTime = DateTime.tryParse(a['begin_at']?.toString() ?? '');
      final bTime = DateTime.tryParse(b['begin_at']?.toString() ?? '');
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return aTime.compareTo(bTime);
    });
    return matches;
  }

  Future<List<Map<String, dynamic>>> _fetchMatches(
    String path,
    String status,
  ) async {
    final items = await _fetchList(path);
    return items.map((match) => {...match, '_displayStatus': status}).toList();
  }

  Future<List<Map<String, dynamic>>?> _tryFetchMatches(
    String path,
    String status,
  ) async {
    try {
      return await _fetchMatches(path, status);
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchList(String path) async {
    final uri = Uri.https('api.pandascore.co', path, {'page[size]': '100'});
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $_apiKey'},
    );
    if (response.statusCode != 200) {
      throw Exception('PandaScore ตอบกลับ ${response.statusCode} ที่ $path');
    }

    final data = jsonDecode(response.body) as List<dynamic>;
    return data.cast<Map<String, dynamic>>();
  }

  String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  List<Map<String, dynamic>> get _demoMatches {
    final now = DateTime.now();
    return [
      _demoMatch('VALORANT', 'Paper Rex vs DRX', 'VCT Pacific', now),
      _demoMatch(
        'League of Legends',
        'T1 vs Gen.G',
        'LCK',
        now.add(const Duration(hours: 3)),
      ),
      _demoMatch(
        'Overwatch 2',
        'Team A vs Team B',
        'Overwatch Champions Series',
        now.add(const Duration(hours: 6)),
      ),
      _demoMatch(
        'Apex Legends',
        'Alliance vs Fnatic',
        'ALGS',
        now.add(const Duration(hours: 9)),
      ),
      _demoMatch(
        'Counter-Strike 2',
        'Team Spirit vs G2',
        'BLAST Premier',
        now.add(const Duration(days: 1)),
      ),
      _demoMatch(
        'PUBG',
        'ทีม A vs ทีม B',
        'PUBG Global Series',
        now.add(const Duration(days: 1, hours: 4)),
      ),
      _demoMatch(
        'ROV',
        'ทีม A vs ทีม B',
        'RoV Pro League',
        now.add(const Duration(days: 2)),
      ),
    ];
  }

  Map<String, dynamic> _demoMatch(
    String game,
    String name,
    String tournament,
    DateTime start,
  ) => {
    'name': name,
    '_displayStatus': 'DEMO',
    'videogame': {'name': game},
    'begin_at': start.toIso8601String(),
    'tournament': {'name': tournament},
  };
}
