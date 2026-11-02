import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/game_action_log.dart';

/// Modal dialog showing the detailed move-by-move game action logs
/// with options to filter by round and download as JSON or Text.
class GameLogsModal extends StatefulWidget {
  final List<GameActionLogEntry> logs;
  final int totalRounds;
  final void Function({int? roundNumber, bool asJson}) onDownloadLogs;
  final String Function({int? roundNumber}) onGetLogsText;

  const GameLogsModal({
    super.key,
    required this.logs,
    required this.totalRounds,
    required this.onDownloadLogs,
    required this.onGetLogsText,
  });

  static Future<void> show(
    BuildContext context, {
    required List<GameActionLogEntry> logs,
    required int totalRounds,
    required void Function({int? roundNumber, bool asJson}) onDownloadLogs,
    required String Function({int? roundNumber}) onGetLogsText,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => GameLogsModal(
        logs: logs,
        totalRounds: totalRounds,
        onDownloadLogs: onDownloadLogs,
        onGetLogsText: onGetLogsText,
      ),
    );
  }

  @override
  State<GameLogsModal> createState() => _GameLogsModalState();
}

class _GameLogsModalState extends State<GameLogsModal> {
  int? _selectedRound; // null = all rounds
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isCompactLandscape = size.width > size.height && size.height < 550;

    final filteredLogs = _selectedRound != null
        ? widget.logs.where((l) => l.roundNumber == _selectedRound).toList()
        : widget.logs;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: isCompactLandscape ? 8 : 24),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 720,
          maxHeight: isCompactLandscape ? 340 : 620,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF09141A),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.85),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.25),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 20,
                vertical: isCompactLandscape ? 8 : 14,
              ),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0x33D4AF37), width: 1.0),
                ),
                gradient: LinearGradient(
                  colors: [Color(0xFF142028), Color(0xFF0A141A)],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(17)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2CA50).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.history_edu_rounded,
                      color: Color(0xFFF2CA50),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GAME ACTION LOGS',
                          style: GoogleFonts.cinzel(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFF2CA50),
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${filteredLogs.length} events logged across ${widget.totalRounds} round(s)',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Close button
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Color(0xFFDAE4ED)),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),

            // Dedicated Round filter bar (safely scrollable horizontally with any number of rounds)
            if (widget.totalRounds > 1)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFF0D1820),
                  border: Border(
                    bottom: BorderSide(color: Color(0x22D4AF37), width: 1.0),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.filter_list_rounded,
                      size: 14,
                      color: Color(0xFFF2CA50),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Round:',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildRoundChip(null, 'All'),
                            for (int r = 1; r <= widget.totalRounds; r++)
                              _buildRoundChip(r, 'R$r'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Top action buttons: Download JSON, Download Text, Copy
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFF0B171F),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Text(
                      _selectedRound != null ? 'Filtered: Round $_selectedRound' : 'Showing all rounds',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFCBD5E1),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Download JSON
                        ElevatedButton.icon(
                          onPressed: () {
                            widget.onDownloadLogs(roundNumber: _selectedRound, asJson: true);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('📥 Downloading Game Logs (JSON)...'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: const Icon(Icons.download_rounded, size: 14),
                          label: const Text('Download JSON'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3A8A),
                            foregroundColor: const Color(0xFFDBEAFE),
                            textStyle: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Download Text
                        ElevatedButton.icon(
                          onPressed: () {
                            widget.onDownloadLogs(roundNumber: _selectedRound, asJson: false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('📄 Downloading Game Logs (Text)...'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: const Icon(Icons.description_outlined, size: 14),
                          label: const Text('Download Text'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF15803D),
                            foregroundColor: const Color(0xFFDCFCE7),
                            textStyle: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Copy to Clipboard
                        OutlinedButton.icon(
                          onPressed: () {
                            final text = widget.onGetLogsText(roundNumber: _selectedRound);
                            Clipboard.setData(ClipboardData(text: text));
                            setState(() => _copied = true);
                            Future.delayed(const Duration(seconds: 2), () {
                              if (mounted) setState(() => _copied = false);
                            });
                          },
                          icon: Icon(_copied ? Icons.check_rounded : Icons.copy_rounded, size: 14),
                          label: Text(_copied ? 'Copied!' : 'Copy'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFF2CA50),
                            side: const BorderSide(color: Color(0x66D4AF37)),
                            textStyle: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Scrollable List of Logs
            Expanded(
              child: filteredLogs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.inbox_rounded, size: 48, color: Colors.white24),
                          const SizedBox(height: 10),
                          Text(
                            'No logs recorded yet for this game.',
                            style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: filteredLogs.length,
                      separatorBuilder: (_, __) => const Divider(color: Color(0x1AFFFFFF), height: 1),
                      itemBuilder: (context, index) {
                        final log = filteredLogs[index];
                        final isHuman = log.player.toLowerCase().contains('human');
                        final isMaya = log.player.toLowerCase().contains('maya');

                        Color playerColor = const Color(0xFFE2E8F0);
                        Color badgeBg = const Color(0xFF1E293B);
                        if (isHuman) {
                          playerColor = const Color(0xFF60A5FA);
                          badgeBg = const Color(0xFF1E3A8A).withValues(alpha: 0.35);
                        } else if (isMaya) {
                          playerColor = const Color(0xFFC084FC);
                          badgeBg = const Color(0xFF6B21A8).withValues(alpha: 0.35);
                        } else {
                          playerColor = const Color(0xFFFBBF24);
                          badgeBg = const Color(0xFFB45309).withValues(alpha: 0.25);
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Time
                              SizedBox(
                                width: 58,
                                child: Text(
                                  '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}:${log.timestamp.second.toString().padLeft(2, '0')}',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 10,
                                    color: const Color(0xFF64748B),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              // Round & Turn Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E242B),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0x33D4AF37)),
                                ),
                                child: Text(
                                  'R${log.roundNumber} T${log.turnNumber}',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFF2CA50),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Player badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: badgeBg,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: playerColor.withValues(alpha: 0.5)),
                                ),
                                child: Text(
                                  log.player,
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: playerColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Action pill
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF131B22),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Text(
                                  log.action,
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Details
                              Expanded(
                                child: Text(
                                  log.details,
                                  style: GoogleFonts.outfit(
                                    fontSize: 11.5,
                                    color: const Color(0xFFCBD5E1),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoundChip(int? round, String label) {
    final isSelected = _selectedRound == round;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: InkWell(
        onTap: () => setState(() => _selectedRound = round),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFF2CA50) : const Color(0xFF1E2832),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFFF2CA50) : const Color(0x55D4AF37),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: isSelected ? const Color(0xFF09141A) : const Color(0xFFCBD5E1),
            ),
          ),
        ),
      ),
    );
  }
}
