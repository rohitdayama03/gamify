import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Small uppercase section header, e.g. "STAGES".
class SectionLabel extends StatelessWidget {
  final String text;

  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Text(text, style: AppFonts.label()),
      );
}

/// One-of-several choice as a row of chips, styled like the app's other filters.
class ChoiceRow<T> extends StatelessWidget {
  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onSelected;

  const ChoiceRow({super.key, required this.options, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final (value, label) in options)
          ChoiceChip(
            label: Text(label),
            selected: value == selected,
            onSelected: (_) => onSelected(value),
            showCheckmark: false,
            selectedColor: AppColors.primary,
            labelStyle: AppTheme.chipLabel(value == selected),
          ),
      ],
    );
  }
}

/// "Label    [-]  4  [+]"
class CountStepper extends StatelessWidget {
  final String label;
  final String? hint;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const CountStepper({
    super.key,
    required this.label,
    this.hint,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label),
              if (hint != null) Text(hint!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Fewer',
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        SizedBox(
          width: 32,
          child: Text('$value', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ),
        IconButton(
          tooltip: 'More',
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}

/// A bordered card used for stages, matches and tables.
class OutlineCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;

  const OutlineCard({super.key, required this.child, this.padding = const EdgeInsets.all(AppSpacing.sm), this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: borderColor ?? AppColors.border),
      ),
      child: child,
    );
  }
}
