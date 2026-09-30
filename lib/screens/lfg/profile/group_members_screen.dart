import 'package:flutter/material.dart';

class GroupMembersScreen extends StatelessWidget {
  const GroupMembersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ข้อมูลสมาชิกผู้พัฒนา')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildMemberCard(
              'นาย สมาชิกคนที่ 1',
              'รหัสนิสิต: 65XXXXXXXX',
              'หน้าที่: Frontend & Firebase',
            ),
            const SizedBox(height: 12),
            _buildMemberCard(
              'นาย สมาชิกคนที่ 2',
              'รหัสนิสิต: 65XXXXXXXX',
              'หน้าที่: External API & UI Design',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberCard(String name, String id, String role) {
    return Card(
      elevation: 4,
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person)),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('$id\n$role'),
      ),
    );
  }
}
