import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

/// A text field that suggests [options] as you type; each pick becomes a removable chip.
class MultiSelectAutocomplete extends StatefulWidget {
  final String label;
  final List<String> options;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  final int? maxSelections;

  const MultiSelectAutocomplete({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.maxSelections,
  });

  @override
  State<MultiSelectAutocomplete> createState() => _MultiSelectAutocompleteState();
}

class _MultiSelectAutocompleteState extends State<MultiSelectAutocomplete> {
  TextEditingController? _fieldController;

  bool get _isFull => widget.maxSelections != null && widget.selected.length >= widget.maxSelections!;

  bool _isSelected(String option) =>
      widget.selected.any((s) => s.toLowerCase() == option.toLowerCase());

  void _add(String option) {
    if (!_isSelected(option) && !_isFull) {
      widget.onChanged([...widget.selected, option]);
    }
    // Autocomplete writes the picked option into the field; clear it for the next entry
    WidgetsBinding.instance.addPostFrameCallback((_) => _fieldController?.clear());
  }

  void _remove(String option) {
    widget.onChanged(widget.selected.where((s) => s != option).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Autocomplete<String>(
          optionsBuilder: (value) {
            final query = value.text.trim().toLowerCase();
            if (query.isEmpty || _isFull) return const Iterable<String>.empty();
            return widget.options.where((o) => !_isSelected(o) && o.toLowerCase().contains(query));
          },
          onSelected: _add,
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            _fieldController = controller;
            return TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: !_isFull,
              onSubmitted: (text) {
                // Accept a typed value only when it exactly matches an option
                final match = widget.options.where((o) => o.toLowerCase() == text.trim().toLowerCase());
                if (match.isNotEmpty) _add(match.first);
              },
              decoration: InputDecoration(
                labelText: widget.label,
                hintText: _isFull ? 'Maximum ${widget.maxSelections} selected' : 'Start typing to search',
                border: const OutlineInputBorder(),
                suffixIcon: const Icon(Icons.search),
              ),
            );
          },
        ),
        if (widget.selected.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final option in widget.selected)
                InputChip(
                  label: Text(option),
                  onDeleted: () => _remove(option),
                  backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                  side: const BorderSide(color: AppColors.primary),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
