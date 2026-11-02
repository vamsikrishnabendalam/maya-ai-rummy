import 'dart:math' as math;
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:game_engine/game_engine.dart';
import '../../../../core/theme/app_colors.dart';
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

    final isMobileLandscape = Responsive.isMobileLandscape(context);
    if (isMobileLandscape) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: MultiplayerTableBackground(
          maxPlayers: maxPlayers,
          child: _buildMobileLandscapeLayout(
            context,
            maxPlayers: maxPlayers,
            opponents: opponents,
            turnId: turnId,
            dealerId: dealerId,
            toastMessage: toastMessage,
          ),
        ),
      );
    }

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

  // =========================================================================
  // MOBILE LANDSCAPE 1024x491 CANONICAL LAYOUT (MATCHING MAYA AI TEMPLATE)
  // =========================================================================

  Widget _buildMobileLandscapeLayout(
    BuildContext context, {
    required int maxPlayers,
    required List<TablePlayer> opponents,
    required String turnId,
    required String dealerId,
    required String toastMessage,
  }) {
    return Center(
      child: AspectRatio(
        aspectRatio: 1024.0 / 491.0,
        child: FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.center,
          child: SizedBox(
            width: 1024.0,
            height: 491.0,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 1. LAYER 1: MULTIPLAYER OPPONENTS LAYER (Armchair seated opponents 2P to 6P)
                Positioned.fill(
                  child: MultiplayerOpponentsLayer(
                    maxPlayers: maxPlayers,
                    opponents: opponents,
                    currentTurnPlayerId: turnId,
                    dealerPlayerId: dealerId,
                    remainingTurnSeconds: 24,
                    isMobile: true,
                  ),
                ),

                // 2. Center Table Cards (Inside Table Circle Felt - Tilted 46 deg perspective)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 243,
                  child: Center(
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0016)
                        ..rotateX(-0.8028),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Closed Deck Stack with Perpendicular Tucked Wild Joker
                          _buildMobilePerspectiveClosedDeck(
                            context: context,
                            count: 24,
                            wildJoker: wildJoker,
                          ),
                          const SizedBox(width: 22),
                          // Open Discard Pile
                          _buildMobilePerspectiveOpenPile(
                            context: context,
                            discardPile: _openPile,
                            wildJoker: wildJoker,
                          ),
                          const SizedBox(width: 22),
                          // Finish / Declare Slot
                          _buildMobilePerspectiveFinishSlot(
                            context: context,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 3. Top-Left Brand Pod with Interactive 2P-6P Switcher Pills
                Positioned(
                  left: 7,
                  top: 9,
                  width: 220,
                  height: 42,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xF210192A), Color(0xF7090F1A)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x99D4AF37), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'MULTIPLAYER RUMMY',
                            style: GoogleFonts.outfit(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFFF2CA50),
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0x33F2CA50),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0x88F2CA50), width: 1),
                            ),
                            child: Text(
                              '201 POOL',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFF2CA50),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Capacity switchers
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
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
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
                                      fontSize: 9.0,
                                      fontWeight: FontWeight.w900,
                                      color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 4. Left Status Pod (Turn countdown timer, 1st Life, 2nd Life, Deadwood)
                Positioned(
                  left: 6,
                  top: 56,
                  width: 142,
                  height: 58,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xF20E1624), Color(0xF7080E18)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x66D4AF37), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'YOUR TURN',
                                style: GoogleFonts.outfit(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF34D399),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0x26F59E0B),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '⏱️ 24s',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFFFBBF24),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded, size: 11, color: Color(0xFF10B981)),
                                  const SizedBox(width: 3),
                                  Text(
                                    '1st Life',
                                    style: GoogleFonts.outfit(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF10B981),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 8),
                              Row(
                                children: [
                                  const Icon(Icons.radio_button_unchecked_rounded, size: 11, color: Color(0xFF64748B)),
                                  const SizedBox(width: 3),
                                  Text(
                                    '2nd Life',
                                    style: GoogleFonts.outfit(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'DEADWOOD: 88 PTS',
                              style: GoogleFonts.outfit(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFFBBF24),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 5. Center Toast Banner
                Positioned(
                  left: 334,
                  top: 12,
                  child: Container(
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xF00E1828), Color(0xF016263E)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0x99F2CA50), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome_rounded, color: Color(0xFFF2CA50), size: 13),
                        const SizedBox(width: 6),
                        Text(
                          toastMessage,
                          style: GoogleFonts.outfit(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFFFFBEB),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 6. Top Right: Declare Hand Button (With DragTarget)
                Positioned(
                  left: 792,
                  top: 10,
                  width: 138,
                  height: 34,
                  child: DragTarget<Object>(
                    onWillAcceptWithDetails: (details) => true,
                    onAcceptWithDetails: (details) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Preview: Card dropped on Declare Hand!')),
                      );
                    },
                    builder: (context, candidateData, rejectedData) {
                      final isHovering = candidateData.isNotEmpty;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF141B26), Color(0xFF0B1018)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isHovering ? const Color(0xFF34D399) : const Color(0xFFF2CA50),
                            width: isHovering ? 2.2 : 1.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isHovering
                                  ? const Color(0xFF34D399).withValues(alpha: 0.6)
                                  : const Color(0xFFF2CA50).withValues(alpha: 0.35),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.emoji_events_rounded, color: Color(0xFFF2CA50), size: 14),
                            const SizedBox(width: 4),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Declare Hand',
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFFF2CA50),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // 7. Top Right: 3-Dash MENU Button
                Positioned(
                  left: 939,
                  top: 10,
                  width: 78,
                  height: 34,
                  child: InkWell(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Preview: Royal Game Menu tapped')),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2A1E0D), Color(0xFF151A22)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFF2CA50), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF2CA50).withValues(alpha: 0.25),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(width: 14, height: 1.8, color: const Color(0xFFF2CA50)),
                              const SizedBox(height: 2.5),
                              Container(width: 14, height: 1.8, color: const Color(0xFFF2CA50)),
                              const SizedBox(height: 2.5),
                              Container(width: 14, height: 1.8, color: const Color(0xFFF2CA50)),
                            ],
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'MENU',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFFF2CA50),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 8. Top-Right Discard Button (With DragTarget support)
                Positioned(
                  left: 905,
                  top: 52,
                  width: 106,
                  height: 38,
                  child: DragTarget<Object>(
                    onWillAcceptWithDetails: (details) => true,
                    onAcceptWithDetails: (details) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Preview: Card dropped on Discard!')),
                      );
                    },
                    builder: (context, candidateData, rejectedData) {
                      final isHovering = candidateData.isNotEmpty;
                      return Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1B2230), Color(0xFF111722)],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isHovering ? const Color(0xFF34D399) : const Color(0xFF60A5FA),
                            width: isHovering ? 2.2 : 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (isHovering ? const Color(0xFF34D399) : const Color(0xFF60A5FA)).withValues(alpha: 0.35),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.arrow_upward_rounded, size: 14, color: Colors.white),
                            const SizedBox(width: 5),
                            Text(
                              'Discard',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // 9. Left Action Buttons Stack (All 112px x 38px)
                // Group Button
                Positioned(
                  left: 6,
                  top: 124,
                  width: 112,
                  height: 38,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2F62C9), Color(0xFF1E4498)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF60A5FA), width: 1.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.folder_rounded, size: 14, color: Colors.white),
                        const SizedBox(width: 5),
                        Text(
                          'Group',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Drop Button
                Positioned(
                  left: 7,
                  top: 171,
                  width: 112,
                  height: 38,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFA82020), Color(0xFF7E1515)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFCA5A5), width: 1.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.flag_rounded, size: 14, color: Colors.white),
                        const SizedBox(width: 5),
                        Text(
                          'Drop (20)',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Sort Hand Button
                Positioned(
                  left: 6,
                  top: 218,
                  width: 112,
                  height: 38,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2D7D46), Color(0xFF1E5C32)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF10B981), width: 1.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.swap_vert_rounded, size: 14, color: Colors.white),
                        const SizedBox(width: 5),
                        Text(
                          'Sort Hand',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // AI Group Button
                Positioned(
                  left: 6,
                  top: 267,
                  width: 112,
                  height: 38,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6A3EA1), Color(0xFF502A82)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFA855F7), width: 1.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.auto_awesome_rounded, size: 14, color: Colors.white),
                        const SizedBox(width: 5),
                        Text(
                          'AI Group',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 10. Grouped Player Hand (Full 938px width rack, 14 cards squeeze without scrolling)
                Positioned(
                  left: 44,
                  top: 335,
                  width: 938,
                  child: PlayerHand(
                    cardGroups: _cardGroups,
                    wildJokerCard: wildJoker,
                    selectedCard: _selectedCard,
                    selectedCards: _selectedCards,
                    isDiscardPhase: true,
                    customCardWidth: 90.0,
                    customCardHeight: 130.0,
                    customCardOverlap: 44.0,
                    customGroupSpacing: 16.0,
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobilePerspectiveClosedDeck({
    required BuildContext context,
    required int count,
    required Card? wildJoker,
  }) {
    const double cardW = 60.0;
    const double cardH = 86.0;
    const double jokerW = 54.0;
    const double jokerH = 76.0;

    return SizedBox(
      width: cardW + 36.0,
      height: cardH,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerRight,
        children: [
          // Perpendicular wild joker tucked underneath peeking to the left
          Positioned(
            left: 2,
            top: (cardH - jokerW) / 2,
            child: Transform.rotate(
              angle: -math.pi / 2,
              child: Container(
                width: jokerW,
                height: jokerH,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 6,
                      offset: const Offset(1, 2),
                    ),
                  ],
                ),
                child: wildJoker != null
                    ? CardWidget(
                        card: wildJoker,
                        isWildJoker: false,
                        width: jokerW,
                        height: jokerH,
                      )
                    : CardBackWidget(
                        width: jokerW,
                        height: jokerH,
                        showPulse: false,
                      ),
              ),
            ),
          ),

          // Layered paper stack rims
          Positioned(
            right: 3.5,
            top: 3.5,
            child: Container(
              width: cardW,
              height: cardH,
              decoration: BoxDecoration(
                color: const Color(0xFFEFE6D5),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0x445D4037), width: 0.6),
              ),
            ),
          ),

          // Top Interactive Closed Deck Card
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.55),
                    blurRadius: 10,
                    spreadRadius: 2.0,
                  ),
                ],
              ),
              child: const CardBackWidget(
                width: cardW,
                height: cardH,
                showPulse: true,
              ),
            ),
          ),

          // Count badge
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF2C1E12), Color(0xFF140D07)]),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF2CA50), width: 0.8),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.outfit(
                  color: const Color(0xFFFDE68A),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobilePerspectiveOpenPile({
    required BuildContext context,
    required List<Card> discardPile,
    required Card? wildJoker,
  }) {
    const double cardW = 60.0;
    const double cardH = 86.0;
    const double stepX = cardW * 0.44;

    final visibleCards = discardPile.length > 5
        ? discardPile.sublist(discardPile.length - 5)
        : discardPile;
    final int count = visibleCards.length;
    final double totalWidth = count > 0 ? (cardW + (count - 1) * stepX) : cardW;

    return DragTarget<Object>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preview: Card dropped on Open Pile (Discard)!')),
        );
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: totalWidth + (isHovering ? 8 : 0),
          height: cardH + (isHovering ? 6 : 0),
          decoration: isHovering
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF34D399), width: 2.2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF34D399).withValues(alpha: 0.6),
                      blurRadius: 14,
                    ),
                  ],
                )
              : null,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < count; i++) ...[
                Positioned(
                  left: i * stepX,
                  top: 0,
                  child: Container(
                    width: cardW,
                    height: cardH,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: (i == count - 1)
                              ? const Color(0xFFF59E0B).withValues(alpha: 0.55)
                              : Colors.black.withValues(alpha: 0.45),
                          blurRadius: (i == count - 1) ? 10 : 4,
                          offset: const Offset(1, 2),
                        ),
                      ],
                    ),
                    child: CardWidget(
                      card: visibleCards[i],
                      isWildJoker: wildJoker != null && visibleCards[i].rank == wildJoker.rank,
                      width: cardW,
                      height: cardH,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildMobilePerspectiveFinishSlot({
    required BuildContext context,
  }) {
    const double cardW = 60.0;
    const double cardH = 86.0;

    return DragTarget<Object>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preview: Card dropped on Finish Slot (Declare)!')),
        );
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: cardW,
          height: cardH,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isHovering
                  ? [const Color(0x6634D399), const Color(0x33059669)]
                  : [const Color(0x44F59E0B), const Color(0x22FBBF24)],
            ),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isHovering ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
              width: isHovering ? 2.4 : 1.8,
            ),
            boxShadow: [
              BoxShadow(
                color: (isHovering ? const Color(0xFF34D399) : const Color(0xFFFBBF24))
                    .withValues(alpha: 0.55),
                blurRadius: isHovering ? 14 : 10,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.emoji_events_rounded,
                color: isHovering ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                size: 18,
              ),
              const SizedBox(height: 2),
              Text(
                'FINISH',
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFFDE68A),
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                '14th Card',
                style: GoogleFonts.outfit(
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFFDE68A).withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

}
