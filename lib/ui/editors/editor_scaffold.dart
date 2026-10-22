import 'package:flutter/material.dart';

import '../theme.dart';

/// Shared chrome for editors: title bar with close/save and a scrollable
/// form body. Works both as a dialog and as a full-screen page.
class EditorScaffold extends StatelessWidget {
  const EditorScaffold({
    super.key,
    required this.title,
    required this.children,
    required this.onSave,
    this.onDelete,
    this.saveLabel = 'Save',
    this.formKey,
  });

  final String title;
  final List<Widget> children;
  final VoidCallback? onSave;
  final VoidCallback? onDelete;
  final String saveLabel;
  final GlobalKey<FormState>? formKey;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.colors.surfaceContainerLow,
    appBar: AppBar(
      backgroundColor: context.colors.surfaceContainerLow,
      leading: IconButton(
        tooltip: 'Close',
        icon: const Icon(Icons.close_rounded),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(title),
      actions: [
        if (onDelete != null)
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: onDelete,
          ),
        Padding(
          padding: const EdgeInsets.only(right: 12, left: 4),
          child: FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(72, 40)),
            onPressed: onSave,
            child: Text(saveLabel),
          ),
        ),
      ],
    ),
    body: Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          for (final c in children) ...[c, const SizedBox(height: 14)],
        ],
      ),
    ),
  );
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
    child: Text(
      text,
      style: context.text.labelLarge?.copyWith(color: context.colors.onSurfaceVariant),
    ),
  );
}

/// A tappable field that shows a value and opens a picker.
class PickerField extends StatelessWidget {
  const PickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.icon,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(14),
    onTap: onTap,
    child: InputDecorator(
      decoration: InputDecoration(labelText: label, prefixIcon: icon == null ? null : Icon(icon)),
      child: Text(value, style: context.text.bodyLarge?.copyWith(fontFeatures: tabular)),
    ),
  );
}
