import 'package:flutter/material.dart';
import 'package:watch_verse/l10n/app_localizations.dart';

/// Shows a single-field text dialog and returns the trimmed value (or null on
/// cancel). The controller lives inside a StatefulWidget so it is disposed only
/// after the dialog's exit animation completes — disposing a controller right
/// after `await showDialog` while the route is still animating is what triggers
/// the `_dependents.isEmpty` / "wrong build scope" crash.
Future<String?> promptForText(
  BuildContext context, {
  required String title,
  String hint = '',
  String initial = '',
  String? actionLabel,
  TextInputType? keyboardType,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _TextPromptDialog(
      title: title,
      hint: hint,
      initial: initial,
      actionLabel: actionLabel,
      keyboardType: keyboardType,
    ),
  );
}

class _TextPromptDialog extends StatefulWidget {
  final String title;
  final String hint;
  final String initial;
  final String? actionLabel;
  final TextInputType? keyboardType;

  const _TextPromptDialog({
    required this.title,
    required this.hint,
    required this.initial,
    required this.actionLabel,
    this.keyboardType,
  });

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: widget.keyboardType,
        decoration: InputDecoration(hintText: widget.hint),
        onSubmitted: (v) => Navigator.pop(context, v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text(widget.actionLabel ?? l10n.save),
        ),
      ],
    );
  }
}
