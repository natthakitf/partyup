import 'dart:ui';

import 'package:flutter/material.dart';

import '../../models/esports_team_model.dart';
import '../../models/party_model.dart';

const _purple = Color(0xFF7C3AED);
const _grey = Color(0xFF858894);
const _games = [
  'VALORANT',
  'League of Legends',
  'Overwatch 2',
  'Apex Legends',
  'Counter-Strike 2',
  'PUBG',
];

class PartyForm extends StatefulWidget {
  const PartyForm({super.key, this.party});
  final PartyModel? party;
  @override
  State<PartyForm> createState() => _PartyFormState();
}

class _PartyFormState extends State<PartyForm> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.party?.title ?? '');
  late final _rank = TextEditingController(
    text: widget.party?.requiredRank ?? 'ทุกแรงค์',
  );
  late final _time = TextEditingController(
    text: widget.party?.playTime ?? 'คืนนี้ 20:00',
  );
  late final _style = TextEditingController(
    text: widget.party?.playStyle ?? 'เล่นสนุก ไม่ toxic',
  );
  late String _game = widget.party?.gameName ?? _games.first;
  @override
  void dispose() {
    _title.dispose();
    _rank.dispose();
    _time.dispose();
    _style.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      top: 55,
      bottom: MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xE6161B26)
                : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0x1FFFFFFF)
                  : const Color(0x0A000000),
            ),
          ),
          child: SafeArea(
            child: Form(
              key: _form,
              child: ListView(
                shrinkWrap: true,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD8D9DE),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 17),
                  Text(
                    widget.party == null ? 'สร้างปาร์ตี้ใหม่' : 'แก้ไขปาร์ตี้',
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    initialValue: _game,
                    decoration: const InputDecoration(labelText: 'เกม'),
                    items: _games
                        .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                        .toList(),
                    onChanged: (v) => setState(() => _game = v ?? _game),
                  ),
                  _input(_title, 'ชื่อปาร์ตี้'),
                  _input(_rank, 'แรงค์ที่ต้องการ'),
                  _input(_style, 'สไตล์การเล่น'),
                  _input(_time, 'เวลาที่สะดวก'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () {
                      if (!_form.currentState!.validate()) return;
                      final old = widget.party;
                      Navigator.pop(
                        context,
                        PartyModel(
                          id:
                              old?.id ??
                              DateTime.now().microsecondsSinceEpoch.toString(),
                          title: _title.text.trim(),
                          gameName: _game,
                          requiredRank: _rank.text.trim(),
                          playStyle: _style.text.trim(),
                          playTime: _time.text.trim(),
                          maxPlayers:
                              old?.maxPlayers ??
                              (_game == 'Apex Legends' ? 3 : 5),
                          currentPlayers: old?.currentPlayers ?? 1,
                          createdBy: old?.createdBy ?? 'คุณ',
                          createdAt: old?.createdAt ?? DateTime.now(),
                          isActive: old?.isActive ?? true,
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: _purple,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('บันทึกปาร์ตี้'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  Widget _input(TextEditingController c, String label) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: TextFormField(
      controller: c,
      validator: (v) =>
          v == null || v.trim().isEmpty ? 'กรุณากรอก$label' : null,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}

class EsportsTeamForm extends StatefulWidget {
  const EsportsTeamForm({super.key, this.team});
  final EsportsTeamModel? team;
  @override
  State<EsportsTeamForm> createState() => _EsportsTeamFormState();
}

class _EsportsTeamFormState extends State<EsportsTeamForm> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.team?.title ?? '');
  late final _rank = TextEditingController(
    text: widget.team?.requiredRank ?? 'Diamond+',
  );
  late final _role = TextEditingController(text: widget.team?.role ?? 'Flex');
  late final _style = TextEditingController(
    text: widget.team?.playStyle ?? 'ซ้อมทีมและลงแข่ง',
  );
  late final _time = TextEditingController(
    text: widget.team?.practiceTime ?? 'จ.-พฤ. 20:00',
  );
  late String _game = widget.team?.gameName ?? _games.first;
  @override
  void dispose() {
    _title.dispose();
    _rank.dispose();
    _role.dispose();
    _style.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      top: 45,
      bottom: MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xE6161B26)
                : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0x1FFFFFFF)
                  : const Color(0x0A000000),
            ),
          ),
          child: SafeArea(
            child: Form(
              key: _form,
              child: ListView(
                shrinkWrap: true,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD8D9DE),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 17),
                  Text(
                    widget.team == null
                        ? 'ประกาศรับสมาชิกทีม eSports'
                        : 'แก้ไขประกาศทีม',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'สำหรับทีมที่กำลังหาผู้เล่นเข้าร่วมซ้อมหรือลงแข่ง',
                    style: TextStyle(fontSize: 11, color: _grey),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _game,
                    decoration: const InputDecoration(
                      labelText: 'เกมที่แข่งขัน',
                    ),
                    items: _games
                        .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                        .toList(),
                    onChanged: (v) => setState(() => _game = v ?? _game),
                  ),
                  _field(_title, 'ชื่อทีม / ประกาศรับสมาชิก'),
                  _field(_rank, 'แรงค์ขั้นต่ำ'),
                  _field(_role, 'ตำแหน่งที่ต้องการ'),
                  _field(_style, 'สไตล์ทีม / เป้าหมาย'),
                  _field(_time, 'เวลาซ้อมประจำ'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () {
                      if (!_form.currentState!.validate()) return;
                      final old = widget.team;
                      Navigator.pop(
                        context,
                        EsportsTeamModel(
                          id:
                              old?.id ??
                              DateTime.now().microsecondsSinceEpoch.toString(),
                          title: _title.text.trim(),
                          gameName: _game,
                          requiredRank: _rank.text.trim(),
                          role: _role.text.trim(),
                          playStyle: _style.text.trim(),
                          practiceTime: _time.text.trim(),
                          maxPlayers:
                              old?.maxPlayers ??
                              (_game == 'Apex Legends' ? 3 : 5),
                          currentPlayers: old?.currentPlayers ?? 1,
                          createdBy: old?.createdBy ?? 'คุณ',
                          createdAt: old?.createdAt ?? DateTime.now(),
                          isActive: old?.isActive ?? true,
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: _purple,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('โพสต์รับสมาชิก'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _field(TextEditingController controller, String label) => Padding(
    padding: const EdgeInsets.only(top: 9),
    child: TextFormField(
      controller: controller,
      validator: (value) =>
          value == null || value.trim().isEmpty ? 'กรุณากรอก$label' : null,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}
