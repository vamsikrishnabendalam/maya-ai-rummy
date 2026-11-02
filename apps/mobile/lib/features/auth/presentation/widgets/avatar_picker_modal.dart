import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../models/avatar_catalog.dart';
import '../../services/image_picker_service.dart';

/// Modal dialog allowing players to choose from preset male/female/default avatars
/// or upload a custom photo from their device.
class AvatarPickerModal extends StatefulWidget {
  final String? initialAvatar;
  final ValueChanged<String> onSelected;

  const AvatarPickerModal({
    super.key,
    this.initialAvatar,
    required this.onSelected,
  });

  static Future<String?> show(BuildContext context, {String? initialAvatar}) {
    return showDialog<String>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => AvatarPickerModal(
        initialAvatar: initialAvatar,
        onSelected: (selected) => Navigator.of(ctx).pop(selected),
      ),
    );
  }

  @override
  State<AvatarPickerModal> createState() => _AvatarPickerModalState();
}

class _AvatarPickerModalState extends State<AvatarPickerModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late String _selectedAvatar;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _selectedAvatar = widget.initialAvatar ?? AvatarCatalog.defaultAvatar.id;
    // Auto-select tab based on initial avatar
    int initialTab = 0;
    if (_selectedAvatar.startsWith('male_')) {
      initialTab = 1;
    } else if (_selectedAvatar == AvatarCatalog.defaultAvatar.id || _selectedAvatar.isEmpty) {
      initialTab = 2;
    }
    _tabController = TabController(length: 3, vsync: this, initialIndex: initialTab);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleCustomUpload() async {
    setState(() => _isUploading = true);
    try {
      final dataUrl = await ImagePickerService.pickCustomPhoto();
      if (dataUrl != null && mounted) {
        setState(() {
          _selectedAvatar = dataUrl;
          _isUploading = false;
        });
        widget.onSelected(dataUrl);
      } else {
        if (mounted) setState(() => _isUploading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Failed to load image: $e'),
          ),
        );
      }
    }
  }

  Widget _buildAvatarGrid(List<AvatarItem> items) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = _selectedAvatar == item.id || _selectedAvatar == item.assetPath;

        return InkWell(
          onTap: () {
            setState(() => _selectedAvatar = item.id);
          },
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.accent.withValues(alpha: 0.15)
                  : const Color(0xFF132238),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.accent : const Color(0x33D4AF37),
                width: isSelected ? 2.2 : 1.0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.4),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            item.thumbPath,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.person_rounded,
                              color: AppColors.accent,
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.name,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Positioned(
                    top: 6,
                    right: 6,
                    child: CircleAvatar(
                      radius: 10,
                      backgroundColor: AppColors.accent,
                      child: Icon(Icons.check, size: 14, color: Colors.black),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSelectedPreview() {
    final isCustom = AvatarCatalog.isCustomPhoto(_selectedAvatar);
    final avatarItem = AvatarCatalog.find(_selectedAvatar);

    ImageProvider? imageProvider;
    if (isCustom) {
      if (_selectedAvatar.startsWith('data:image')) {
        try {
          final base64String = _selectedAvatar.split(',').last;
          imageProvider = MemoryImage(base64Decode(base64String));
        } catch (_) {}
      } else if (_selectedAvatar.startsWith('http')) {
        imageProvider = NetworkImage(_selectedAvatar);
      }
    } else {
      imageProvider = AssetImage(avatarItem?.thumbPath ?? AvatarCatalog.defaultAvatar.thumbPath);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1E36),
        border: const Border(bottom: BorderSide(color: Color(0x33D4AF37), width: 1)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.accent,
            child: CircleAvatar(
              radius: 26,
              backgroundImage: imageProvider,
              child: imageProvider == null
                  ? const Icon(Icons.person, color: Colors.black, size: 30)
                  : null,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCustom ? 'Custom Uploaded Photo' : (avatarItem?.name ?? 'Default Avatar'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isCustom
                      ? 'Displays as luxury gold badge at the table'
                      : 'Will sit in your chair at multiplayer tables',
                  style: const TextStyle(color: AppColors.textGold, fontSize: 11),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: const BorderSide(color: AppColors.accent),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            icon: _isUploading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                  )
                : const Icon(Icons.upload_file_rounded, size: 16),
            label: Text(
              _isUploading ? 'Uploading...' : 'Upload Photo',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
            onPressed: _isUploading ? null : _handleCustomUpload,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1B2A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.accent, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.25),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  const Icon(Icons.style_rounded, color: AppColors.accent, size: 22),
                  const SizedBox(width: 10),
                  const Text(
                    'CHOOSE PLAYER AVATAR',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Current selection preview bar
            _buildSelectedPreview(),

            // Tab bar
            Container(
              color: const Color(0xFF0A1523),
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppColors.accent,
                indicatorWeight: 3,
                labelColor: AppColors.accent,
                unselectedLabelColor: Colors.white60,
                labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                tabs: [
                  Tab(text: 'FEMALE (${AvatarCatalog.femaleAvatars.length})'),
                  Tab(text: 'MALE (${AvatarCatalog.maleAvatars.length})'),
                  const Tab(text: 'DEFAULT (1)'),
                ],
              ),
            ),

            // Tab contents
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAvatarGrid(AvatarCatalog.femaleAvatars),
                  _buildAvatarGrid(AvatarCatalog.maleAvatars),
                  _buildAvatarGrid([AvatarCatalog.defaultAvatar]),
                ],
              ),
            ),

            // Bottom Confirm Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    widget.onSelected(_selectedAvatar);
                  },
                  child: const Text(
                    'CONFIRM AVATAR',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

