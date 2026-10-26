import 'package:flutter/material.dart' hide Card;
import 'package:game_engine/game_engine.dart';
import '../../../../core/theme/app_colors.dart';

/// Premium card widget with selection, drag, wild joker badge, and hover effects.
class CardWidget extends StatefulWidget {
  final Card card;
  final bool isSelected;
  final bool isWildJoker;
  final bool isNewCard;
  final bool isDraggable;
  final VoidCallback? onTap;
  final double width;
  final double height;
  final String? groupId;

  const CardWidget({
    Key? key,
    required this.card,
    this.isSelected = false,
    this.isWildJoker = false,
    this.isNewCard = false,
    this.isDraggable = false,
    this.onTap,
    this.width = 52.0,
    this.height = 78.0,
    this.groupId,
  }) : super(key: key);

  @override
  State<CardWidget> createState() => _CardWidgetState();
}

class _CardWidgetState extends State<CardWidget>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _shimmerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
    if (widget.isNewCard) {
      _shimmerController.forward();
    }
  }

  @override
  void didUpdateWidget(CardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isNewCard && !oldWidget.isNewCard) {
      _shimmerController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  String _getSuitSymbol(Suit? suit) {
    switch (suit) {
      case Suit.hearts:
        return '♥';
      case Suit.diamonds:
        return '♦';
      case Suit.clubs:
        return '♣';
      case Suit.spades:
        return '♠';
      default:
        return '★';
    }
  }

  Color _getSuitColor(Suit? suit) {
    if (widget.card.isPrintedJoker) return Colors.deepPurple;
    switch (suit) {
      case Suit.hearts:
      case Suit.diamonds:
        return AppColors.suitRed;
      case Suit.clubs:
      case Suit.spades:
      default:
        return AppColors.suitBlack;
    }
  }

  String _getRankSymbol(Rank? rank) {
    if (widget.card.isPrintedJoker) return 'JKR';
    switch (rank) {
      case Rank.ace:
        return 'A';
      case Rank.jack:
        return 'J';
      case Rank.queen:
        return 'Q';
      case Rank.king:
        return 'K';
      case Rank.ten:
        return '10';
      case Rank.nine:
        return '9';
      case Rank.eight:
        return '8';
      case Rank.seven:
        return '7';
      case Rank.six:
        return '6';
      case Rank.five:
        return '5';
      case Rank.four:
        return '4';
      case Rank.three:
        return '3';
      case Rank.two:
        return '2';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getSuitColor(widget.card.suit);
    final rankText = _getRankSymbol(widget.card.rank);
    final suitText = _getSuitSymbol(widget.card.suit);
    final isLifted = widget.isSelected || _isHovered;

    Widget cardContent = MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          transform: Matrix4.identity()
            ..translate(0.0, widget.isSelected ? -12.0 : (_isHovered ? -4.0 : 0.0))
            ..scale(widget.isSelected ? 1.05 : (_isHovered ? 1.02 : 1.0)),
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: const Color(0xFFFAF7F2), // HTML reference card face #FAF7F2
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(
              color: widget.isSelected
                  ? const Color(0xFFF2CA50)
                  : _isHovered
                      ? const Color(0xFFF2CA50).withValues(alpha: 0.6)
                      : const Color(0xFFE2E8F0),
              width: widget.isSelected ? 2.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.isSelected
                    ? const Color(0xFFF2CA50).withValues(alpha: 0.45)
                    : Colors.black.withValues(alpha: 0.35),
                blurRadius: widget.isSelected ? 16.0 : (isLifted ? 8.0 : 4.0),
                offset: Offset(0, widget.isSelected ? -4 : (isLifted ? 4 : 2)),
                spreadRadius: widget.isSelected ? 1.5 : 0.0,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7.0),
            child: Stack(
              children: [
                // Card face content
                if (widget.card.isPrintedJoker)
                  _buildPrintedJoker()
                else
                  _buildNormalCard(rankText, suitText, color),

                // Wild Joker badge
                if (widget.isWildJoker && !widget.card.isPrintedJoker)
                  _buildWildJokerBadge(),

                // New card shimmer effect
                if (widget.isNewCard)
                  AnimatedBuilder(
                    animation: _shimmerAnimation,
                    builder: (context, child) {
                      return Positioned.fill(
                        child: Opacity(
                          opacity: (1.0 - _shimmerAnimation.value) * 0.3,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment(-1.0 + _shimmerAnimation.value * 3, -0.5),
                                end: Alignment(-0.5 + _shimmerAnimation.value * 3, 0.5),
                                colors: [
                                  Colors.transparent,
                                  AppColors.accent.withValues(alpha: 0.4),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    return cardContent;
  }

  Widget _buildNormalCard(String rankText, String suitText, Color color) {
    final isHeart = widget.card.suit == Suit.hearts;
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top-left rank + suit
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                rankText,
                style: TextStyle(
                  fontSize: widget.width * 0.26,
                  fontWeight: FontWeight.w800,
                  color: color,
                  height: 1.0,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 1),
              Text(
                suitText,
                style: TextStyle(
                  fontSize: isHeart ? widget.width * 0.16 : widget.width * 0.2,
                  color: color,
                  height: 1.2,
                ),
              ),
            ],
          ),
          // Center suit (balanced proportions, 100% solid opacity)
          Expanded(
            child: Center(
              child: Text(
                suitText,
                style: TextStyle(
                  fontSize: isHeart ? widget.width * 0.36 : widget.width * 0.42,
                  color: color,
                  height: 1.0,
                ),
              ),
            ),
          ),
          // Bottom-right rank
          Align(
            alignment: Alignment.bottomRight,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.rotationZ(3.14159),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    rankText,
                    style: TextStyle(
                      fontSize: widget.width * 0.22,
                      fontWeight: FontWeight.w800,
                      color: color,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(width: 1),
                  Text(
                    suitText,
                    style: TextStyle(
                      fontSize: isHeart ? widget.width * 0.13 : widget.width * 0.17,
                      color: color,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrintedJoker() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.purple.shade100,
            Colors.blue.shade50,
            Colors.amber.shade50,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '🃏',
              style: TextStyle(fontSize: widget.width * 0.35),
            ),
            const SizedBox(height: 2),
            Text(
              'JOKER',
              style: TextStyle(
                fontSize: widget.width * 0.15,
                fontWeight: FontWeight.w900,
                color: Colors.deepPurple,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWildJokerBadge() {
    return Positioned(
      top: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF2CA50), Color(0xFFD4AF37)],
          ),
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(7),
            bottomLeft: Radius.circular(6),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x66D4AF37),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.workspace_premium_rounded, size: 8, color: Color(0xFF241A00)),
            SizedBox(width: 1),
            Text(
              'JOKER',
              style: TextStyle(
                fontSize: 6.5,
                fontWeight: FontWeight.w900,
                color: Color(0xFF241A00),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


