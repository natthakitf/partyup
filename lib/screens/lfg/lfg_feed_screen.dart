import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:simple_icons/simple_icons.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../models/party_model.dart';
import '../../models/esports_team_model.dart';
import '../../data/demo_data.dart';
import '../../services/firestore_service.dart';
import '../../services/pandascore_api_service.dart';
import '../../services/realtime_chat_service.dart';
import 'party_chat_screen.dart';
import 'lfg_forms.dart';

const _purple = Color(0xFF7C3AED);
const _cyan = Color(0xFF06B6D4);
const _lime = Color(0xFF10B981);
const _games = [
  'VALORANT',
  'League of Legends',
  'Overwatch 2',
  'Apex Legends',
  'Counter-Strike 2',
  'PUBG',
  'ROV',
];

const _groupMembers = [
  ('นายณัฐกิตติ์ เฟื่องฟุ้ง', '6721652137'),
  ('นายศิวกร แสงวิรุณ', '6721652684'),
];

class LfgFeedScreen extends StatefulWidget {
  const LfgFeedScreen({
    super.key,
    required this.firebaseReady,
    required this.isDarkMode,
    required this.onDarkModeChanged,
    required this.playerName,
    required this.playerBio,
    required this.games,
    required this.ranks,
    required this.onProfileChanged,
    required this.onLogout,
  });
  final bool firebaseReady;
  final bool isDarkMode;
  final Future<void> Function(bool value) onDarkModeChanged;
  final String playerName;
  final String playerBio;
  final List<String> games;
  final Map<String, String> ranks;
  final Future<void> Function(
    String name,
    String bio,
    List<String> games,
    Map<String, String> ranks,
  )
  onProfileChanged;
  final Future<void> Function() onLogout;
  @override
  State<LfgFeedScreen> createState() => _LfgFeedScreenState();
}

class _LfgFeedScreenState extends State<LfgFeedScreen> {
  Color get _pageBackground =>
      widget.isDarkMode ? const Color(0xFF0B0E17) : const Color(0xFFF2F2F7);
  Color get _surface =>
      widget.isDarkMode ? const Color(0xD9161B26) : Colors.white;
  Color get _cardBorder =>
      widget.isDarkMode ? const Color(0x18FFFFFF) : const Color(0x0A000000);
  Color get _dark =>
      widget.isDarkMode ? const Color(0xFFF5F7FF) : const Color(0xFF191A22);
  Color get _grey =>
      widget.isDarkMode ? const Color(0xFF929DB0) : const Color(0xFF858894);

