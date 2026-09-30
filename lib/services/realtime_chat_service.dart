import 'package:firebase_database/firebase_database.dart';

class RealtimeChatService {
  FirebaseDatabase get _db => FirebaseDatabase.instance;

  // ส่งข้อความเข้าห้องแชท
  Future sendMessage(String partyId, String sender, String message) async {
    await _db.ref('chats/$partyId').push().set({
      'sender': sender,
      'message': message,
      'timestamp': ServerValue.timestamp,
    });
  }

  // ฟังข้อความแบบ Realtime
  Stream<DatabaseEvent> getChatMessages(String partyId) {
    return _db.ref('chats/$partyId').orderByChild('timestamp').onValue;
  }
}
