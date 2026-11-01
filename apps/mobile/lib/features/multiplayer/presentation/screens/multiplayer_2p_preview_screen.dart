import 'dart:math' as math;
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:game_engine/game_engine.dart';
import '../../../../core/utils/responsive.dart';
import '../../../game/models/card_group.dart';
import '../../../game/presentation/widgets/card_widget.dart';
import '../../../game/presentation/widgets/card_back_widget.dart';
import '../../../game/presentation/widgets/discard_history_modal.dart';
import '../../../game/presentation/widgets/player_hand.dart';
import '../../../game/presentation/widgets/royal_life_checklist_bar.dart';
import '../../models/table_models.dart';
import '../widgets/multiplayer_table_background.dart';
import '../widgets/multiplayer_opponents_layer.dart';

/// Interactive standalone preview screen for Multiplayer Royal Casino Hall tables (2, 3, 4, 5, 6 players).
class Multiplayer2PPreviewScreen extends ConsumerStatefulWidget {
  final int initialCapacity;

  const Multiplayer2PPreviewScreen({
    super.key,
    this.initialCapacity = 2,
  });

  @override
  ConsumerState<Multiplayer2PPreviewScreen> createState() => _Multiplayer2PPreviewScreenState();
}

class _Multiplayer2PPreviewScreenState extends ConsumerState<Multiplayer2PPreviewScreen> {
  static const double _tableCardW = 68.0;
  static const double _tableCardH = 96.0;

  late int _activeCapacity;
  Card? _selectedCard;
  final Set<Card> _selectedCards = {};

  final Card wildJoker = const Card(suit: Suit.diamonds, rank: Rank.eight, deckIndex: 0);

  late List<CardGroup> _cardGroups;
  late List<Card> _openPile;

  @override
  void initState() {
    super.initState();
    _activeCapacity = widget.initialCapacity.clamp(2, 6);
    _openPile = [
      const Card(suit: Suit.diamonds, rank: Rank.nine, deckIndex: 0),
      const Card(suit: Suit.diamonds, rank: Rank.king, deckIndex: 0),
    ];

    _cardGroups = [
      const CardGroup(
        id: 'g1',
        cards: [
          Card(suit: Suit.spades, rank: Rank.jack, deckIndex: 0),
          Card(suit: Suit.spades, rank: Rank.ten, deckIndex: 0),
          Card(suit: Suit.spades, rank: Rank.eight, deckIndex: 0),
        ],
        type: CardGroupType.pureSequence,
        isValid: true,
      ),
      const CardGroup(
        id: 'g2',
        cards: [
          Card(suit: Suit.hearts, rank: Rank.two, deckIndex: 0),
          Card(suit: Suit.hearts, rank: Rank.three, deckIndex: 0),
        ],
        type: CardGroupType.deadwood,
      ),
      const CardGroup(
        id: 'g3',
        cards: [
          Card(suit: Suit.hearts, rank: Rank.seven, deckIndex: 0),
          Card(suit: Suit.hearts, rank: Rank.queen, deckIndex: 0),
          Card(suit: Suit.clubs, rank: Rank.three, deckIndex: 0),
          Card(suit: Suit.clubs, rank: Rank.six, deckIndex: 0),
          Card(suit: Suit.clubs, rank: Rank.king, deckIndex: 0),
          Card(suit: Suit.spades, rank: Rank.ace, deckIndex: 0),
          Card(suit: Suit.spades, rank: Rank.five, deckIndex: 0),
          Card(suit: Suit.diamonds, rank: Rank.queen, deckIndex: 0),
        ],
        type: CardGroupType.deadwood,
      ),
      const CardGroup(
        id: 'g4',
        cards: [
          Card(suit: Suit.clubs, rank: Rank.seven, deckIndex: 0),
        ],
        type: CardGroupType.deadwood,
      ),
    ];
  }

