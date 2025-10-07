// lib/widgets/country_status_modal.dart
import 'package:flutter/material.dart';
import '../models/country_status.dart';
import '../data/countries.dart';

class CountryStatusModal extends StatelessWidget {
  final String countryCode;
  final String countryName;
  final CountryStatus? currentStatus;
  final Function(CountryStatus?) onStatusSelected;

  const CountryStatusModal({
    super.key,
    required this.countryCode,
    required this.countryName,
    required this.currentStatus,
    required this.onStatusSelected,
  });

  @override
  Widget build(BuildContext context) {
    final flag = CountriesData.getFlagEmoji(countryCode);

    return Container(
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
                  Text(
                    flag,
                    style: const TextStyle(fontSize: 32),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          countryName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                        Text(
                          'Select your status',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Status options
            _StatusOption(
              status: CountryStatus.want,
              label: 'Want to Visit',
              emoji: '🔴',
              description: 'Countries on your bucket list',
              isSelected: currentStatus == CountryStatus.want,
              onTap: () {
                onStatusSelected(CountryStatus.want);
                Navigator.pop(context);
              },
            ),

            _StatusOption(
              status: CountryStatus.been,
              label: 'Been There',
              emoji: '🟢',
              description: 'Countries you\'ve visited',
              isSelected: currentStatus == CountryStatus.been,
              onTap: () {
                onStatusSelected(CountryStatus.been);
                Navigator.pop(context);
              },
            ),

            _StatusOption(
              status: CountryStatus.lived,
              label: 'Lived There',
              emoji: '🟡',
              description: 'Countries where you\'ve lived',
              isSelected: currentStatus == CountryStatus.lived,
              onTap: () {
                onStatusSelected(CountryStatus.lived);
                Navigator.pop(context);
              },
            ),

            _StatusOption(
              status: CountryStatus.live,
              label: 'Living Here',
              emoji: '🔵',
              description: 'Your current country',
              isSelected: currentStatus == CountryStatus.live,
              onTap: () {
                onStatusSelected(CountryStatus.live);
                Navigator.pop(context);
              },
            ),

            // Remove status option
            if (currentStatus != null)
              _StatusOption(
                status: null,
                label: 'Remove Status',
                emoji: '❌',
                description: 'Clear this country\'s status',
                isSelected: false,
                onTap: () {
                  onStatusSelected(null);
                  Navigator.pop(context);
                },
              ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _StatusOption extends StatelessWidget {
  final CountryStatus? status;
  final String label;
  final String emoji;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatusOption({
    required this.status,
    required this.label,
    required this.emoji,
    required this.description,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
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
              Text(
                emoji,
                style: const TextStyle(fontSize: 28),
              ),
              const SizedBox(width: 16),

              // Label and description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? const Color(0xFF5B7C99)
                            : const Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              // Checkmark for selected
              if (isSelected)
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFF5B7C99),
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }
}