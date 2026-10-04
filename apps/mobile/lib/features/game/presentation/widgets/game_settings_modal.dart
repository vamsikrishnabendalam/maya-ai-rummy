import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../models/game_settings.dart';

/// Interactive modal allowing players to configure First Drop, Middle Drop, Full Count, and Elimination Score.
class GameSettingsModal extends StatefulWidget {
  final GameSettings currentSettings;
  final ValueChanged<GameSettings> onSave;
  final VoidCallback onClose;

  const GameSettingsModal({
    super.key,
    required this.currentSettings,
    required this.onSave,
    required this.onClose,
  });

  @override
  State<GameSettingsModal> createState() => _GameSettingsModalState();
}

class _GameSettingsModalState extends State<GameSettingsModal> {
  late int _firstDrop;
  late int _middleDrop;
  late int _fullCount;
  late int _eliminationScore;

  @override
  void initState() {
    super.initState();
    _firstDrop = widget.currentSettings.firstDropPenalty;
    _middleDrop = widget.currentSettings.middleDropPenalty;
    _fullCount = widget.currentSettings.fullCountPenalty;
    _eliminationScore = widget.currentSettings.eliminationScore;
  }

  void _resetDefaults() {
    setState(() {
      _firstDrop = 20;
      _middleDrop = 40;
      _fullCount = 80;
      _eliminationScore = 201;
    });
  }

  void _saveAndClose() {
    widget.onSave(GameSettings(
      firstDropPenalty: _firstDrop,
      middleDropPenalty: _middleDrop,
      fullCountPenalty: _fullCount,
      eliminationScore: _eliminationScore,
    ));
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 580),
        decoration: BoxDecoration(
          color: const Color(0xFF141E18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.glassBorder, width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.glassBorder)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.settings_outlined, color: AppColors.accent, size: 22),
                  const SizedBox(width: 10),
                  const Text(
                    'GAME SETTINGS',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textMuted),
                    onPressed: widget.onClose,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Settings Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildSettingRow(
                    title: 'First Drop Penalty',
                    subtitle: 'Points added when dropping on your first turn',
                    value: _firstDrop,
                    min: 5,
                    max: 100,
                    step: 5,
                    onChanged: (val) => setState(() => _firstDrop = val),
                  ),
                  const Divider(color: AppColors.glassBorder, height: 28),
                  _buildSettingRow(
                    title: 'Middle Drop Penalty',
                    subtitle: 'Points added when dropping after the first turn',
                    value: _middleDrop,
                    min: 10,
                    max: 120,
                    step: 5,
                    onChanged: (val) => setState(() => _middleDrop = val),
                  ),
                  const Divider(color: AppColors.glassBorder, height: 28),
                  _buildSettingRow(
                    title: 'Full Count / Invalid Show',
                    subtitle: 'Penalty applied for invalid declaration or max hand points',
                    value: _fullCount,
                    min: 40,
                    max: 160,
                    step: 10,
                    onChanged: (val) => setState(() => _fullCount = val),
                  ),
                  const Divider(color: AppColors.glassBorder, height: 28),
                  _buildSettingRow(
                    title: 'Elimination Score',
                    subtitle: 'Player is eliminated when score exceeds ${_eliminationScore - 1} pts',
                    value: _eliminationScore,
                    min: 51,
                    max: 501,
                    step: 10,
                    quickOptions: const [101, 201, 301],
                    onChanged: (val) => setState(() => _eliminationScore = val),
                  ),
                ],
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.glassBorder)),
              ),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _resetDefaults,
                    child: const Text(
                      'Reset to Defaults',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _saveAndClose,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Save & Apply', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingRow({
    required String title,
    required String subtitle,
    required int value,
    required int min,
    required int max,
    required int step,
    required ValueChanged<int> onChanged,
    List<int>? quickOptions,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: AppColors.glass,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove, size: 16, color: AppColors.accent),
                    onPressed: value > min ? () => onChanged(value - step) : null,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                  ),
                  Container(
                    constraints: const BoxConstraints(minWidth: 44),
                    alignment: Alignment.center,
                    child: Text(
                      '$value',
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, size: 16, color: AppColors.accent),
                    onPressed: value < max ? () => onChanged(value + step) : null,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ],
        ),
        if (quickOptions != null) ...[
          const SizedBox(height: 8),
          Row(
            children: quickOptions.map((opt) {
              final isSelected = value == opt;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('$opt Pool'),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) onChanged(opt);
                  },
                  selectedColor: AppColors.accent.withValues(alpha: 0.25),
                  backgroundColor: AppColors.glass,
                  labelStyle: TextStyle(
                    color: isSelected ? AppColors.accent : AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: isSelected ? AppColors.accent : AppColors.glassBorder,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
