import 'package:flutter/material.dart';
import '../core/constants/form_options.dart';

/// Searchable country drop-down: tap to open the list, or type to filter it.
class CountryDropdown extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  final String label;

  const CountryDropdown({super.key, required this.value, required this.onChanged, this.label = 'Country'});

  @override
  Widget build(BuildContext context) {
    // Keep a value saved before this list existed selectable instead of showing it blank
    final countries = value == null || FormOptions.countries.contains(value)
        ? FormOptions.countries
        : [value!, ...FormOptions.countries];

    return DropdownMenu<String>(
      initialSelection: value,
      onSelected: onChanged,
      expandedInsets: EdgeInsets.zero,
      menuHeight: 300,
      enableFilter: true,
      requestFocusOnTap: true,
      label: Text(label),
      leadingIcon: const Icon(Icons.public),
      dropdownMenuEntries: [
        for (final country in countries) DropdownMenuEntry(value: country, label: country),
      ],
    );
  }
}
