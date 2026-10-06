import 'package:flutter/material.dart';

/// Asks for a number of minutes, and validates the range before returning.
///
/// Shared by the two screens that let the user type a length — the schedule form
/// and the focus setup screen — so both refuse the same values with the same
/// sentence. The dialog owns its `TextEditingController`: disposing it in the
/// caller as soon as `showDialog` returns leaves the field listening to a
/// disposed controller while the dialog is still animating out, which throws.
///
/// Returns the chosen minutes, or null when the user cancelled or typed
/// something outside [min]..[max]. Out of range is refused rather than clamped —
/// silently turning "0" into 1 minute, or "9999" into 600, saves a value the user
/// did not ask for.
Future<int?> showCustomMinutesDialog(
  BuildContext context, {
  required int initialMinutes,
  required String outOfRangeMessage,
  String title = '自定义时长',
  int min = 1,
  int max = 600,
}) {
  return showDialog<int>(
    context: context,
    builder: (_) => _CustomMinutesDialog(
      initialMinutes: initialMinutes,
      outOfRangeMessage: outOfRangeMessage,
      title: title,
      min: min,
      max: max,
    ),
  );
}

class _CustomMinutesDialog extends StatefulWidget {
  final int initialMinutes;
  final String outOfRangeMessage;
  final String title;
  final int min;
  final int max;

  const _CustomMinutesDialog({
    required this.initialMinutes,
    required this.outOfRangeMessage,
    required this.title,
    required this.min,
    required this.max,
  });

  @override
  State<_CustomMinutesDialog> createState() => _CustomMinutesDialogState();
}

class _CustomMinutesDialogState extends State<_CustomMinutesDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialMinutes.toString());
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final minutes = int.tryParse(_controller.text.trim());
    if (minutes == null || minutes < widget.min || minutes > widget.max) {
      // Shown in the dialog rather than returned, so the user can correct the
      // number instead of starting over.
      setState(() => _error = widget.outOfRangeMessage);
      return;
    }
    Navigator.of(context).pop(minutes);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: '分钟',
          helperText: '${widget.min} 到 ${widget.max} 分钟',
          errorText: _error,
        ),
        onSubmitted: (_) => _confirm(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(onPressed: _confirm, child: const Text('确定')),
      ],
    );
  }
}
