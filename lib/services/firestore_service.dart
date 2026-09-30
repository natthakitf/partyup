import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/esports_team_model.dart';
import '../models/party_model.dart';

class FirestoreService {
  // ประกาศรับสมาชิกสำหรับทีม eSports
  CollectionReference<Map<String, dynamic>> get _teamCollection =>
      FirebaseFirestore.instance.collection('esports_teams');

  // ปาร์ตี้สำหรับนัดเล่นเกมทั่วไป
  CollectionReference<Map<String, dynamic>> get _partyCollection =>
      FirebaseFirestore.instance.collection('parties');

  Future<String> createTeam(EsportsTeamModel team) async {
    final document = await _teamCollection.add(team.toMap());
    return document.id;
  }

  Stream<List<EsportsTeamModel>> getTeams() {
    return _teamCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((document) {
            return EsportsTeamModel.fromMap(document.id, document.data());
          }).toList();
        });
  }

  Future<void> updateTeam(EsportsTeamModel team) {
    return _teamCollection.doc(team.id).update(team.toMap());
  }

  Future<void> deleteTeam(String teamId) {
    return _teamCollection.doc(teamId).delete();
  }

  Future<String> createParty(PartyModel party) async {
    final document = await _partyCollection.add(party.toMap());
    return document.id;
  }

  Stream<List<PartyModel>> getParties() {
    return _partyCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((document) {
            return PartyModel.fromMap(document.id, document.data());
          }).toList();
        });
  }

  Future<void> updateParty(PartyModel party) {
    return _partyCollection.doc(party.id).update(party.toMap());
  }

  Future<void> deleteParty(String partyId) {
    return _partyCollection.doc(partyId).delete();
  }
}
