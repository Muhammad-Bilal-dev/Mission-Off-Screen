import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChildrenManager extends StatefulWidget {
  const ChildrenManager({super.key});

  @override
  State<ChildrenManager> createState() => _ChildrenManagerState();
}

class _ChildrenManagerState extends State<ChildrenManager> {
  final _name = TextEditingController();
  bool _busy = false;

  CollectionReference<Map<String, dynamic>> _col() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance.collection('users').doc(uid).collection('children');
  }

  DocumentReference<Map<String, dynamic>> _user() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance.collection('users').doc(uid);
  }

  Future<void> _add() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final doc = await _col().add({
        'name': _name.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      // set as active if none active yet
      final u = await _user().get();
      if ((u.data()?['activeChildId'] ?? '') == '') {
        await _user().update({
          'activeChildId': doc.id,
          'activeChildName': _name.text.trim(),
        });
      }
      _name.clear();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _makeActive(String id, String name) async {
    await _user().update({
      'activeChildId': id,
      'activeChildName': name,
    });
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Children')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'Child name',
                      prefixIcon: Icon(Icons.child_care),
                    ),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _busy ? null : _add,
                  child: _busy
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Add'),
                ),
              ],
            ),
          ),
          const Divider(height: 0),
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
              builder: (context, userSnap) {
                final activeId = userSnap.data?.data()?['activeChildId'] ?? '';
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _col().orderBy('createdAt', descending: true).snapshots(),
                  builder: (context, snap) {
                    final docs = snap.data?.docs ?? const [];
                    if (docs.isEmpty) {
                      return const Center(child: Text('No children yet. Add one above.'));
                    }
                    return ListView.separated(
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const Divider(height: 0),
                      itemBuilder: (_, i) {
                        final d = docs[i];
                        final name = d.data()['name'] ?? '';
                        final isActive = activeId == d.id;
                        return ListTile(
                          leading: CircleAvatar(child: Text(name.isEmpty ? '?' : name[0].toUpperCase())),
                          title: Text(name),
                          trailing: isActive
                              ? const Chip(label: Text('Active'))
                              : OutlinedButton(
                            onPressed: () => _makeActive(d.id, name),
                            child: const Text('Set active'),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
