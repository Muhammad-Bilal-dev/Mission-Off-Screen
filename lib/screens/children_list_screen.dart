import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChildrenListScreen extends StatelessWidget {
  const ChildrenListScreen({super.key});

  CollectionReference<Map<String, dynamic>> _childrenCol() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('children');
  }

  Future<void> _addChild(BuildContext context) async {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: const Text('Add child'),
          content: TextField(
            controller: c,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Name'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Add')),
          ],
        );
      },
    );
    if (name == null || name.isEmpty) return;
    await _childrenCol().add({'name': name, 'createdAt': FieldValue.serverTimestamp()});
  }

  Future<void> _setActive(DocumentSnapshot<Map<String, dynamic>> child) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'activeChildId': child.id,
      'activeChildName': child['name'] ?? '',
    });
  }

  Future<void> _delete(DocumentSnapshot<Map<String, dynamic>> child) async {
    await child.reference.delete();
  }

  @override
  Widget build(BuildContext context) {
    final col = _childrenCol();
    return Scaffold(
      appBar: AppBar(title: const Text('My Family')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addChild(context),
        label: const Text('Add'),
        icon: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: col.orderBy('createdAt', descending: false).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No children yet.'));
          }
          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (context, i) {
              final d = docs[i];
              final name = (d['name'] as String?) ?? 'Unnamed';
              return ListTile(
                leading: CircleAvatar(child: Text(name[0].toUpperCase())),
                title: Text(name),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'active') _setActive(d);
                    if (v == 'delete') _delete(d);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'active', child: Text('Set active')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
