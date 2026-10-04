import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class MayaAvatarWidget extends StatefulWidget {
  final bool isHorizontal;

  const MayaAvatarWidget({Key? key, this.isHorizontal = false}) : super(key: key);

  @override
  State<MayaAvatarWidget> createState() => _MayaAvatarWidgetState();
}

class _MayaAvatarWidgetState extends State<MayaAvatarWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  int _speechIndex = 0;
  Timer? _speechTimer;

  final List<String> _dialogues = [
    'Ready to test your Rummy skills?',
    'I\'ve prepared some sharp sequences today!',
    'Can you minimize your deadwood count against me?',
    'Choose your difficulty and let\'s play!',
    'Remember: at least one Pure Sequence is mandatory!',
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _speechTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() {
          _speechIndex = (_speechIndex + 1) % _dialogues.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _speechTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isHorizontal) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildAvatar(),
          const SizedBox(width: 14),
          Flexible(child: _buildSpeechBubble()),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildAvatar(),
        const SizedBox(height: 10),
        _buildSpeechBubble(),
      ],
    );
  }

  Widget _buildAvatar() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = 1.0 + (_pulseController.value * 0.05);
        final glowRadius = 8.0 + (_pulseController.value * 8.0);

        return Transform.scale(
          scale: scale,
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.35),
                  blurRadius: glowRadius,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer ring
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [
                        AppColors.accent,
                        Color(0xFF8E24AA),
                        Color(0xFF1E88E5),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: Colors.white38,
                      width: 1.5,
                    ),
                  ),
                ),
                // Inner circle
                Container(
                  width: 66,
                  height: 66,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF0D1E36),
                  ),
                  child: const Center(
                    child: Text(
                      '🤖',
                      style: TextStyle(fontSize: 34),
                    ),
                  ),
                ),
                // Online/Status badge
                Positioned(
                  bottom: 2,
                  right: 4,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.groupPure,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSpeechBubble() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.35),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.smart_toy_rounded,
            color: AppColors.accent,
            size: 16,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _dialogues[_speechIndex],
                key: ValueKey(_speechIndex),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
