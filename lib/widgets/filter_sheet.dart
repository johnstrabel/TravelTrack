// lib/widgets/filter_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/filter_mode.dart';

class FilterSheet extends StatelessWidget {
  final FilterMode currentMode;
  final Function(FilterMode) onModeSelected;

  const FilterSheet({
    super.key,
    required this.currentMode,
    required this.onModeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Row(
                children: [
                  const Text('🗺️', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Map View',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                        Text(
                          'Choose how to view your travels',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Filter options
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  _FilterOption(
                    mode: FilterMode.visited,
                    isSelected: currentMode == FilterMode.visited,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onModeSelected(FilterMode.visited);
                      Navigator.pop(context);
                    },
                  ),
                  _FilterOption(
                    mode: FilterMode.trips,
                    isSelected: currentMode == FilterMode.trips,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onModeSelected(FilterMode.trips);
                      Navigator.pop(context);
                    },
                  ),
                  _FilterOption(
                    mode: FilterMode.years,
                    isSelected: currentMode == FilterMode.years,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onModeSelected(FilterMode.years);
                      Navigator.pop(context);
                    },
                  ),
                  _FilterOption(
                    mode: FilterMode.bucketList,
                    isSelected: currentMode == FilterMode.bucketList,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onModeSelected(FilterMode.bucketList);
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _FilterOption extends StatelessWidget {
  final FilterMode mode;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterOption({
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF5B7C99).withOpacity(0.1) : null,
          border: Border(
            left: BorderSide(
              color: isSelected ? const Color(0xFF5B7C99) : Colors.transparent,
              width: 4,
            ),
          ),
        ),
        child: Row(
          children: [
            // Emoji
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF5B7C99).withOpacity(0.2)
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(mode.emoji, style: const TextStyle(fontSize: 24)),
            ),

            const SizedBox(width: 16),

            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode.displayName,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: isSelected
                          ? const Color(0xFF5B7C99)
                          : const Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    mode.description,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),

            // Checkmark
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFF5B7C99),
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}
