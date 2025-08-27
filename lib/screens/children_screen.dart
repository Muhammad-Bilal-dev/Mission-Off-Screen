// lib/screens/children_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChildrenScreen extends StatelessWidget {
  const ChildrenScreen({super.key});

  String _initials(String name) {
    final n = name.trim();
    if (n.isEmpty) return 'N';
    final parts = n.split(' ');
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final children =
    FirebaseFirestore.instance.collection('users').doc(uid).collection('children').orderBy('createdAt');

    Future<void> _addChild() async {
      final controller = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Add child'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Name'),
            autofocus: true,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
          ],
        ),
      );
      if (ok != true) return;
      final name = controller.text.trim();
      if (name.isEmpty) return;

      final doc = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('children')
          .doc();
      await doc.set({
        'name': name,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // set active if none
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if ((userDoc.data()?['activeChildId'] as String?)?.isEmpty ?? true) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'activeChildId': doc.id,
          'activeChildName': name,
        });
      }
    }

    Future<void> _setActive(String id, String name) async {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'activeChildId': id,
        'activeChildName': name,
      });
      if (context.mounted) Navigator.pop(context);
    }

    Future<void> _delete(String id) async {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('children')
          .doc(id)
          .delete();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Family')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addChild,
        icon: const Icon(Icons.add),
        label: const Text('Add child'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: children.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemBuilder: (_, i) {
              final d = docs[i];
              final name = (d['name'] as String?) ?? '';
              return ListTile(
                leading: CircleAvatar(child: Text(_initials(name))),
                title: Text(name.isEmpty ? 'Unnamed' : name),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'active') _setActive(d.id, name);
                    if (v == 'delete') _delete(d.id);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'active', child: Text('Set active')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              );
            },
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemCount: docs.length,
          );
        },
      ),
    );
  }
}
