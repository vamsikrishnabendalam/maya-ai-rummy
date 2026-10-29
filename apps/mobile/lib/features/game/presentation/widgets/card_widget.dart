import 'package:flutter/material.dart' hide Card;
import 'package:game_engine/game_engine.dart';
import '../../../../core/theme/app_colors.dart';

/// Premium playing card widget displaying the authentic original playing-card artwork.
///
/// Directly maps each functional [Card] in the game to the extracted original
/// card artwork assets from the complete deck sheet, preserving:
/// - Original vector quality, proportions, and authentic typography
/// - Authentic number and arrangement of suit pips
/// - Canonical corner indices with suit below rank
/// - Authentic face-card illustrations (J, Q, K) and ornate Ace designs
/// - Reversible double-headed Jester Joker artwork
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

  /// Maps a game [Card] directly to its original artwork asset.
  String _getCardAssetPath(Card card) {
    if (card.isPrintedJoker) {
      return card.jokerIndex == 1
          ? 'assets/cards/joker_blue.png'
          : 'assets/cards/joker_color.png';
    }
    final suitName = card.suit?.name ?? 'hearts';
    final rankName = card.rank?.name ?? 'ace';
    return 'assets/cards/${suitName}_$rankName.png';
  }

  @override
  Widget build(BuildContext context) {
    final isLifted = widget.isSelected || _isHovered;
    final assetPath = _getCardAssetPath(widget.card);

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
            color: Colors.white,
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
                // 1. Original authentic card artwork
                Positioned.fill(
                  child: Image.asset(
                    assetPath,
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Text(
                          widget.card.isPrintedJoker
                              ? '🃏 JOKER'
                              : '${widget.card.rank?.name ?? ""} of ${widget.card.suit?.name ?? ""}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 10, color: Colors.black87),
                        ),
                      );
                    },
                  ),
                ),

                // 2. Wild Joker badge (positioned in top-right)
                if (widget.isWildJoker && !widget.card.isPrintedJoker)
                  _buildWildJokerBadge(),

                // 3. New card shimmer effect
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