  List<TablePlayer> _getOpponentsForCapacity(int capacity) {
    final allMockOpponents = [
      TablePlayer(
        uid: 'opp_vikram',
        displayName: 'Vikram S.',
        photoURL: '',
        seatIndex: 1,
        cardCount: 13,
        status: 'ACTIVE',
        connected: true,
        isHost: false,
      ),
      TablePlayer(
        uid: 'opp_ananya',
        displayName: 'Ananya R.',
        photoURL: '',
        seatIndex: 2,
        cardCount: 13,
        status: 'ACTIVE',
        connected: true,
        isHost: false,
      ),
      TablePlayer(
        uid: 'opp_kabir',
        displayName: 'Kabir M.',
        photoURL: '',
        seatIndex: 3,
        cardCount: 13,
        status: 'ACTIVE',
        connected: true,
        isHost: false,
      ),
      TablePlayer(
        uid: 'opp_pooja',
        displayName: 'Pooja S.',
        photoURL: '',
        seatIndex: 4,
        cardCount: 13,
        status: 'ACTIVE',
        connected: true,
        isHost: false,
      ),
      TablePlayer(
        uid: 'opp_rohan',
        displayName: 'Rohan V.',
        photoURL: '',
        seatIndex: 5,
        cardCount: 13,
        status: 'ACTIVE',
        connected: true,
        isHost: false,
      ),
    ];
    return allMockOpponents.take(capacity - 1).toList();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = Responsive.isDesktop(context) || size.width >= 1024;
    final isTablet = Responsive.isTablet(context) || (size.width >= 768 && size.width < 1024);

    final maxPlayers = _activeCapacity;
    final opponents = _getOpponentsForCapacity(maxPlayers);
    final dealerId = opponents.isNotEmpty ? opponents.first.uid : '';
    final turnId = opponents.length > 1 ? opponents[1].uid : (opponents.isNotEmpty ? opponents[0].uid : '');

    const String roomCode = 'ROOM77';
    const String gameMode = '201 POOL';
    const String toastMessage = '✨ Your Turn! Tap Closed Deck or Open Pile to draw.';

    final mayaAiMultiplayerCanvas = Center(
      child: AspectRatio(
        aspectRatio: 1754 / 896,
        child: FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.center,
          child: SizedBox(
            width: 1754,
            height: 896,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 1. LAYER 1: 3D PERSPECTIVE WARPED TABLE SURFACE
                Positioned.fill(
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0016)
                      ..rotateX(-1.15)
                      ..translate(0.0, 200.0),
                    child: SizedBox(
                      width: 1754,
                      height: 896,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            top: 395,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Closed Deck Stack with Perpendicular Wild Joker Tucked Underneath
                                  _buildClosedDeckWithTuckedJoker(),
                                  const SizedBox(width: 32),
                                  // Open Discard Pile
                                  _buildOpenPile(),
                                  const SizedBox(width: 32),
                                  // Finish Slot
                                  _buildFinishSlot(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 2. LAYER 2: MULTIPLAYER OPPONENTS LAYER
                // Dynamically seats opponents cleanly above armchairs according to capacity (2, 3, 4, 5, 6)
                Positioned.fill(
                  child: MultiplayerOpponentsLayer(
                    maxPlayers: maxPlayers,
                    opponents: opponents,
                    currentTurnPlayerId: turnId,
                    dealerPlayerId: dealerId,
                    remainingTurnSeconds: 24,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF09141A),
      body: MultiplayerTableBackground(
        maxPlayers: maxPlayers,
        child: Stack(
          children: [
            // 1. Center 3D Table Surface & Opponent Pod
            Positioned.fill(
              child: mayaAiMultiplayerCanvas,
            ),

            // 2. Top HUD Navigation & Control Bar (Pinned to literal top: 0)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildTopHudBar(
                context,
                isDesktop: isDesktop,
                isTablet: isTablet,
                maxPlayers: maxPlayers,
                roomCode: roomCode,
                gameMode: gameMode,
                toastMessage: toastMessage,
              ),
            ),

            // 3. Player 13-Card Hand Tray (Pinned to literal bottom: 2)
            Positioned(
              left: 0,
              right: 0,
              bottom: 2,
              child: Center(
                child: SizedBox(
                  width: isDesktop ? 1440 : (isTablet ? 1120 : 960),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PlayerHand(
                        cardGroups: _cardGroups,
                        wildJokerCard: wildJoker,
                        selectedCard: _selectedCard,
                        selectedCards: _selectedCards,
                        isDiscardPhase: true,
                        onCardTap: (card) {
                          setState(() {
                            if (_selectedCard == card) {
                              _selectedCard = null;
                            } else {
                              _selectedCard = card;
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 2),
                      const RoyalLifeChecklistBar(
                        hasFirstLife: true,
                        hasSecondLife: false,
                        points: 88,
                        isMyTurn: true,
                        turnSeconds: 26,
                        instructionText: toastMessage,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 4. Left Action Controls: Drop, Sort Hand, AI Group
            Positioned(
              left: isDesktop ? 48 : 16,
              bottom: 8,
              child: _buildLeftThumbControls(isDesktop: isDesktop),
            ),

            // 5. Right Action Controls: Group, Discard, Declare Hand
            Positioned(
              right: isDesktop ? 48 : 16,
              bottom: 8,
              child: _buildRightThumbControls(isDesktop: isDesktop),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClosedDeckWithTuckedJoker() {
    const double jokerW = 65.0;
    const double jokerH = 91.0;

    return SizedBox(
      width: _tableCardW + 42.0,
      height: _tableCardH,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerRight,
        children: [
          // Perpendicular Wild Joker tucked under closed deck peeking left
          Positioned(
            left: 8,
            top: (_tableCardH - jokerW) / 2,
            child: Transform.rotate(
              angle: -math.pi / 2,
              child: Container(
                width: jokerW,
                height: jokerH,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.65),
                      blurRadius: 8,
                      offset: const Offset(2, 3),
                    ),
                  ],
                ),
                child: CardWidget(
                  card: wildJoker,
                  isWildJoker: false,
                  width: jokerW,
                  height: jokerH,
                ),
              ),
            ),
          ),

          // Layered paper stack effect
          Positioned(
            right: 4.5,
            top: 4.5,
            child: Container(
              width: _tableCardW,
              height: _tableCardH,
              decoration: BoxDecoration(
                color: const Color(0xFFEFE6D5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0x445D4037), width: 0.8),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 4, offset: const Offset(1, 2)),
                ],
              ),
            ),
          ),
          Positioned(
            right: 2.5,
            top: 2.5,
            child: Container(
              width: _tableCardW,
              height: _tableCardH,
              decoration: BoxDecoration(
                color: const Color(0xFFF6F0E4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0x335D4037), width: 0.8),
              ),
            ),
          ),

          // Top card
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.55),
                    blurRadius: 14,
                    spreadRadius: 2.5,
                    offset: const Offset(1, 3),
                  ),
                ],
              ),
              child: const CardBackWidget(
                width: _tableCardW,
                height: _tableCardH,
                showPulse: true,
              ),
            ),
          ),

          // Deck count badge
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF2C1E12), Color(0xFF140D07)]),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF2CA50), width: 1.0),
              ),
              child: Text(
                '23',
                style: GoogleFonts.outfit(
                  color: const Color(0xFFFDE68A),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpenPile() {
    final count = _openPile.length;
    const double stepX = _tableCardW * 0.46;
    final totalWidth = _tableCardW + (count - 1) * stepX;

    return SizedBox(
      width: totalWidth,
      height: _tableCardH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < count; i++) ...[
            Positioned(
              left: i * stepX,
              top: 0,
              child: Container(
                width: _tableCardW,
                height: _tableCardH,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: (i == count - 1)
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.55)
                          : Colors.black.withValues(alpha: 0.5),
                      blurRadius: (i == count - 1) ? 12 : 5,
                      offset: const Offset(1, 2),
                    ),
                  ],
                ),
                child: CardWidget(
                  card: _openPile[i],
                  isWildJoker: _openPile[i].rank == wildJoker.rank,
                  width: _tableCardW,
                  height: _tableCardH,
                ),
              ),
            ),
          ],
          Positioned(
            top: -6,
            right: -6,
            child: Container(
              padding: const EdgeInsets.all(4.5),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFBBF24), width: 1.0),
              ),
              child: const Icon(Icons.history_rounded, size: 14, color: Color(0xFFFDE68A)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinishSlot() {
    return Container(
      width: _tableCardW,
      height: _tableCardH,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x44F59E0B), Color(0x22FBBF24)],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFBBF24), width: 2.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFBBF24).withValues(alpha: 0.55),
            blurRadius: 14,
            spreadRadius: 2.5,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.emoji_events_rounded, color: Color(0xFFFBBF24), size: 20),
          const SizedBox(height: 3),
          Text(
            'FINISH',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: const Color(0xFFFDE68A),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            '14th Card',
            style: GoogleFonts.outfit(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFFDE68A).withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHudBar(
    BuildContext context, {
    required bool isDesktop,
    required bool isTablet,
    required int maxPlayers,
    required String roomCode,
    required String gameMode,
    required String toastMessage,
  }) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + (isDesktop ? 6 : 4),
        bottom: isDesktop ? 8 : 5,
        left: isDesktop ? 18 : 8,
        right: isDesktop ? 18 : 8,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF09141A), Color(0xFF040A0D)],
        ),
        border: const Border(bottom: BorderSide(color: Color(0xFFD4AF37), width: 1.5)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 10, offset: const Offset(0, 3)),
          BoxShadow(color: const Color(0xFFD4AF37).withValues(alpha: 0.25), blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: SizedBox(
          width: 1754,
          child: Stack(
            alignment: Alignment.center,
            children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left: Title, Badges, Joker Pill
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'MAYA AI RUMMY',
                    style: GoogleFonts.outfit(
                      fontSize: isDesktop ? 16.0 : (isTablet ? 14.0 : 12.0),
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFF2CA50),
                      letterSpacing: 0.8,
                    ),
                  ),
                  SizedBox(width: isDesktop ? 8 : 5),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: isDesktop ? 8 : 5, vertical: isDesktop ? 3.5 : 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2CA50).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$maxPlayers-MAX',
                      style: GoogleFonts.outfit(
                        fontSize: isDesktop ? 10.0 : 8.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFF2CA50),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  SizedBox(width: isDesktop ? 6 : 4),
                  // Interactive Capacity Switcher Pills (2P .. 6P)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [2, 3, 4, 5, 6].map((cap) {
                      final isSelected = cap == maxPlayers;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _activeCapacity = cap;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(left: 3),
                          padding: EdgeInsets.symmetric(
                            horizontal: isDesktop ? 6 : 4,
                            vertical: isDesktop ? 3 : 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFF2CA50) : const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSelected ? const Color(0xFFF2CA50) : const Color(0x55D4AF37),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            '${cap}P',
                            style: GoogleFonts.outfit(
                              fontSize: isDesktop ? 9.5 : 8.0,
                              fontWeight: FontWeight.w800,
                              color: isSelected ? const Color(0xFF160A02) : Colors.white70,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  SizedBox(width: isDesktop ? 6 : 4),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: isDesktop ? 8 : 5, vertical: isDesktop ? 3.5 : 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      '#$roomCode',
                      style: GoogleFonts.outfit(
                        fontSize: isDesktop ? 10.0 : 8.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFFDE68A),
                      ),
                    ),
                  ),
                  SizedBox(width: isDesktop ? 6 : 4),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: isDesktop ? 8 : 5, vertical: isDesktop ? 3.5 : 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF222B32),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      gameMode,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: isDesktop ? 10.0 : 8.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFD0C5AF),
                      ),
                    ),
                  ),
                  SizedBox(width: isDesktop ? 8 : 5),
                  // Mini wild joker pill
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: isDesktop ? 11 : 8, vertical: isDesktop ? 4.5 : 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF222B32).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('JOKER', style: GoogleFonts.outfit(fontSize: isDesktop ? 10.5 : 8.5, fontWeight: FontWeight.w800, color: const Color(0xFFD0C5AF))),
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(color: const Color(0xFFFAF7F2), borderRadius: BorderRadius.circular(3)),
                          child: Text('8♦', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: const Color(0xFFB91C1C))),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.workspace_premium_rounded, size: 14, color: Color(0xFFF2CA50)),
                      ],
                    ),
                  ),
                ],
              ),

              // Right: Drop rules, Scoreboard, Logs, Exit
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: isDesktop ? 9 : 6, vertical: isDesktop ? 5 : 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF182128),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(
                      '1st: 20p • Mid: 40p',
                      style: GoogleFonts.jetBrainsMono(fontSize: isDesktop ? 10.5 : 9.0, color: const Color(0xFF86EFAC), fontWeight: FontWeight.w700),
                    ),
                  ),
                  SizedBox(width: isDesktop ? 8 : 5),
                  // Scoreboard
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: isDesktop ? 10 : 7, vertical: isDesktop ? 5.5 : 3.5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF2E2413), Color(0xFF181F26)]),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFF2CA50).withValues(alpha: 0.7)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.table_chart_rounded, size: 13, color: Color(0xFFF2CA50)),
                        const SizedBox(width: 4),
                        Text('Scoreboard', style: GoogleFonts.cinzel(fontSize: 10.5, fontWeight: FontWeight.w700, color: const Color(0xFFF2CA50))),
                      ],
                    ),
                  ),
                  SizedBox(width: isDesktop ? 8 : 5),
                  // Logs
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: isDesktop ? 10 : 7, vertical: isDesktop ? 5.5 : 3.5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF1E293B), Color(0xFF0F172A)]),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF60A5FA).withValues(alpha: 0.7)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.history_edu_rounded, size: 13, color: Color(0xFF93C5FD)),
                        const SizedBox(width: 4),
                        Text('Logs', style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.w700, color: const Color(0xFFDBEAFE))),
                      ],
                    ),
                  ),
                  SizedBox(width: isDesktop ? 8 : 5),
                  // Exit
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: isDesktop ? 10 : 7, vertical: isDesktop ? 5.5 : 3.5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF3F1417), Color(0xFF1A0A0C)]),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.6)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.logout_rounded, size: 13, color: Color(0xFFF87171)),
                        const SizedBox(width: 4),
                        Text('Exit', style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.w700, color: const Color(0xFFFCA5A5))),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Center guidance toast pill
          Center(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 18.0 : 12.0, vertical: isDesktop ? 6.0 : 4.0),
              decoration: BoxDecoration(
                color: const Color(0xFF141D24).withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF2CA50).withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome, size: 12, color: Color(0xFFF2CA50)),
                  const SizedBox(width: 6),
                  Text(
                    toastMessage,
                    style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFFFAF7F2)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  ),
);
  }

  Widget _buildLeftThumbControls({required bool isDesktop}) {
    final double padH = isDesktop ? 18.0 : 10.0;
    final double padV = isDesktop ? 11.0 : 7.0;
    final double fontSize = isDesktop ? 14.0 : 10.5;
    const double gap = 8.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Drop
        Container(
          padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFB91C1C), Color(0xFF7F1D1D)]),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFCA5A5), width: 1.6),
            boxShadow: [
              BoxShadow(color: const Color(0xFFDC2626).withValues(alpha: 0.6), blurRadius: 10, offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.flag_rounded, size: 16, color: Color(0xFFFFF1F2)),
              const SizedBox(width: 5),
              Text('Drop (20)', style: GoogleFonts.outfit(color: const Color(0xFFFFF1F2), fontSize: fontSize, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
        const SizedBox(height: gap),
        // Sort
        Container(
          padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF15803D), Color(0xFF0E4B24)]),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF86EFAC), width: 1.6),
            boxShadow: [
              BoxShadow(color: const Color(0xFF16A34A).withValues(alpha: 0.6), blurRadius: 10, offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.swap_vert_rounded, size: 16, color: Color(0xFFDCFCE7)),
              const SizedBox(width: 5),
              Text('Sort Hand', style: GoogleFonts.outfit(color: const Color(0xFFDCFCE7), fontSize: fontSize, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
        const SizedBox(height: gap),
        // AI Group
        Container(
          padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF4C1D95)]),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFF2CA50), width: 1.8),
            boxShadow: [
              BoxShadow(color: const Color(0xFF7C3AED).withValues(alpha: 0.7), blurRadius: 10, offset: const Offset(0, 2)),
              BoxShadow(color: const Color(0xFFF2CA50).withValues(alpha: 0.4), blurRadius: 6),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome_rounded, size: 16, color: Color(0xFFFDE68A)),
              const SizedBox(width: 5),
              Text('AI Group', style: GoogleFonts.outfit(color: const Color(0xFFFDE68A), fontSize: fontSize, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRightThumbControls({required bool isDesktop}) {
    final double padH = isDesktop ? 18.0 : 10.0;
    final double padV = isDesktop ? 11.0 : 7.0;
    final double fontSize = isDesktop ? 14.0 : 10.5;
    final double declarePadH = isDesktop ? 26.0 : 16.0;
    const double gap = 8.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Group
            Container(
              padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF1E40AF)]),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF93C5FD), width: 1.6),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF2563EB).withValues(alpha: 0.6), blurRadius: 10, offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.layers_rounded, size: 16, color: Color(0xFFEFF6FF)),
                  const SizedBox(width: 5),
                  Text('Group', style: GoogleFonts.outfit(color: const Color(0xFFEFF6FF), fontSize: fontSize, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            const SizedBox(width: 6),
            // Discard
            Container(
              padding: EdgeInsets.symmetric(horizontal: padH + 2, vertical: padV),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A), width: 1.8),
                boxShadow: [
                  BoxShadow(color: const Color(0xFFF59E0B).withValues(alpha: 0.7), blurRadius: 10, offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_upward_rounded, size: 16, color: Color(0xFF1F1200)),
                  const SizedBox(width: 4),
                  Text('Discard', style: GoogleFonts.outfit(color: const Color(0xFF1F1200), fontSize: fontSize, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: gap),
        // Declare Hand
        Container(
          padding: EdgeInsets.symmetric(horizontal: declarePadH, vertical: padV + 2),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706), Color(0xFFB45309)]),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFEF08A), width: 2.0),
            boxShadow: [
              BoxShadow(color: const Color(0xFFF59E0B).withValues(alpha: 0.7), blurRadius: 12, offset: const Offset(0, 3)),
              BoxShadow(color: const Color(0xFFD4AF37).withValues(alpha: 0.5), blurRadius: 6),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emoji_events_rounded, size: 18, color: Color(0xFF241A00)),
              const SizedBox(width: 5),
              Text('Declare Hand', style: GoogleFonts.outfit(color: const Color(0xFF241A00), fontSize: fontSize, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ],
    );
  }
}

