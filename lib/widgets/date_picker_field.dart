import 'package:flutter/material.dart';
import '../utils/date_utils.dart' as du;

class DatePickerField extends StatefulWidget {
  final TextEditingController? controller;
  final String? initialValue;
  final ValueChanged<String>? onChanged;
  final InputDecoration? decoration;
  final double? height;

  const DatePickerField({
    super.key,
    this.controller,
    this.initialValue,
    this.onChanged,
    this.decoration,
    this.height,
  });

  @override
  State<DatePickerField> createState() => _DatePickerFieldState();
}

class _DatePickerFieldState extends State<DatePickerField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    if (widget.initialValue != null) {
      _controller.text = widget.initialValue!;
    }
  }

  @override
  void didUpdateWidget(DatePickerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller &&
        widget.controller != null) {
      _controller = widget.controller!;
    }
    if (widget.initialValue != oldWidget.initialValue &&
        widget.initialValue != null &&
        widget.controller == null) {
      _controller.text = widget.initialValue!;
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    DateTime? initial;
    if (_controller.text.isNotEmpty) {
      initial = du.parseDate(_controller.text);
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      final formatted = du.formatDate(picked);
      if (_controller.text != formatted) {
        _controller.text = formatted;
        widget.onChanged?.call(formatted);
      }
    }
  }

  void _clear() {
    if (_controller.text.isNotEmpty) {
      _controller.clear();
      widget.onChanged?.call('');
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final hasValue = _controller.text.isNotEmpty;
        return TextField(
          controller: _controller,
          readOnly: true,
          canRequestFocus: false,
          onTap: _pickDate,
          decoration: (widget.decoration ?? const InputDecoration()).copyWith(
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasValue)
                  InkWell(
                    onTap: _clear,
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(Icons.clear, size: 18),
                    ),
                  ),
                InkWell(
                  onTap: _pickDate,
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Icons.calendar_today, size: 18),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (widget.height != null) {
      return SizedBox(height: widget.height, child: child);
    }
    return child;
  }
}
