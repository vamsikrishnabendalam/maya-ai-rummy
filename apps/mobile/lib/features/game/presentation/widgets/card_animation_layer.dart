import 'dart:math' as math;
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_engine/game_engine.dart' show Card;
import '../../providers/game_ui_provider.dart';
import '../../../../core/theme/app_colors.dart';
import 'card_widget.dart';
import 'card_back_widget.dart';

/// Overlay widget that renders visual card animations:
/// - 13-card initial deal distribution cascade to player & opponent
/// - Drawing card flying from closed deck / open pile to player/bot
/// - Discarding card flying from hand/opponent to open pile
class CardAnimationLayer extends ConsumerStatefulWidget {
  const CardAnimationLayer({Key? key}) : super(key: key);

  @override
  ConsumerState<CardAnimationLayer> createState() => _CardAnimationLayerState();
}

class _CardAnimationLayerState extends ConsumerState<CardAnimationLayer>
    with TickerProviderStateMixin {
  late final AnimationController _dealController;
  late final AnimationController _singleCardController;

  Offset _startOffset = Offset.zero;
  Offset _endOffset = Offset.zero;
  Card? _activeCard;
  bool _isCardFaceUp = false;

  @override
  void initState() {
    super.initState();

    _dealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _singleCardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _dealController.dispose();
    _singleCardController.dispose();
    super.dispose();
  }

  void _triggerSingleFlight({
    required Offset from,
    required Offset to,
    Card? card,
    bool faceUp = false,
  }) {
    setState(() {
      _startOffset = from;
      _endOffset = to;
      _activeCard = card;
      _isCardFaceUp = faceUp;
    });

    _singleCardController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<GameUIState>(gameUIProvider, (previous, next) {
      if (previous?.lastAction != next.lastAction && next.lastAction != GameActionType.none) {
        final size = MediaQuery.of(context).size;
        final centerDeck = Offset(size.width * 0.42, size.height * 0.42);
        final centerOpenPile = Offset(size.width * 0.58, size.height * 0.42);
        final opponentHand = Offset(size.width * 0.50, size.height * 0.08);
        final playerHand = Offset(size.width * 0.50, size.height * 0.85);
        final playerDrawnSlot = Offset(size.width * 0.82, size.height * 0.85);

        switch (next.lastAction) {
          case GameActionType.dealing:
            _dealController.forward(from: 0.0);
            break;
          case GameActionType.drewFromClosed:
            _triggerSingleFlight(
              from: centerDeck,
              to: playerDrawnSlot,
              card: next.animatingCard,
              faceUp: true,
            );
            break;
          case GameActionType.drewFromOpen:
            _triggerSingleFlight(
              from: centerOpenPile,
              to: playerDrawnSlot,
              card: next.animatingCard,
              faceUp: true,
            );
            break;
          case GameActionType.discarded:
            _triggerSingleFlight(
              from: playerHand,
              to: centerOpenPile,
              card: next.animatingCard,
              faceUp: true,
            );
            break;
          case GameActionType.botDrew:
            _triggerSingleFlight(
              from: centerDeck,
              to: opponentHand,
              faceUp: false,
            );
            break;
          case GameActionType.botDiscarded:
            _triggerSingleFlight(
              from: opponentHand,
              to: centerOpenPile,
              card: next.animatingCard,
              faceUp: true,
            );
            break;
          default:
            break;
        }
      }
    });

    return IgnorePointer(
      child: Stack(
        children: [
          // 1. Initial 13-Card Deal Distribution Cascade
          AnimatedBuilder(
            animation: _dealController,
            builder: (context, child) {
              if (!_dealController.isAnimating) return const SizedBox.shrink();

              final size = MediaQuery.of(context).size;
              final deckPos = Offset(size.width * 0.42, size.height * 0.42);
              final botPos = Offset(size.width * 0.50, size.height * 0.08);
              final playerPos = Offset(size.width * 0.50, size.height * 0.85);

              const int totalCards = 13;
              final flyingWidgets = <Widget>[];

              for (int i = 0; i < totalCards; i++) {
                final double startFraction = i / (totalCards * 1.5);
                final double duration = 0.28;
                final double endFraction = (startFraction + duration).clamp(0.0, 1.0);

                if (_dealController.value >= startFraction && _dealController.value <= endFraction) {
                  final double t = (_dealController.value - startFraction) / duration;
                  final double curveVal = Curves.easeOutCubic.transform(t);

                  // Dealt to bot
                  final botCurrent = Offset.lerp(deckPos, botPos, curveVal)!;
                  flyingWidgets.add(
                    Positioned(
                      left: botCurrent.dx - 18,
                      top: botCurrent.dy - 26,
                      child: Transform.rotate(
                        angle: math.sin(curveVal * math.pi) * 0.15,
                        child: const CardBackWidget(width: 36, height: 52),
                      ),
                    ),
                  );

                  // Dealt to player
                  final playerCurrent = Offset.lerp(deckPos, playerPos, curveVal)!;
                  flyingWidgets.add(
                    Positioned(
                      left: playerCurrent.dx - 22,
                      top: playerCurrent.dy - 32,
                      child: Transform.rotate(
                        angle: -math.sin(curveVal * math.pi) * 0.15,
                        child: const CardBackWidget(width: 44, height: 64),
                      ),
                    ),
                  );
                }
              }

              // Dealing banner text
              flyingWidgets.add(
                Positioned(
                  top: size.height * 0.32,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
                      ),
                      child: const Text(
                        'DEALING 13 CARDS...',
                        style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
              );

              return Stack(children: flyingWidgets);
            },
          ),

          // 2. Single Card Draw or Discard Flying Animation
          AnimatedBuilder(
            animation: _singleCardController,
            builder: (context, child) {
              if (!_singleCardController.isAnimating) return const SizedBox.shrink();

              final t = Curves.easeInOutCubic.transform(_singleCardController.value);
              final currentPos = Offset.lerp(_startOffset, _endOffset, t)!;
              final rotation = math.sin(t * math.pi) * 0.2;
              final scale = 1.0 + math.sin(t * math.pi) * 0.15;

              Widget cardDisplay;
              if (_isCardFaceUp && _activeCard != null) {
                cardDisplay = CardWidget(
                  card: _activeCard!,
                  width: 50,
                  height: 75,
                );
              } else {
                cardDisplay = const CardBackWidget(
                  width: 50,
                  height: 75,
                );
              }

              return Positioned(
                left: currentPos.dx - 25,
                top: currentPos.dy - 38,
                child: Transform.scale(
                  scale: scale,
                  child: Transform.rotate(
                    angle: rotation,
                    child: Material(
                      color: Colors.transparent,
                      elevation: 12,
                      shadowColor: Colors.black54,
                      child: cardDisplay,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