  final _service = FirestoreService();
  final _api = PandaScoreApiService();
  final _search = TextEditingController();
  String _game = 'ทั้งหมด';
  int _nav = 0;
  bool _showParties = false;
  bool _showSchedule = false;
  bool _showMembers = false;
  bool _showPastPosts = false;
  final Set<String> _readRooms = {};
  List<EsportsTeamModel> _liveTeams = [];
  List<PartyModel> _liveParties = [];
  StreamSubscription<List<EsportsTeamModel>>? _teamsSubscription;
  StreamSubscription<List<PartyModel>>? _partiesSubscription;
  late List<PartyModel> _demo;
  late List<EsportsTeamModel> _demoTeams;
  Future<List<Map<String, dynamic>>> _matchesFuture = Future.value([]);
  Timer? _matchRefreshTimer;
  DateTime? _lastMatchRefresh;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _demoTeams = DemoData.esportsTeams(now);
    _demo = DemoData.parties(now);
    if (widget.firebaseReady) {
      _teamsSubscription = _service.getTeams().listen((teams) {
        if (mounted) setState(() => _liveTeams = teams);
      }, onError: (_) {});
      _partiesSubscription = _service.getParties().listen((parties) {
        if (mounted) setState(() => _liveParties = parties);
      }, onError: (_) {});
    }
  }

  List<PartyModel> _filter(List<PartyModel> input) => input
      .where(
        (p) =>
            (_nav == 2 ? p.isActive != _showPastPosts : p.isActive) &&
            (_game == 'ทั้งหมด' || _sameGame(p.gameName, _game)) &&
            (_nav != 2 || p.createdBy == 'คุณ') &&
            ('${p.title} ${p.gameName} ${p.requiredRank}'
                .toLowerCase()
                .contains(_search.text.toLowerCase())),
      )
      .toList();

  String _gameKey(String value) {
    final name = value.toLowerCase();
    if (name.contains('valorant')) return 'valorant';
    if (name.contains('league') || name == 'lol') return 'lol';
    if (name.contains('overwatch')) return 'overwatch';
    if (name.contains('apex')) return 'apex';
    if (name.contains('counter') || name == 'cs2' || name == 'csgo') {
      return 'cs2';
    }
    if (name.contains('pubg')) return 'pubg';
    return name.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  bool _sameGame(String first, String second) =>
      _gameKey(first) == _gameKey(second);

  List<Map<String, dynamic>> _filterMatches(List<Map<String, dynamic>> input) =>
      input.where((match) {
        final videogame = match['videogame'] is Map
            ? (match['videogame']['name'] ?? '').toString()
            : '';
        final tournament = match['tournament'] is Map
            ? (match['tournament']['name'] ?? '').toString()
            : '';
        final searchable = '${match['name'] ?? ''} $videogame $tournament';
        return (_game == 'ทั้งหมด' || _sameGame(videogame, _game)) &&
            searchable.toLowerCase().contains(_search.text.toLowerCase());
      }).toList();

  void _selectTab(int index) {
    setState(() => _nav = index);
  }

  int _activeCount(String game) {
    final teams = widget.firebaseReady ? _liveTeams : _demoTeams;
    final parties = widget.firebaseReady ? _liveParties : _demo;
    final activeTeams = teams
        .where((team) => team.isActive && _sameGame(team.gameName, game))
        .length;
    final activeParties = parties
        .where((party) => party.isActive && _sameGame(party.gameName, game))
        .length;
    return activeTeams + activeParties;
  }

  void _refreshMatches() {
    if (!mounted) return;
    setState(() {
      _matchesFuture = _api.getMatches();
      _lastMatchRefresh = DateTime.now();
    });
  }

  @override
  void dispose() {
    _matchRefreshTimer?.cancel();
    _teamsSubscription?.cancel();
    _partiesSubscription?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 760;

    return Scaffold(
      backgroundColor: _pageBackground,
      body: _showSchedule
          ? _schedulePage(wide)
          : SafeArea(bottom: false, child: _pageContent(wide)),
      floatingActionButton: !_showSchedule && _showPostButton
          ? _postFab()
          : null,
      bottomNavigationBar: _showSchedule ? null : _bottomBar(),
    );
  }

  bool get _showPostButton => _nav == 0 || _nav == 1 || _nav == 2;

  Widget _postFab() {
    final label = _showParties ? 'สร้างปาร์ตี้' : 'โพสต์รับสมาชิก';
    return Semantics(
      button: true,
      label: label,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: _purple.withValues(alpha: .48),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: _cyan.withValues(alpha: .14),
              blurRadius: 28,
              offset: const Offset(6, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _openPostForm,
            borderRadius: BorderRadius.circular(30),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded, size: 19, color: Colors.white),
                  const SizedBox(width: 7),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openPostForm() {
    if (_showParties && (_nav == 0 || _nav == 2)) {
      _editParty();
    } else {
      _editTeam();
    }
  }

  Widget _pageContent(bool wide) {
    if (_nav == 4) {
      return _showMembers ? _membersPage(wide) : _profilePage(wide);
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _topBar(wide)),
        if (_nav == 0) ...[
          SliverToBoxAdapter(child: _homeHeader(wide)),
          SliverToBoxAdapter(child: _heroCard(wide)),
          SliverToBoxAdapter(child: _homeSections(wide)),
          if (_showParties) _partySliver(wide) else _teamSliver(wide),
        ] else if (_nav == 1) ...[
          SliverToBoxAdapter(
            child: _pageTitle(
              wide,
              'หาตามเกม',
              'เลือกเกมแล้วหาเพื่อนร่วมทีมได้เลย',
            ),
          ),
          SliverToBoxAdapter(child: _gameGrid(wide)),
          SliverToBoxAdapter(child: _searchBar(wide)),
          SliverToBoxAdapter(child: _gameFilters(wide)),
          _teamSliver(wide),
        ] else if (_nav == 2) ...[
          SliverToBoxAdapter(
            child: _pageTitle(
              wide,
              'โพสต์ของฉัน',
              'ประกาศทีมและปาร์ตี้ที่คุณสร้าง',
            ),
          ),
          SliverToBoxAdapter(child: _postTypePicker(wide)),
          SliverToBoxAdapter(child: _postHistoryPicker(wide)),
          if (_showParties) _partySliver(wide) else _teamSliver(wide),
        ] else ...[
          SliverToBoxAdapter(
            child: _pageTitle(wide, 'แชท', 'ห้องนัดหมายของทีมและปาร์ตี้'),
          ),
          _chatRoomsSliver(wide),
        ],
        SliverToBoxAdapter(child: SizedBox(height: _showPostButton ? 160 : 24)),
      ],
    );
  }

  Widget _topBar(bool wide) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          color: _surface.withValues(alpha: .82),
          padding: EdgeInsets.fromLTRB(wide ? 42 : 20, 10, wide ? 42 : 20, 10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/app_icon.png',
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  semanticLabel: 'PartyUp',
                ),
              ),
              const SizedBox(width: 9),
              Text(
                'partyup',
                style: TextStyle(
                  fontSize: 20,
                  letterSpacing: 0,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                  color: _dark,
                ),
              ),
              const Spacer(),
              _circleButton(Icons.emoji_events_outlined, _openSchedule),
              const SizedBox(width: 8),
              _circleButton(Icons.notifications_none_rounded, () {}),
              const SizedBox(width: 9),
              GestureDetector(
                onTap: () => _selectTab(4),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: widget.isDarkMode
                      ? const Color(0xFF292638)
                      : const Color(0xFFE8E8F8),
                  child: const Icon(
                    Icons.sports_esports_rounded,
                    color: _purple,
                    size: 19,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _homeHeader(bool wide) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: wide ? 42 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'หาเพื่อนร่วมทีม\neSports',
            style: TextStyle(
              fontSize: 32,
              height: 1.28,
              fontWeight: FontWeight.w800,
              letterSpacing: -.6,
              color: _dark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ทีมที่ใช่ เริ่มจากเพื่อนที่เข้ากัน',
            style: TextStyle(color: _grey, fontSize: 15, height: 1.45),
          ),
          const SizedBox(height: 18),
          _gameStrip(),
          const SizedBox(height: 18),
        ],
      ),
    );
  }

  Widget _pageTitle(bool wide, String title, String subtitle) {
    return Padding(
      padding: EdgeInsets.fromLTRB(wide ? 42 : 20, 8, wide ? 42 : 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 30,
              height: 1.28,
              fontWeight: FontWeight.w800,
              letterSpacing: -.5,
              color: _dark,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            subtitle,
            style: TextStyle(color: _grey, fontSize: 15, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _homeSections(bool wide) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _postTypePicker(wide),
          const SizedBox(height: 14),
          _searchBar(wide),
          const SizedBox(height: 12),
          _gameFilters(wide),
          const SizedBox(height: 20),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: wide ? 42 : 20),
            child: _sectionHeader(
              _showParties ? 'ปาร์ตี้ที่กำลังหาเพื่อน' : 'ทีมที่เปิดรับสมาชิก',
              '',
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _postTypePicker(bool wide) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: wide ? 42 : 20),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: widget.isDarkMode
              ? const Color(0xFF2C2C2E)
              : const Color(0xFFE5E5EA),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            _segment(
              'ทีม eSports',
              !_showParties,
              () => setState(() => _showParties = false),
            ),
            _segment(
              'หาเพื่อนเล่นเกม',
              _showParties,
              () => setState(() => _showParties = true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _postHistoryPicker(bool wide) {
    return Padding(
      padding: EdgeInsets.fromLTRB(wide ? 42 : 20, 12, wide ? 42 : 20, 18),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: widget.isDarkMode
              ? const Color(0xFF2C2C2E)
              : const Color(0xFFE5E5EA),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            _segment(
              'กำลังเปิดรับ',
              !_showPastPosts,
              () => setState(() => _showPastPosts = false),
            ),
            _segment(
              'ประวัติที่ผ่านมา',
              _showPastPosts,
              () => setState(() => _showPastPosts = true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _segment(String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? _surface : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? _dark : _grey,
            ),
          ),
        ),
      ),
    );
  }

  Widget _gameStrip() {
    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _games.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) =>
            _gameTile(_games[index], compact: true),
      ),
    );
  }

  Widget _gameGrid(bool wide) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: wide ? 42 : 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _games.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: wide ? 4 : 3,
          mainAxisExtent: 126,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemBuilder: (context, index) => _gameTile(_games[index]),
      ),
    );
  }

  Widget _gameTile(String game, {bool compact = false}) {
    final color = _gameColor(game);
    final selected = _sameGame(_game, game);
    return GestureDetector(
      onTap: () => setState(() => _game = selected ? 'ทั้งหมด' : game),
      child: SizedBox(
        width: compact ? 82 : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: compact ? 56 : 62,
              height: compact ? 56 : 62,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: widget.isDarkMode ? .24 : .12),
                    _surface,
                  ],
                ),
                borderRadius: BorderRadius.circular(19),
                border: Border.all(
                  color: selected ? _purple : _cardBorder,
                  width: selected ? 1.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: selected
                        ? color.withValues(alpha: .22)
                        : Colors.black.withValues(
                            alpha: widget.isDarkMode ? .22 : .04,
                          ),
                    blurRadius: selected ? 18 : 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      right: -8,
                      bottom: -8,
                      child: Transform.rotate(
                        angle: -.24,
                        child: Opacity(
                          opacity: widget.isDarkMode ? .12 : .08,
                          child: _gameLogo(game, 58, color),
                        ),
                      ),
                    ),
                    _gameLogo(game, compact ? 27 : 30, color),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              _shortGameName(game),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: _dark,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${_activeCount(game)} ทีมกำลังหา',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 9, color: _grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchBar(bool wide) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: wide ? 42 : 20),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'ค้นหาทีม, เกม, หรือโหมดการเล่น',
                prefixIcon: Icon(Icons.search_rounded, color: _grey),
                filled: true,
                fillColor: _surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: _cardBorder),
                ),
              ),
            ),
          ),
          const SizedBox(width: 9),
          _circleButton(Icons.tune_rounded, _openGameFilter),
        ],
      ),
    );
  }

  Widget _gameFilters(bool wide) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: wide ? 42 : 20),
      child: SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: ['ทั้งหมด', ..._games].map((game) {
            final selected = _game == game;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(
                  game,
                  style: TextStyle(
                    fontSize: 11,
                    color: selected ? Colors.white : _dark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                selected: selected,
                showCheckmark: false,
                selectedColor: _purple,
                backgroundColor: _surface,
                side: BorderSide(color: selected ? _purple : _cardBorder),
                shape: const StadiumBorder(),
                onSelected: (_) => setState(() => _game = game),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _bottomBar() {
    const labels = ['หน้าแรก', 'หาตามเกม', 'โพสต์ของฉัน', 'แชท', 'โปรไฟล์'];
    const icons = [
      Icons.home_outlined,
      Icons.sports_esports_outlined,
      Icons.add_box_outlined,
      Icons.chat_bubble_outline,
      Icons.person_outline,
    ];
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            decoration: BoxDecoration(
              color: widget.isDarkMode
                  ? const Color(0xE6161B26)
                  : const Color(0xE6FFFFFF),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: widget.isDarkMode
                    ? const Color(0x1FFFFFFF)
                    : const Color(0x18000000),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: widget.isDarkMode ? .30 : .08,
                  ),
                  blurRadius: 26,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: SizedBox(
              height: 62,
              child: Row(
                children: List.generate(
                  labels.length,
                  (index) => Expanded(
                    child: _navButton(index, labels[index], icons[index]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navButton(int index, String label, IconData icon) {
    final selected = _nav == index;
    return InkWell(
      onTap: () => _selectTab(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? _purple.withValues(alpha: widget.isDarkMode ? .18 : .10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 19,
              color: selected ? _cyan : _grey,
              shadows: selected
                  ? [
                      Shadow(
                        color: _cyan.withValues(alpha: .65),
                        blurRadius: 12,
                      ),
                    ]
                  : null,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                color: selected ? _cyan : _grey,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            if (selected)
              Container(
                width: 16,
                height: 2,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: _cyan,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: _cyan.withValues(alpha: .75),
                      blurRadius: 7,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _profilePage(bool wide) {
    final primaryGame = widget.games.isEmpty ? null : widget.games.first;
    final primaryRank = primaryGame == null
        ? 'ยังไม่เลือกแรงค์'
        : widget.ranks[primaryGame] ?? 'Unranked';
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _topBar(wide)),
        SliverToBoxAdapter(
          child: _pageTitle(wide, 'โปรไฟล์', 'ข้อมูลผู้เล่นของคุณ'),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: wide ? 42 : 20),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: _cardDecoration(24),
                  child: Column(
                    children: [
                      Container(
                        width: 82,
                        height: 82,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [_cyan, _purple],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Icon(
                          Icons.sports_esports_rounded,
                          color: Colors.white,
                          size: 38,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.playerName,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: _dark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.playerBio,
                        style: TextStyle(fontSize: 13, color: _grey),
                      ),
                      const SizedBox(height: 18),
                      OutlinedButton.icon(
                        onPressed: _editProfile,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('แก้ไขโปรไฟล์'),
                        style: OutlinedButton.styleFrom(
                          shape: const StadiumBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: widget.isDarkMode
                              ? const Color(0x22FBBF24)
                              : const Color(0xFFFFF4E5),
                          border: Border.all(
                            color: widget.isDarkMode
                                ? const Color(0x66FBBF24)
                                : const Color(0x33C28B28),
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.military_tech_rounded,
                              size: 16,
                              color: const Color(0xFFFBBF24),
                            ),
                            SizedBox(width: 6),
                            Text(
                              primaryGame == null
                                  ? 'เลือกเกมที่เล่น'
                                  : '$primaryGame · $primaryRank',
                              style: TextStyle(
                                fontSize: 12,
                                color: widget.isDarkMode
                                    ? const Color(0xFFFDE68A)
                                    : const Color(0xFF8C641E),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _profileRow(
                  Icons.military_tech_outlined,
                  'เกมที่เล่น',
                  widget.games.isEmpty
                      ? 'ยังไม่ได้เลือกเกม'
                      : widget.games.join(' · '),
                  onTap: _selectGames,
                ),
                const SizedBox(height: 10),
                _profileRow(
                  Icons.verified_user_outlined,
                  'บัญชีผู้ใช้',
                  widget.firebaseReady ? 'เชื่อมต่อ Firebase' : 'โหมดทดลอง',
                ),
                const SizedBox(height: 10),
                _profileRow(
                  Icons.logout_rounded,
                  'ออกจากระบบ',
                  'ออกจากบัญชี PartyUp บนอุปกรณ์นี้',
                  onTap: () => widget.onLogout(),
                ),
                const SizedBox(height: 10),
                _profileRow(
                  Icons.groups_2_outlined,
                  'สมาชิกกลุ่ม',
                  '${_groupMembers.length} คน · ดูรายชื่อและรหัสนักศึกษา',
                  onTap: () => setState(() => _showMembers = true),
                ),
                const SizedBox(height: 10),
                _profileRow(
                  Icons.dark_mode_outlined,
                  'รูปลักษณ์',
                  widget.isDarkMode ? 'มืด' : 'สว่าง',
                  trailing: Switch.adaptive(
                    value: widget.isDarkMode,
                    onChanged: (value) => widget.onDarkModeChanged(value),
                    activeTrackColor: _purple,
                  ),
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'สถิติผู้เล่น',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _dark,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _statCard(
                        '12',
                        'ปาร์ตี้ที่เข้าร่วม',
                        Icons.groups_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _statCard('99%', 'ชื่อเสียง', Icons.stars_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _membersPage(bool wide) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _topBar(wide)),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(wide ? 42 : 20, 8, wide ? 42 : 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextButton.icon(
                  onPressed: () => setState(() => _showMembers = false),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('กลับไปหน้าโปรไฟล์'),
                  style: TextButton.styleFrom(foregroundColor: _purple),
                ),
                const SizedBox(height: 8),
                Text(
                  'สมาชิกกลุ่ม',
                  style: TextStyle(
                    fontSize: 30,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    color: _dark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'ผู้จัดทำแอป PartyUp · ${_groupMembers.length} คน',
                  style: TextStyle(fontSize: 14, color: _grey),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: wide ? 42 : 20),
          sliver: SliverGrid.builder(
            itemCount: _groupMembers.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: wide ? 2 : 1,
              mainAxisExtent: 126,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemBuilder: (context, index) {
              final member = _groupMembers[index];
              return Container(
                padding: const EdgeInsets.all(18),
                decoration: _cardDecoration(20),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: _purple.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Center(
                        child: Text(
                          member.$1.substring(3, 4),
                          style: const TextStyle(
                            color: _purple,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.$1,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _dark,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'รหัสนักศึกษา ${member.$2}',
                            style: TextStyle(fontSize: 12, color: _grey),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.verified_user_outlined,
                      color: _purple,
                      size: 19,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _profileRow(
    IconData icon,
    String title,
    String subtitle, {
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: _cardDecoration(18),
          child: Row(
            children: [
              Icon(icon, color: _purple),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: _dark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: _grey, fontSize: 11),
                    ),
                  ],
                ),
              ),
              ?trailing,
              if (onTap != null) ...[
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, color: _grey, size: 19),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editProfile() async {
    final nameController = TextEditingController(text: widget.playerName);
    final bioController = TextEditingController(text: widget.playerBio);
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('แก้ไขโปรไฟล์'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                maxLength: 30,
                decoration: const InputDecoration(labelText: 'ชื่อที่แสดง'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'กรุณาใส่ชื่อ'
                    : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: bioController,
                maxLength: 60,
                decoration: const InputDecoration(labelText: 'แนะนำตัวสั้น ๆ'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(dialogContext, [
                nameController.text.trim(),
                bioController.text.trim(),
              ]);
            },
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );

    nameController.dispose();
    bioController.dispose();
    if (result == null || !mounted) return;
    await widget.onProfileChanged(
      result[0],
      result[1],
      widget.games,
      widget.ranks,
    );
    if (mounted) _showMessage('บันทึกโปรไฟล์แล้ว');
  }

  Future<void> _selectGames() async {
    final selected = widget.games.toSet();
    final ranks = Map<String, String>.from(widget.ranks);
    const rankOptions = [
      'Unranked',
      'Iron',
      'Bronze',
      'Silver',
      'Gold',
      'Platinum',
      'Diamond',
      'Ascendant',
      'Immortal',
      'Radiant',
      'Master',
      'Grandmaster',
      'Challenger',
    ];

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refreshDialog) => AlertDialog(
          title: const Text('เกมที่เล่น'),
          content: SizedBox(
            width: 420,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 480),
              child: ListView(
                shrinkWrap: true,
                children: _games.map((game) {
                  final isSelected = selected.contains(game);
                  return Column(
                    children: [
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: isSelected,
                        activeColor: _purple,
                        title: Text(game),
                        secondary: _gameLogo(game, 22, _gameColor(game)),
                        onChanged: (value) => refreshDialog(() {
                          if (value == true) {
                            selected.add(game);
                            ranks.putIfAbsent(game, () => 'Unranked');
                          } else {
                            selected.remove(game);
                          }
                        }),
                      ),
                      if (isSelected)
                        Padding(
                          padding: const EdgeInsets.only(left: 50, bottom: 8),
                          child: DropdownButtonFormField<String>(
                            initialValue: rankOptions.contains(ranks[game])
                                ? ranks[game]
                                : 'Unranked',
                            decoration: const InputDecoration(
                              labelText: 'แรงค์',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            items: rankOptions
                                .map(
                                  (rank) => DropdownMenuItem(
                                    value: rank,
                                    child: Text(rank),
                                  ),
                                )
                                .toList(),
                            onChanged: (rank) {
                              if (rank != null) {
                                refreshDialog(() => ranks[game] = rank);
                              }
                            },
                          ),
                        ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );

    if (result != true || !mounted) return;
    await widget.onProfileChanged(
      widget.playerName,
      widget.playerBio,
      selected.toList(),
      ranks,
    );
    if (mounted) _showMessage('บันทึกเกมและแรงค์แล้ว');
  }

  Widget _statCard(String value, String label, IconData icon) => Container(
    padding: const EdgeInsets.all(16),
    decoration: _cardDecoration(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _purple, size: 19),
        const SizedBox(height: 12),
        Text(
          value,
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w700,
            color: _dark,
          ),
        ),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(fontSize: 11, color: _grey)),
      ],
    ),
  );

  BoxDecoration _cardDecoration(double radius) => BoxDecoration(
    color: _surface,
    borderRadius: BorderRadius.circular(radius),
    border: Border.fromBorderSide(BorderSide(color: _cardBorder)),
    boxShadow: [
      BoxShadow(
        color: widget.isDarkMode
            ? _purple.withValues(alpha: .10)
            : Colors.black.withValues(alpha: .05),
        blurRadius: 24,
        offset: const Offset(0, 8),
      ),
    ],
  );

  Widget _circleButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: _surface.withValues(alpha: .9),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(icon, size: 19, color: _dark),
        ),
      ),
    );
  }

  Future<void> _openGameFilter() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _surface.withValues(alpha: .94),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(26),
                ),
                border: Border.all(color: _cardBorder),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'เลือกเกม',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['ทั้งหมด', ..._games]
                        .map(
                          (game) => ChoiceChip(
                            label: Text(game),
                            selected: _game == game,
                            selectedColor: _purple,
                            backgroundColor: _surface,
                            side: BorderSide(color: _cardBorder),
                            labelStyle: TextStyle(
                              color: _game == game ? Colors.white : _dark,
                              fontWeight: FontWeight.w600,
                            ),
                            onSelected: (_) {
                              setState(() => _game = game);
                              Navigator.pop(context);
                            },
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openSchedule() {
    _refreshMatches();
    setState(() => _showSchedule = true);
    if (PandaScoreApiService.hasApiKey) {
      _matchRefreshTimer?.cancel();
      _matchRefreshTimer = Timer.periodic(
        const Duration(seconds: 60),
        (_) => _refreshMatches(),
      );
    }
  }

  void _closeSchedule() {
    _matchRefreshTimer?.cancel();
    _matchRefreshTimer = null;
    setState(() => _showSchedule = false);
  }

  Widget _schedulePage(bool wide) => SafeArea(
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'ตารางแข่ง eSports',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
              Material(
                color: _surface,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _closeSchedule,
                  child: const SizedBox(
                    width: 48,
                    height: 48,
                    child: Tooltip(
                      message: 'ปิดตารางแข่ง',
                      child: Icon(Icons.close_rounded),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: CustomScrollView(slivers: [_matchesSliver(wide)])),
      ],
    ),
  );

  Widget _chatRoomsSliver(bool wide) {
    if (!widget.firebaseReady) {
      final rooms = [
        ..._demoTeams.map(
          (team) => _roomCard(
            team.title,
            team.gameName,
            team.practiceTime,
            () => _contactTeam(team),
            roomId: 'team_${team.id}',
            hostName: team.createdBy,
          ),
        ),
        ..._demo.map(
          (party) => _roomCard(
            party.title,
            party.gameName,
            party.playTime,
            () => _openPartyChat(party),
            roomId: party.id,
            hostName: party.createdBy,
          ),
        ),
      ];
      return SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: wide ? 42 : 20),
        sliver: SliverList.list(children: rooms),
      );
    }
    return SliverToBoxAdapter(
      child: StreamBuilder<List<EsportsTeamModel>>(
        stream: _service.getTeams(),
        builder: (context, teamSnapshot) {
          final teams = teamSnapshot.data ?? [];
          return StreamBuilder<List<PartyModel>>(
            stream: _service.getParties(),
            builder: (context, partySnapshot) {
              final parties = partySnapshot.data ?? [];
              if (teams.isEmpty &&
                  parties.isEmpty &&
                  (teamSnapshot.hasError || partySnapshot.hasError)) {
                return _firebaseError('โหลดห้องแชทไม่สำเร็จ');
              }
              if (teams.isEmpty && parties.isEmpty) {
                return Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'ยังไม่มีห้องแชท ลองเข้าร่วมทีมก่อน',
                      style: TextStyle(color: _grey),
                    ),
                  ),
                );
              }
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: wide ? 42 : 20),
                child: Column(
                  children: [
                    ...teams.map(
                      (team) => _roomCard(
                        team.title,
                        team.gameName,
                        team.practiceTime,
                        () => _contactTeam(team),
                        roomId: 'team_${team.id}',
                        hostName: team.createdBy,
                      ),
                    ),
                    ...parties.map(
                      (party) => _roomCard(
                        party.title,
                        party.gameName,
                        party.playTime,
                        () => _openPartyChat(party),
                        roomId: party.id,
                        hostName: party.createdBy,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _roomCard(
    String title,
    String game,
    String time,
    VoidCallback onTap, {
    required String roomId,
    required String hostName,
  }) {
    return StreamBuilder<DatabaseEvent>(
      stream: widget.firebaseReady
          ? RealtimeChatService().getChatMessages(roomId)
          : null,
      builder: (context, snapshot) {
        var preview = widget.firebaseReady
            ? 'เริ่มนัดหมายกับทีมได้เลย'
            : 'หวัดดี พร้อมเล่นเมื่อไร?';
        var sender = hostName;
        var unread = widget.firebaseReady ? 0 : 1;
        final value = snapshot.data?.snapshot.value;
        if (value is Map) {
          final messages = value.values.whereType<Map>().toList();
          if (messages.isNotEmpty) {
            final latest = messages.last;
            sender = latest['sender']?.toString() ?? hostName;
            preview = latest['message']?.toString() ?? preview;
            unread = messages
                .where((message) => message['sender']?.toString() != 'คุณ')
                .length;
          }
        }
        final showUnread = !_readRooms.contains(roomId) && unread > 0;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: _cardDecoration(18),
          child: ListTile(
            onTap: () {
              setState(() => _readRooms.add(roomId));
              onTap();
            },
            leading: CircleAvatar(
              backgroundColor: _gameColor(game).withValues(alpha: .12),
              child: _gameLogo(game, 21, _gameColor(game)),
            ),
            title: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$sender: $preview',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$game · $time',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: _grey),
                ),
              ],
            ),
            trailing: showUnread
                ? Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF3B30),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$unread',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                : Icon(Icons.chevron_right_rounded, color: _grey),
          ),
        );
      },
    );
  }

  void _openPartyChat(PartyModel party) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PartyChatScreen(party: party, firebaseReady: widget.firebaseReady),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  List<EsportsTeamModel> _filterTeams(List<EsportsTeamModel> teams) => teams
      .where(
        (t) =>
            (_nav == 2 ? t.isActive != _showPastPosts : t.isActive) &&
            (_game == 'ทั้งหมด' || _sameGame(t.gameName, _game)) &&
            (_nav != 2 || t.createdBy == 'คุณ') &&
            '${t.title} ${t.gameName} ${t.requiredRank} ${t.role} ${t.createdBy}'
                .toLowerCase()
                .contains(_search.text.toLowerCase()),
      )
      .toList();

  Widget _teamSliver(bool wide) {
    if (!widget.firebaseReady) {
      final teams = _filterTeams(_demoTeams);
      if (teams.isEmpty) {
        return SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: Center(
              child: Text(
                'ยังไม่มีทีมที่เปิดรับสมาชิก',
                style: TextStyle(color: _grey),
              ),
            ),
          ),
        );
      }
      return SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: wide ? 42 : 20),
        sliver: SliverGrid.builder(
          itemCount: teams.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: wide ? 2 : 1,
            mainAxisExtent: 260,
            crossAxisSpacing: 14,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (_, i) => _teamCard(teams[i]),
        ),
      );
    }
    return SliverToBoxAdapter(
      child: StreamBuilder<List<EsportsTeamModel>>(
        stream: _service.getTeams(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _firebaseError(snapshot.error.toString());
          }
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final teams = _filterTeams(snapshot.data ?? []);
          if (teams.isEmpty) {
            return Padding(
              padding: EdgeInsets.all(28),
              child: Center(
                child: Text(
                  'ยังไม่มีทีมที่เปิดรับสมาชิก ลองโพสต์ทีมแรกเลย',
                  style: TextStyle(color: _grey),
                ),
              ),
            );
          }
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: wide ? 42 : 20),
            child: Wrap(
              spacing: 14,
              runSpacing: 12,
              children: teams
                  .map(
                    (t) => SizedBox(
                      width: wide
                          ? (MediaQuery.sizeOf(context).width - 98) / 2
                          : MediaQuery.sizeOf(context).width - 40,
                      child: _teamCard(t),
                    ),
                  )
                  .toList(),
            ),
          );
        },
      ),
    );
  }

  Widget _teamCard(EsportsTeamModel team) => ClipRRect(
    borderRadius: BorderRadius.circular(22),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Container(
        height: 260,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.fromBorderSide(BorderSide(color: _cardBorder)),
          boxShadow: [
            BoxShadow(
              color: widget.isDarkMode
                  ? _purple.withValues(alpha: .12)
                  : Colors.black.withValues(alpha: .05),
              blurRadius: widget.isDarkMode ? 28 : 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _gameColor(team.gameName).withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 25,
                        height: 25,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _gameLogo(
                          team.gameName,
                          17,
                          _gameColor(team.gameName),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Padding(
                        padding: const EdgeInsets.only(right: 5),
                        child: Text(
                          team.gameName,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _gameColor(team.gameName),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (team.isActive)
                  const _PulsingDot()
                else
                  Icon(
                    Icons.pause_circle_outline_rounded,
                    size: 12,
                    color: _grey,
                  ),
                const SizedBox(width: 5),
                Text(
                  team.isActive ? 'รับสมาชิก' : 'ปิดรับแล้ว',
                  style: TextStyle(
                    fontSize: 11,
                    color: team.isActive ? _lime : _grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _postedTime(team.createdAt),
                  style: TextStyle(fontSize: 10, color: _grey),
                ),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  onSelected: (v) {
                    if (v == 'edit') _editTeam(team);
                    if (v == 'delete') _deleteTeam(team);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('แก้ไข')),
                    PopupMenuItem(value: 'delete', child: Text('ลบ')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              team.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                height: 1.3,
                fontWeight: FontWeight.w700,
                color: _dark,
              ),
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 7,
              runSpacing: 6,
              children: [
                _rankBadge(team.requiredRank),
                _pill(Icons.person_search_rounded, 'Looking for: ${team.role}'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              team.playStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, height: 1.4, color: _grey),
            ),
            const SizedBox(height: 11),
            _playerSlots(team),
            const Spacer(),
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: widget.isDarkMode
                      ? const Color(0xFF292638)
                      : const Color(0xFFE8E8F8),
                  child: Text(
                    team.createdBy.isEmpty
                        ? '?'
                        : team.createdBy[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 9,
                      color: _purple,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              team.createdBy,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: _dark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Icon(
                            Icons.verified_rounded,
                            color: _purple,
                            size: 12,
                          ),
                        ],
                      ),
                      Text(
                        'ซ้อม ${team.practiceTime}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          height: 1.3,
                          color: _grey,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (_nav == 2) ...[
                  TextButton.icon(
                    onPressed: () => _editTeam(team),
                    icon: const Icon(Icons.edit_outlined, size: 14),
                    label: const Text('แก้ไข'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      minimumSize: Size.zero,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _setTeamActive(team, !team.isActive),
                    icon: Icon(
                      team.isActive
                          ? Icons.archive_outlined
                          : Icons.refresh_rounded,
                      size: 14,
                    ),
                    label: Text(team.isActive ? 'ปิดรับ' : 'เปิดใหม่'),
                    style: TextButton.styleFrom(
                      foregroundColor: team.isActive
                          ? const Color(0xFFE28A43)
                          : _lime,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: Size.zero,
                    ),
                  ),
                ] else
                  SizedBox(
                    height: 32,
                    child: FilledButton(
                      onPressed: () => _contactTeam(team),
                      style: FilledButton.styleFrom(
                        backgroundColor: _purple,
                        padding: const EdgeInsets.symmetric(horizontal: 11),
                        shape: const StadiumBorder(),
                      ),
                      child: const Text(
                        '+ เข้าร่วมทีม',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Widget _playerSlots(EsportsTeamModel team) {
    final slots = team.maxPlayers.clamp(1, 6);
    final players = team.currentPlayers.clamp(0, slots);

    return Row(
      children: [
        Text('สมาชิก', style: TextStyle(fontSize: 10, color: _grey)),
        const SizedBox(width: 8),
        ...List.generate(slots, (index) {
          if (index < players) {
            final isHost = index == 0;
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Container(
                width: 23,
                height: 23,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: isHost
                        ? const [Color(0xFF7C3AED), Color(0xFF06B6D4)]
                        : widget.isDarkMode
                        ? const [Color(0xFF27344B), Color(0xFF172333)]
                        : const [Color(0xFFE2E0FF), Color(0xFFC9C5FF)],
                  ),
                  border: Border.all(
                    color: widget.isDarkMode
                        ? const Color(0x667C3AED)
                        : Colors.white,
                    width: 1.5,
                  ),
                  boxShadow: const [
                    BoxShadow(color: Color(0x10000000), blurRadius: 4),
                  ],
                ),
                child: Center(
                  child: isHost
                      ? Text(
                          team.createdBy.isEmpty
                              ? '?'
                              : team.createdBy[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : const Icon(
                          Icons.person_rounded,
                          color: Colors.white,
                          size: 13,
                        ),
                ),
              ),
            );
          }

          return Padding(
            padding: EdgeInsets.only(right: 4),
            child: _EmptyPlayerSlot(color: widget.isDarkMode ? _cyan : _purple),
          );
        }),
        const Spacer(),
        Text(
          '$players/${team.maxPlayers}',
          style: TextStyle(
            fontSize: 11,
            color: _dark,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  void _contactTeam(EsportsTeamModel team) {
    final party = PartyModel(
      id: 'team_${team.id}',
      title: team.title,
      gameName: team.gameName,
      requiredRank: team.requiredRank,
      playStyle: team.playStyle,
      playTime: team.practiceTime,
      maxPlayers: team.maxPlayers,
      currentPlayers: team.currentPlayers,
      createdBy: team.createdBy,
      createdAt: team.createdAt,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PartyChatScreen(party: party, firebaseReady: widget.firebaseReady),
      ),
    );
  }

  Widget _partySliver(bool wide) {
    if (!widget.firebaseReady) {
      final list = _filter(_demo);
      return _partyGrid(list, wide);
    }
    return SliverToBoxAdapter(
      child: StreamBuilder<List<PartyModel>>(
        stream: _service.getParties(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _firebaseError(snapshot.error.toString());
          }
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final parties = _filter(snapshot.data ?? []);
          if (parties.isEmpty) {
            return Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'ยังไม่มีปาร์ตี้ ลองสร้างปาร์ตี้แรกเลย!',
                  style: TextStyle(color: _grey),
                ),
              ),
            );
          }
          if (wide) {
            final width = MediaQuery.sizeOf(context).width;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 42),
              child: Wrap(
                spacing: 14,
                runSpacing: 12,
                children: parties
                    .map(
                      (party) => SizedBox(
                        width: (width - 98) / 2,
                        child: _partyCard(party),
                      ),
                    )
                    .toList(),
              ),
            );
          }
          return Column(children: parties.map(_partyCard).toList());
        },
      ),
    );
  }

  Widget _partyGrid(List<PartyModel> parties, bool wide) {
    if (parties.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text(
              'ยังไม่มีปาร์ตี้ที่ตรงกัน',
              style: TextStyle(color: _grey),
            ),
          ),
        ),
      );
    }
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: wide ? 42 : 20),
      sliver: SliverGrid.builder(
        itemCount: parties.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: wide ? 2 : 1,
          mainAxisExtent: 198,
          crossAxisSpacing: 14,
          mainAxisSpacing: 12,
        ),
        itemBuilder: (context, index) => _partyCard(parties[index]),
      ),
    );
  }

  Widget _partyCard(PartyModel p) => ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Container(
        height: 190,
        margin: EdgeInsets.only(bottom: widget.firebaseReady ? 11 : 0),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.fromBorderSide(BorderSide(color: _cardBorder)),
          boxShadow: [
            BoxShadow(
              color: widget.isDarkMode
                  ? _purple.withValues(alpha: .12)
                  : Colors.black.withValues(alpha: .05),
              blurRadius: widget.isDarkMode ? 28 : 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _gameColor(p.gameName).withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    p.gameName,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _gameColor(p.gameName),
                    ),
                  ),
                ),
                if (!p.isActive) ...[
                  const SizedBox(width: 7),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: widget.isDarkMode
                          ? const Color(0xFF2C2C2E)
                          : const Color(0xFFF1F2F5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'ปิดแล้ว',
                      style: TextStyle(fontSize: 10, color: _grey),
                    ),
                  ),
                ],
                const Spacer(),
                Text(p.playTime, style: TextStyle(fontSize: 11, color: _grey)),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  onSelected: (v) {
                    if (v == 'edit') _editParty(p);
                    if (v == 'delete') _deleteParty(p);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('แก้ไข')),
                    PopupMenuItem(value: 'delete', child: Text('ลบ')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              p.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _dark,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 6,
              children: [
                _rankBadge(p.requiredRank),
                _pill(Icons.bolt_rounded, p.playStyle),
              ],
            ),
            const Spacer(),
            Row(
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: widget.isDarkMode
                      ? const Color(0xFF292638)
                      : const Color(0xFFE9E7F6),
                  child: Text(
                    p.createdBy.isNotEmpty ? p.createdBy[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 10,
                      color: _purple,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    p.createdBy,
                    style: TextStyle(fontSize: 11, color: _grey),
                  ),
                ),
                Icon(Icons.people_alt_outlined, size: 15, color: _grey),
                const SizedBox(width: 4),
                Text(
                  '${p.currentPlayers}/${p.maxPlayers}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 10),
                if (_nav == 2) ...[
                  TextButton.icon(
                    onPressed: () => _editParty(p),
                    icon: const Icon(Icons.edit_outlined, size: 14),
                    label: const Text('แก้ไข'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      minimumSize: Size.zero,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _setPartyActive(p, !p.isActive),
                    icon: Icon(
                      p.isActive
                          ? Icons.archive_outlined
                          : Icons.refresh_rounded,
                      size: 14,
                    ),
                    label: Text(p.isActive ? 'ปิดปาร์ตี้' : 'เปิดใหม่'),
                    style: TextButton.styleFrom(
                      foregroundColor: p.isActive
                          ? const Color(0xFFE28A43)
                          : _lime,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: Size.zero,
                    ),
                  ),
                ] else
                  SizedBox(
                    height: 32,
                    child: FilledButton.icon(
                      onPressed: () => _openPartyChat(p),
                      style: FilledButton.styleFrom(
                        backgroundColor: _purple,
                        padding: const EdgeInsets.symmetric(horizontal: 11),
                        shape: const StadiumBorder(),
                      ),
                      icon: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 13,
                      ),
                      label: const Text(
                        'เข้าห้อง',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Widget _matchesSliver(bool wide) => SliverToBoxAdapter(
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: wide ? 42 : 20),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _matchesFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            final needsApiKey = !PandaScoreApiService.hasApiKey;
            return Padding(
              padding: const EdgeInsets.fromLTRB(8, 48, 8, 20),
              child: Column(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: widget.isDarkMode
                          ? const Color(0xFF292638)
                          : const Color(0xFFECEAFF),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.emoji_events_outlined,
                      color: _purple,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    needsApiKey
                        ? 'ตั้งค่า API key เพื่อดูตารางจริง'
                        : 'โหลดตารางแข่งไม่สำเร็จ',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _dark,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    needsApiKey
                        ? 'เพิ่ม PANDASCORE_API_KEY ในการตั้งค่ารันแอป แล้วหยุดและเริ่มแอปใหม่'
                        : 'ตรวจสอบการเชื่อมต่อและ API key แล้วลองรีเฟรชอีกครั้ง',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, height: 1.5, color: _grey),
                  ),
                ],
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.all(28),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final matches = _filterMatches(snapshot.data ?? []);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    const Icon(Icons.sync_rounded, size: 14, color: _purple),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        !PandaScoreApiService.hasApiKey
                            ? 'ข้อมูลตัวอย่าง · ตั้งค่า API key เพื่อดูตารางจริง'
                            : _lastMatchRefresh == null
                            ? 'กำลังโหลดข้อมูลการแข่งขัน'
                            : 'อัปเดตอัตโนมัติทุก 60 วินาที · ${_lastMatchRefresh!.hour.toString().padLeft(2, '0')}:${_lastMatchRefresh!.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(fontSize: 10, color: _grey),
                      ),
                    ),
                    IconButton(
                      tooltip: 'รีเฟรชตารางแข่ง',
                      visualDensity: VisualDensity.compact,
                      onPressed: _refreshMatches,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                    ),
                  ],
                ),
              ),
              if (matches.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    _game == 'ทั้งหมด'
                        ? 'ยังไม่มีตารางแข่งในขณะนี้'
                        : 'ยังไม่มีตารางแข่ง $_game ในรายการที่ดึงมา',
                    style: TextStyle(color: _grey, fontSize: 12),
                  ),
                ),
              ...matches.map((m) {
                final videogame = m['videogame'] is Map
                    ? (m['videogame']['name'] ?? 'eSports').toString()
                    : 'eSports';
                final tournament = m['tournament'] is Map
                    ? (m['tournament']['name'] ?? 'รายการแข่งขัน').toString()
                    : 'รายการแข่งขัน';
                final start = DateTime.tryParse(m['begin_at']?.toString() ?? '')
                    ?.toLocal();
                final live = m['_displayStatus'] == 'LIVE';
                final demo = m['_displayStatus'] == 'DEMO';
                final when = start == null
                    ? 'รอกำหนดเวลา'
                    : '${start.day}/${start.month} · ${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
                return Container(
                  margin: const EdgeInsets.only(bottom: 11),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: widget.isDarkMode
                              ? const Color(0xFF292638)
                              : const Color(0xFFECEAFF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.emoji_events_rounded,
                          color: _purple,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    videogame,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: _purple,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: live
                                        ? const Color(0xFFE8F6EE)
                                        : demo
                                        ? const Color(0xFFFFF1DE)
                                        : const Color(0xFFF1F2F5),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    live
                                        ? 'LIVE'
                                        : demo
                                        ? 'ตัวอย่าง'
                                        : 'เร็ว ๆ นี้',
                                    style: TextStyle(
                                      fontSize: 8,
                                      color: live
                                          ? const Color(0xFF32835A)
                                          : demo
                                          ? const Color(0xFFB7782B)
                                          : _grey,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              m['name']?.toString() ?? tournament,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              tournament,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 10, color: _grey),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        when,
                        style: TextStyle(
                          fontSize: 10,
                          color: _grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          );
        },
      ),
    ),
  );

  Widget _heroCard(bool wide) => Padding(
    padding: EdgeInsets.symmetric(horizontal: wide ? 42 : 20),
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _purple.withValues(alpha: .30),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: _cyan.withValues(alpha: .12),
            blurRadius: 34,
            offset: const Offset(10, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF141527), Color(0xFF4C1D95), Color(0xFF0E5361)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -82,
                right: 16,
                child: _heroGlow(const Color(0xFFB5A9FF), 190),
              ),
              Positioned(
                bottom: -105,
                right: 120,
                child: _heroGlow(_cyan, 190),
              ),
              Padding(
                padding: const EdgeInsets.all(19),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .14),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              'PARTY UP, LEVEL UP',
                              style: TextStyle(
                                fontSize: 9,
                                letterSpacing: 1,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 11),
                          const Text(
                            'ทีมดี เริ่มจาก\nเพื่อนที่เข้ากัน',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'เลือกเกม เลือกแรงค์ แล้วไปลุยกัน',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .75),
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextButton.icon(
                            onPressed: () => _selectTab(1),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              backgroundColor: Colors.white.withValues(
                                alpha: .14,
                              ),
                              shape: const StadiumBorder(),
                            ),
                            icon: const Icon(
                              Icons.arrow_forward_rounded,
                              size: 15,
                            ),
                            label: const Text(
                              'ดูทีมที่กำลังหาเพื่อน',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Transform.rotate(
                      angle: -.12,
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF67E8F9), Color(0xFF7C3AED)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: .55),
                            width: 1.5,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x550F0D2E),
                              blurRadius: 18,
                              offset: Offset(0, 12),
                            ),
                            BoxShadow(
                              color: Color(0x66FFFFFF),
                              blurRadius: 1,
                              offset: Offset(-2, -2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.sports_esports_rounded,
                          color: Color(0xFF4B418F),
                          size: 38,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _heroGlow(Color color, double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [color.withValues(alpha: .42), color.withValues(alpha: 0)],
      ),
    ),
  );
  Widget _sectionHeader(String title, String trailing) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: -.4,
            color: _dark,
          ),
        ),
      ),
      Text(
        trailing,
        style: const TextStyle(
          fontSize: 11,
          color: _purple,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
  Widget _pill(IconData icon, String text) {
    final roleTag = text.startsWith('Looking for:');
    final accent = roleTag ? _cyan : _grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: widget.isDarkMode
            ? (roleTag ? _cyan.withValues(alpha: .10) : const Color(0xFF202735))
            : (roleTag
                  ? _cyan.withValues(alpha: .08)
                  : const Color(0xFFF3F4F6)),
        borderRadius: BorderRadius.circular(8),
        border: roleTag
            ? Border.all(color: _cyan.withValues(alpha: .24))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: accent),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              color: roleTag
                  ? (widget.isDarkMode ? _cyan : const Color(0xFF087E99))
                  : _grey,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _rankBadge(String rank) {
    final normalized = rank.toLowerCase();
    final badgeColor = normalized.contains('radiant')
        ? const Color(0xFFFBBF24)
        : normalized.contains('diamond') || normalized.contains('ascendant')
        ? _cyan
        : const Color(0xFFA78BFA);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            badgeColor.withValues(alpha: widget.isDarkMode ? .20 : .12),
            _surface,
          ],
        ),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: badgeColor.withValues(alpha: .38)),
        boxShadow: widget.isDarkMode
            ? [
                BoxShadow(
                  color: badgeColor.withValues(alpha: .12),
                  blurRadius: 12,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.military_tech_rounded, size: 13, color: badgeColor),
          const SizedBox(width: 5),
          Text(
            rank,
            style: TextStyle(
              fontSize: 10,
              color: widget.isDarkMode ? badgeColor : const Color(0xFF51445F),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _firebaseError(String error) => Padding(
    padding: const EdgeInsets.all(18),
    child: Text(
      'เชื่อม Firestore ไม่สำเร็จ\n$error',
      style: const TextStyle(color: Colors.redAccent, fontSize: 12),
    ),
  );
  String _postedTime(DateTime createdAt) {
    final age = DateTime.now().difference(createdAt);
    if (age.inMinutes < 1) return 'เมื่อกี้';
    if (age.inHours < 1) return '${age.inMinutes} นาทีที่แล้ว';
    if (age.inDays < 1) return '${age.inHours} ชม.ที่แล้ว';
    return '${createdAt.day}/${createdAt.month}';
  }

  Widget _gameLogo(String game, double size, Color color) {
    if (_sameGame(game, 'VALORANT')) {
      return Icon(SimpleIcons.valorant, size: size, color: color);
    }
    if (_sameGame(game, 'League of Legends')) {
      return Icon(SimpleIcons.leagueoflegends, size: size, color: color);
    }
    if (_sameGame(game, 'Counter-Strike 2')) {
      return Icon(SimpleIcons.counterstrike, size: size, color: color);
    }
    if (_sameGame(game, 'PUBG')) {
      return Icon(SimpleIcons.pubg, size: size, color: color);
    }

    return CustomPaint(
      size: Size.square(size),
      painter: _GameSymbolPainter(game: game, color: color),
    );
  }

  String _shortGameName(String game) {
    if (game == 'League of Legends') return 'League';
    if (game == 'Overwatch 2') return 'Overwatch';
    if (game == 'Counter-Strike 2') return 'CS2';
    return game;
  }

  Color _gameColor(String game) {
    if (game == 'VALORANT') return const Color(0xFFFF4655);
    if (game == 'League of Legends') return const Color(0xFFC8A45D);
    if (game == 'Overwatch 2') return const Color(0xFFEF8A36);
    if (game == 'PUBG') return const Color(0xFFE8A21A);
    if (game == 'ROV') return const Color(0xFF4C8FE8);
    if (game == 'Apex Legends') return const Color(0xFFCE3B3B);
    return _purple;
  }

  Future<void> _editTeam([EsportsTeamModel? existing]) async {
    final result = await showModalBottomSheet<EsportsTeamModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EsportsTeamForm(team: existing),
    );
    if (result == null || !mounted) return;
    if (widget.firebaseReady) {
      try {
        if (existing == null) {
          await _service.createTeam(result);
        } else {
          await _service.updateTeam(result);
        }
      } catch (e) {
        _snack('บันทึกประกาศทีมไม่สำเร็จ: $e');
      }
    } else {
      setState(() {
        if (existing == null) {
          _demoTeams.insert(0, result);
        } else {
          _demoTeams[_demoTeams.indexWhere((t) => t.id == existing.id)] =
              result;
        }
      });
    }
  }

  Future<void> _deleteTeam(EsportsTeamModel team) async {
    if (widget.firebaseReady) {
      try {
        await _service.deleteTeam(team.id);
      } catch (e) {
        _snack('ลบประกาศไม่สำเร็จ: $e');
      }
    } else {
      setState(() => _demoTeams.removeWhere((t) => t.id == team.id));
    }
  }

  Future<void> _setTeamActive(EsportsTeamModel team, bool isActive) async {
    final updated = EsportsTeamModel(
      id: team.id,
      title: team.title,
      gameName: team.gameName,
      requiredRank: team.requiredRank,
      role: team.role,
      playStyle: team.playStyle,
      practiceTime: team.practiceTime,
      maxPlayers: team.maxPlayers,
      currentPlayers: team.currentPlayers,
      createdBy: team.createdBy,
      createdAt: team.createdAt,
      isActive: isActive,
    );
    if (widget.firebaseReady) {
      try {
        await _service.updateTeam(updated);
      } catch (error) {
        _snack('เปลี่ยนสถานะโพสต์ไม่สำเร็จ: $error');
      }
    } else {
      setState(() {
        final index = _demoTeams.indexWhere((item) => item.id == team.id);
        if (index >= 0) _demoTeams[index] = updated;
      });
    }
  }

  Future<void> _editParty([PartyModel? existing]) async {
    final result = await showModalBottomSheet<PartyModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PartyForm(party: existing),
    );
    if (result == null || !mounted) return;
    if (widget.firebaseReady) {
      try {
        if (existing == null) {
          await _service.createParty(result);
        } else {
          await _service.updateParty(result);
        }
      } catch (e) {
        _snack('บันทึกไม่สำเร็จ: $e');
      }
    } else {
      setState(() {
        if (existing == null) {
          _demo.insert(0, result);
        } else {
          _demo[_demo.indexWhere((p) => p.id == existing.id)] = result;
        }
      });
    }
  }

  Future<void> _deleteParty(PartyModel party) async {
    if (widget.firebaseReady) {
      try {
        await _service.deleteParty(party.id);
      } catch (e) {
        _snack('ลบไม่สำเร็จ: $e');
      }
    } else {
      setState(() => _demo.removeWhere((p) => p.id == party.id));
    }
  }

  Future<void> _setPartyActive(PartyModel party, bool isActive) async {
    final updated = PartyModel(
      id: party.id,
      title: party.title,
      gameName: party.gameName,
      requiredRank: party.requiredRank,
      playStyle: party.playStyle,
      playTime: party.playTime,
      maxPlayers: party.maxPlayers,
      currentPlayers: party.currentPlayers,
      createdBy: party.createdBy,
      createdAt: party.createdAt,
      isActive: isActive,
    );
    if (widget.firebaseReady) {
      try {
        await _service.updateParty(updated);
      } catch (error) {
        _snack('เปลี่ยนสถานะโพสต์ไม่สำเร็จ: $error');
      }
    } else {
      setState(() {
        final index = _demo.indexWhere((item) => item.id == party.id);
        if (index >= 0) _demo[index] = updated;
      });
    }
  }

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween<double>(begin: .55, end: 1).animate(_pulse),
    child: ScaleTransition(
      scale: Tween<double>(begin: .8, end: 1.15).animate(_pulse),
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(color: _lime, shape: BoxShape.circle),
      ),
    ),
  );
}

class _EmptyPlayerSlot extends StatelessWidget {
  const _EmptyPlayerSlot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 23,
    height: 23,
    child: CustomPaint(
      painter: _DashedHexagonPainter(color),
      child: Center(child: Icon(Icons.add_rounded, size: 12, color: color)),
    ),
  );
}

class _DashedHexagonPainter extends CustomPainter {
  const _DashedHexagonPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final brush = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * .44;
    final points = List.generate(6, (index) {
      final angle = math.pi * (index / 3) - math.pi / 2;
      return Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
    });
    for (var index = 0; index < points.length; index++) {
      final next = points[(index + 1) % points.length];
      final start = Offset.lerp(points[index], next, .12)!;
      final end = Offset.lerp(points[index], next, .82)!;
      canvas.drawLine(start, end, brush);
    }
  }

  @override
  bool shouldRepaint(covariant _DashedHexagonPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _GameSymbolPainter extends CustomPainter {
  const _GameSymbolPainter({required this.game, required this.color});

  final String game;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final mark = game.toLowerCase();
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * .09
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final bounds = Offset.zero & size;

    if (mark.contains('overwatch')) {
      canvas.drawArc(
        bounds.deflate(size.width * .12),
        math.pi * .12,
        math.pi * 1.76,
        false,
        line,
      );
      final arrow = Path()
        ..moveTo(size.width * .31, size.height * .48)
        ..lineTo(size.width * .5, size.height * .68)
        ..lineTo(size.width * .69, size.height * .48);
      canvas.drawPath(arrow, line);
      return;
    }

    if (mark.contains('apex')) {
      final apex = Path()
        ..moveTo(size.width * .5, size.height * .12)
        ..lineTo(size.width * .88, size.height * .86)
        ..moveTo(size.width * .37, size.height * .86)
        ..lineTo(size.width * .5, size.height * .52)
        ..lineTo(size.width * .63, size.height * .86)
        ..moveTo(size.width * .43, size.height * .69)
        ..lineTo(size.width * .57, size.height * .69);
      canvas.drawPath(apex, line);
      return;
    }

    final shield = Path()
      ..moveTo(size.width * .5, size.height * .1)
      ..lineTo(size.width * .86, size.height * .25)
      ..lineTo(size.width * .8, size.height * .64)
      ..quadraticBezierTo(
        size.width * .7,
        size.height * .81,
        size.width * .5,
        size.height * .91,
      )
      ..quadraticBezierTo(
        size.width * .3,
        size.height * .81,
        size.width * .2,
        size.height * .64,
      )
      ..lineTo(size.width * .14, size.height * .25)
      ..close();
    canvas.drawPath(
      shield,
      Paint()
        ..color = color.withValues(alpha: .12)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(shield, line);
    final centerMark = Path()
      ..moveTo(size.width * .5, size.height * .31)
      ..lineTo(size.width * .56, size.height * .46)
      ..lineTo(size.width * .72, size.height * .47)
      ..lineTo(size.width * .6, size.height * .57)
      ..lineTo(size.width * .64, size.height * .72)
      ..lineTo(size.width * .5, size.height * .63)
      ..lineTo(size.width * .36, size.height * .72)
      ..lineTo(size.width * .4, size.height * .57)
      ..lineTo(size.width * .28, size.height * .47)
      ..lineTo(size.width * .44, size.height * .46)
      ..close();
    canvas.drawPath(
      centerMark,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _GameSymbolPainter oldDelegate) =>
      oldDelegate.game != game || oldDelegate.color != color;
}
