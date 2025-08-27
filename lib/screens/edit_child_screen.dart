import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/children_service.dart';

class EditChildScreen extends StatefulWidget {
  final String? childId; // if null => add mode
  final Map<String, dynamic>? initial;

  const EditChildScreen({super.key, this.childId, this.initial});

  @override
  State<EditChildScreen> createState() => _EditChildScreenState();
}

class _EditChildScreenState extends State<EditChildScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _avatar = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _name.text = (widget.initial!['name'] ?? '').toString();
      final ageVal = widget.initial!['age'];
      _age.text = (ageVal is int) ? ageVal.toString() : (ageVal ?? '').toString();
      _avatar.text = (widget.initial!['avatar'] ?? '').toString();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _avatar.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _saving = true);
    try {
      final ageInt = int.tryParse(_age.text.trim()) ?? 0;

      if (widget.childId == null) {
        // Add
        await ChildrenService.addChild(
          uid: uid,
          name: _name.text.trim(),
          age: ageInt,
          avatar: _avatar.text.trim().isEmpty ? null : _avatar.text.trim(),
          setActive: true, // first child becomes active
        );
      } else {
        // Update
        await ChildrenService.updateChild(
          uid: uid,
          childId: widget.childId!,
          name: _name.text.trim(),
          age: ageInt,
          avatar: _avatar.text.trim().isEmpty ? null : _avatar.text.trim(),
        );
      }

      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.childId != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit child' : 'Add child')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Form(
                      key: _form,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextFormField(
                            controller: _name,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Name',
                              prefixIcon: Icon(Icons.person),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Enter a name'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _age,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Age',
                              prefixIcon: Icon(Icons.cake_outlined),
                            ),
                            validator: (v) {
                              final n = int.tryParse(v ?? '');
                              if (n == null || n <= 0) return 'Enter a valid age';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _avatar,
                            textInputAction: TextInputAction.done,
                            decoration: const InputDecoration(
                              labelText: 'Avatar (emoji optional, e.g., 🦊)',
                              prefixIcon: Icon(Icons.emoji_emotions_outlined),
                            ),
                            onFieldSubmitted: (_) => _save(),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _saving ? null : _save,
                              child: _saving
                                  ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                                  : Text(isEdit ? 'Save changes' : 'Add child'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
