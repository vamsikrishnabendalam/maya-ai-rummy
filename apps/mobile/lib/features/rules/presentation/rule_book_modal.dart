import 'package:flutter/material.dart' hide Card;
import 'package:game_engine/game_engine.dart';
import '../../../../core/theme/app_colors.dart';
import 'widgets/visual_card_meld_example.dart';

class RuleBookModal extends StatefulWidget {
  const RuleBookModal({Key? key}) : super(key: key);

  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => const RuleBookModal(),
    );
  }

  @override
  State<RuleBookModal> createState() => _RuleBookModalState();
}

class _RuleBookModalState extends State<RuleBookModal> {
  int _selectedTabIndex = 0;

  final List<String> _tabs = [
    'Basics',
    'Sequences',
    'Sets & Ace',
    'Jokers',
    'Declaration',
    'Scoring & Drops',
  ];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 820,
          maxHeight: size.height * 0.88,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1E36),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.accent.withValues(alpha: 0.8),
            width: 1.5,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black87,
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.accentSubtle,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
                  ),
                  child: const Icon(
                    Icons.menu_book_rounded,
                    color: AppColors.accent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Indian Rummy Rule Book',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '13-Card Rules & Declarations Guide',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Tabs
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _tabs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final isSelected = _selectedTabIndex == index;
                return ChoiceChip(
                  label: Text(_tabs[index]),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedTabIndex = index);
                  },
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.black : AppColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  selectedColor: AppColors.accent,
                  backgroundColor: AppColors.glass,
                  side: BorderSide(
                    color: isSelected ? AppColors.accent : AppColors.glassBorder,
                  ),
                );
              },
            ),
          ),

          const Divider(color: AppColors.glassBorder, height: 16),

          // Content body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: _buildTabContent(),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildBasicsTab();
      case 1:
        return _buildSequencesTab();
      case 2:
        return _buildSetsAndAceTab();
      case 3:
        return _buildJokersTab();
      case 4:
        return _buildDeclarationTab();
      case 5:
        return _buildScoringAndDropsTab();
      default:
        return _buildBasicsTab();
    }
  }

  Widget _buildBasicsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('1. Objective of the Game', Icons.flag_rounded),
        const Text(
          'Indian Rummy is played with 2 standard decks of 52 cards plus printed jokers (106 cards total). '
          'Each player is dealt 13 cards. The objective is to arrange all 13 cards into valid sequences and sets '
          'and make a valid declaration before your opponent.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.5, fontSize: 13),
        ),
        const SizedBox(height: 16),

        _buildSectionHeader('2. Turn Flow & Mechanics', Icons.sync_alt_rounded),
        _buildBulletPoint('Draw Phase', 'At the start of your turn, pick 1 card either from the face-down Closed Deck or the face-up Open Discard Pile.'),
        _buildBulletPoint('Evaluation & Grouping', 'Inspect your hand and rearrange cards into logical groups (Pure Sequences, Impure Sequences, Sets).'),
        _buildBulletPoint('Discard Phase', 'Select 1 card from your 14 cards to manually discard into the Open Pile, or drop it into the DECLARE slot if your hand is complete.'),
        const SizedBox(height: 16),

        _buildSectionHeader('3. Winning Condition', Icons.emoji_events_rounded),
        const Text(
          'To win a game of 13-Card Rummy, you must make a valid declaration satisfying all criteria:\n'
          '• Minimum 2 sequences\n'
          '• At least 1 Pure Sequence (no jokers)\n'
          '• Remaining cards arranged in valid sequences or sets\n'
          '• Exactly 0 deadwood score',
          style: TextStyle(color: AppColors.textSecondary, height: 1.5, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildSequencesTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Pure Sequence (Mandatory)', Icons.verified_rounded),
        const Text(
          'A Pure Sequence consists of 3 or more consecutive cards of the SAME SUIT. '
          'No Joker or Wildcard can substitute for a card in a pure sequence. '
          'Having at least 1 Pure Sequence is strictly MANDATORY to declare or avoid 80-point penalty.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.5, fontSize: 13),
        ),
        VisualCardMeldExample(
          title: 'Pure Sequence: 4♥ - 5♥ - 6♥',
          subtitle: 'Consecutive Hearts in numerical order without any Joker. 100% valid pure sequence.',
          cards: const [
            Card(suit: Suit.hearts, rank: Rank.four, deckIndex: 0),
            Card(suit: Suit.hearts, rank: Rank.five, deckIndex: 0),
            Card(suit: Suit.hearts, rank: Rank.six, deckIndex: 0),
          ],
          isValid: true,
          statusText: 'VALID PURE SEQ',
        ),
        const SizedBox(height: 16),

        _buildSectionHeader('Impure Sequence', Icons.auto_awesome_rounded),
        const Text(
          'An Impure Sequence consists of 3 or more consecutive cards of the same suit where '
          'one or more missing cards are substituted by a Wild Joker or Printed Joker.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.5, fontSize: 13),
        ),
        VisualCardMeldExample(
          title: 'Impure Sequence: 4♥ - 5♥ - 🃏 (Wild Joker)',
          subtitle: 'The Joker acts as the missing 6♥ to complete the sequence. Counts toward the 2 required sequences.',
          cards: const [
            Card(suit: Suit.hearts, rank: Rank.four, deckIndex: 0),
            Card(suit: Suit.hearts, rank: Rank.five, deckIndex: 0),
            Card(suit: Suit.spades, rank: Rank.eight, deckIndex: 0), // Assume 8 is wild joker
          ],
          wildJoker: const Card(suit: Suit.spades, rank: Rank.eight, deckIndex: 0),
          isValid: true,
          statusText: 'VALID IMPURE SEQ',
          statusColor: AppColors.groupImpure,
        ),
        const SizedBox(height: 16),

        _buildSectionHeader('Invalid Sequences', Icons.cancel_rounded),
        VisualCardMeldExample(
          title: 'Invalid: 4♥ - 6♥ - 7♥ (Gap in sequence)',
          subtitle: 'Missing 5♥ with no joker to bridge the gap. This group will count as deadwood points.',
          cards: const [
            Card(suit: Suit.hearts, rank: Rank.four, deckIndex: 0),
            Card(suit: Suit.hearts, rank: Rank.six, deckIndex: 0),
            Card(suit: Suit.hearts, rank: Rank.seven, deckIndex: 0),
          ],
          isValid: false,
          statusText: 'INVALID SEQUENCE',
        ),
      ],
    );
  }

  Widget _buildSetsAndAceTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Sets (3 or 4 of a Kind)', Icons.dashboard_rounded),
        const Text(
          'A Set consists of 3 or 4 cards of the SAME RANK but DIFFERENT SUITS. '
          'A set cannot contain two cards of the identical suit (even with two decks). '
          'Jokers may substitute for any card in a set.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.5, fontSize: 13),
        ),
        VisualCardMeldExample(
          title: 'Valid 3-Card Set: 7♥ - 7♣ - 7♦',
          subtitle: 'Same rank (7) across three distinct suits. Perfectly valid.',
          cards: const [
            Card(suit: Suit.hearts, rank: Rank.seven, deckIndex: 0),
            Card(suit: Suit.clubs, rank: Rank.seven, deckIndex: 0),
            Card(suit: Suit.diamonds, rank: Rank.seven, deckIndex: 0),
          ],
          isValid: true,
          statusText: 'VALID SET',
          statusColor: AppColors.groupSet,
        ),
        VisualCardMeldExample(
          title: 'Invalid Set: 7♥ - 7♥ - 7♣ (Duplicate Suit)',
          subtitle: 'Two 7♥ cards from different decks in the same set is strictly INVALID in Indian Rummy.',
          cards: const [
            Card(suit: Suit.hearts, rank: Rank.seven, deckIndex: 0),
            Card(suit: Suit.hearts, rank: Rank.seven, deckIndex: 1),
            Card(suit: Suit.clubs, rank: Rank.seven, deckIndex: 0),
          ],
          isValid: false,
          statusText: 'INVALID (DUPLICATE SUIT)',
        ),
        const SizedBox(height: 16),

        _buildSectionHeader('Ace High / Low Rules', Icons.stars_rounded),
        const Text(
          'The Ace is versatile in Indian Rummy:\n'
          '• Low Sequence: A-2-3 (Ace acts as rank 1)\n'
          '• High Sequence: Q-K-A (Ace acts as rank 14)\n'
          '• Wrap-Around (K-A-2) is STRICTLY INVALID.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.5, fontSize: 13),
        ),
        VisualCardMeldExample(
          title: 'Ace-High Pure Sequence: Q♠ - K♠ - A♠',
          subtitle: 'Valid high sequence in Spades. Ace connects after King.',
          cards: const [
            Card(suit: Suit.spades, rank: Rank.queen, deckIndex: 0),
            Card(suit: Suit.spades, rank: Rank.king, deckIndex: 0),
            Card(suit: Suit.spades, rank: Rank.ace, deckIndex: 0),
          ],
          isValid: true,
          statusText: 'VALID ACE-HIGH',
        ),
      ],
    );
  }

  Widget _buildJokersTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Open Joker & Wildcards', Icons.stars_sharp),
        const Text(
          'At the start of each game, after dealing 13 cards to each player, a card is cut from the closed deck '
          'and placed face-up under the draw pile. This card is the Open Joker.\n\n'
          'All cards possessing the same numerical rank as the cut card across all 4 suits become WILD JOKERS.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.5, fontSize: 13),
        ),
        const SizedBox(height: 12),
        _buildInfoBox(
          'Example:',
          'If the 8 of Spades (8♠) is cut as the Open Joker, then 8♥, 8♦, 8♣, and 8♠ are all Wild Jokers for that entire game!',
          AppColors.accent,
        ),
        const SizedBox(height: 16),

        _buildSectionHeader('Printed Joker Cut Rule', Icons.warning_amber_rounded),
        _buildInfoBox(
          'Special Cut Rule:',
          'If the card randomly cut from the deck is a Printed Joker (🃏), then all ACES (A♥, A♦, A♣, A♠) automatically become the Wild Jokers for that game!',
          Colors.orangeAccent,
        ),
        const SizedBox(height: 16),

        _buildSectionHeader('Using Jokers Effectively', Icons.lightbulb_outline),
        _buildBulletPoint('Save Jokers for Sets & Impure', 'Never waste a Joker inside a pure sequence unless it naturally fits there.'),
        _buildBulletPoint('Joker Deadwood Value', 'Jokers carry 0 deadwood penalty points when left in your hand upon an opponent declaration!'),
      ],
    );
  }

  Widget _buildDeclarationTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Declaration Requirements', Icons.check_circle_outline),
        _buildRuleCard(
          'Rule 1: Minimum 2 Sequences',
          'Your 13 cards must include at least two sequences. A single sequence plus sets is not valid.',
        ),
        _buildRuleCard(
          'Rule 2: At Least 1 Pure Sequence',
          'At least one sequence must be completely pure (no jokers substituted).',
        ),
        _buildRuleCard(
          'Rule 3: Second Sequence (Pure or Impure)',
          'The second sequence can be either pure or impure (utilizing a joker).',
        ),
        _buildRuleCard(
          'Rule 4: All 13 Cards Meld',
          'Remaining cards must form valid sequences or sets (groups of 3 or 4 cards).',
        ),
        _buildRuleCard(
          'Rule 5: Discard into Declare Slot',
          'The 14th card must be discarded into the designated DECLARE slot to complete the show.',
        ),
        const SizedBox(height: 16),

        _buildSectionHeader('Wrong Show Penalty (80 Points)', Icons.gavel_rounded),
        _buildInfoBox(
          'Wrong Show Rule:',
          'If you declare with an invalid hand (e.g. missing pure sequence, invalid set, unmelded cards), '
          'you will automatically be penalized with a Full Count (80 points)! The winner scores 0 points.',
          AppColors.danger,
        ),
      ],
    );
  }

  Widget _buildScoringAndDropsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Point Values & Deadwood', Icons.score_rounded),
        const Text(
          'When a player declares, losers tally deadwood penalty points based on unmatched cards:',
          style: TextStyle(color: AppColors.textSecondary, height: 1.5, fontSize: 13),
        ),
        const SizedBox(height: 10),
        _buildScoreTable(),
        const SizedBox(height: 16),

        _buildSectionHeader('Drop Penalties', Icons.exit_to_app_rounded),
        _buildDropCard('First Drop', '20 Pts', 'Dropping on your very first turn without drawing from the discard pile.'),
        _buildDropCard('Middle Drop', '40 Pts', 'Dropping after drawing cards on any subsequent turn.'),
        _buildDropCard('Full Count / Wrong Show', '80 Pts', 'Invalid declaration or missing pure sequence with maximum deadwood.'),
        const SizedBox(height: 16),

        _buildSectionHeader('Pool Elimination', Icons.sports_score_rounded),
        const Text(
          'In Pool Rummy (e.g. 201 Pool), player scores accumulate across successive deals. '
          'When a player crosses the elimination threshold (201 points), they are eliminated from the table. '
          'The last remaining player wins!',
          style: TextStyle(color: AppColors.textSecondary, height: 1.5, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.accent, size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: AppColors.accent, fontSize: 16)),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                children: [
                  TextSpan(text: '$title: ', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  TextSpan(text: description),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox(String title, String text, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: accentColor,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            text,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleCard(String title, String description) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, color: AppColors.groupPure, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreTable() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        children: [
          _buildScoreRow('Face Cards (K, Q, J)', '10 Points Each', true),
          _buildScoreRow('Ace (A)', '10 Points', false),
          _buildScoreRow('Number Cards (2 - 10)', 'Face Value (e.g. 5 = 5 pts)', false),
          _buildScoreRow('Jokers (Wild & Printed)', '0 Points (Zero Deadwood)', false),
          _buildScoreRow('Max Cap per Round', '80 Points Maximum', false),
        ],
      ),
    );
  }

  Widget _buildScoreRow(String label, String value, bool isFirst) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: isFirst ? null : const Border(top: BorderSide(color: AppColors.glassBorder)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12)),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.accent,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropCard(String title, String points, String description) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accentSubtle,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
            ),
            child: Text(
              points,
              style: const TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  description,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
