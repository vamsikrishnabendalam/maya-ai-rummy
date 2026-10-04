import 'package:flutter/material.dart' hide Card;
import 'package:game_engine/game_engine.dart';
import '../../../../core/theme/app_colors.dart';
import 'card_widget.dart';

/// Modal bottom sheet displaying intelligent Rummy group suggestions and probabilities.
class GroupSuggestionsModal extends StatelessWidget {
  final List<GroupSuggestion> suggestions;
  final Card openJoker;
  final VoidCallback onApplyBestGrouping;
  final VoidCallback onClose;

  const GroupSuggestionsModal({
    super.key,
    required this.suggestions,
    required this.openJoker,
    required this.onApplyBestGrouping,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: const BoxDecoration(
        color: AppColors.tableGradientBottom,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Row(
            children: [
              const Icon(Icons.auto_fix_high, color: AppColors.accent, size: 20),
              const SizedBox(width: 8),
              const Text(
                'GROUP SUGGESTIONS',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                onPressed: onClose,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Suggestion list
          Expanded(
            child: suggestions.isEmpty
                ? const Center(
                    child: Text(
                      'No combinations detected. Try drawing or sorting your hand.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    itemCount: suggestions.length,
                    itemBuilder: (context, index) {
                      final item = suggestions[index];
                      return _buildSuggestionItem(item);
                    },
                  ),
          ),

          const SizedBox(height: 12),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: onClose,
                  child: const Text('CLOSE'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text(
                    'APPLY BEST GROUPING',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  onPressed: onApplyBestGrouping,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionItem(GroupSuggestion item) {
    Color badgeColor;
    IconData badgeIcon;

    switch (item.category) {
      case SuggestionCategory.found:
        badgeColor = AppColors.success;
        badgeIcon = Icons.check_circle;
        break;
      case SuggestionCategory.probable:
        badgeColor = AppColors.accent;
        badgeIcon = Icons.bolt;
        break;
      case SuggestionCategory.possible:
        badgeColor = AppColors.groupImpure;
        badgeIcon = Icons.lightbulb_outline;
        break;
      case SuggestionCategory.unlikely:
        badgeColor = AppColors.danger;
        badgeIcon = Icons.cancel_outlined;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.glass,
        border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(badgeIcon, color: badgeColor, size: 16),
              const SizedBox(width: 6),
              Text(
                item.title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: badgeColor,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              if (item.category != SuggestionCategory.found)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${item.probabilityPercentage}% chance',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: badgeColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Cards preview row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...item.currentCards.map((c) => Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: CardWidget(
                        card: c,
                        isWildJoker: JokerUtils.isWildJoker(c, openJoker),
                        width: 36,
                        height: 52,
                      ),
                    )),
                if (item.neededCards.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.arrow_forward, color: Colors.white38, size: 16),
                  ),
                  ...item.neededCards.take(3).map((c) => Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Opacity(
                          opacity: 0.7,
                          child: CardWidget(
                            card: c,
                            isWildJoker: JokerUtils.isWildJoker(c, openJoker),
                            width: 36,
                            height: 52,
                          ),
                        ),
                      )),
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.description,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
