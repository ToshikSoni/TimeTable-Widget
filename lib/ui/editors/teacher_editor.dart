import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../app_scope.dart';
import '../widgets/common.dart';
import 'editor_scaffold.dart';

class TeacherEditor extends StatefulWidget {
  const TeacherEditor({super.key, this.teacher});
  final Teacher? teacher;

  @override
  State<TeacherEditor> createState() => _TeacherEditorState();
}

class _TeacherEditorState extends State<TeacherEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.teacher?.name);
  late final _code = TextEditingController(text: widget.teacher?.code);
  late final _email = TextEditingController(text: widget.teacher?.email);
  late final _phone = TextEditingController(text: widget.teacher?.phone);
  late final _notes = TextEditingController(text: widget.teacher?.notes);

  @override
  void dispose() {
    for (final c in [_name, _code, _email, _phone, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    String? clean(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    final t = Teacher(
      id: widget.teacher?.id,
      name: _name.text.trim(),
      code: _code.text.trim(),
      email: clean(_email),
      phone: clean(_phone),
      notes: clean(_notes),
    );
    context.readStore.upsertTeacher(t);
    Navigator.pop(context, t);
  }

  Future<void> _delete() async {
    final ok = await confirm(context, title: 'Delete ${widget.teacher!.displayName}?');
    if (!ok || !mounted) return;
    context.readStore.removeTeacher(widget.teacher!.id);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => EditorScaffold(
    title: widget.teacher == null ? 'New teacher' : 'Edit teacher',
    formKey: _form,
    onSave: _save,
    onDelete: widget.teacher == null ? null : _delete,
    children: [
      TextFormField(
        controller: _name,
        autofocus: widget.teacher == null,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Name',
          prefixIcon: Icon(Icons.person_outline_rounded),
        ),
        validator: (v) => (v == null || v.trim().isEmpty) && _code.text.trim().isEmpty
            ? 'Enter a name or initials'
            : null,
      ),
      TextField(
        controller: _code,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(
          labelText: 'Initials / code',
          hintText: 'e.g. KKH',
          prefixIcon: Icon(Icons.badge_outlined),
        ),
      ),
      TextField(
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(
          labelText: 'Email',
          prefixIcon: Icon(Icons.mail_outline_rounded),
        ),
      ),
      TextField(
        controller: _phone,
        keyboardType: TextInputType.phone,
        decoration: const InputDecoration(
          labelText: 'Phone',
          prefixIcon: Icon(Icons.call_outlined),
        ),
      ),
      TextField(
        controller: _notes,
        maxLines: 3,
        minLines: 1,
        decoration: const InputDecoration(
          labelText: 'Notes',
          hintText: 'Cabin, office hours…',
          prefixIcon: Icon(Icons.notes_rounded),
        ),
      ),
    ],
  );
}
