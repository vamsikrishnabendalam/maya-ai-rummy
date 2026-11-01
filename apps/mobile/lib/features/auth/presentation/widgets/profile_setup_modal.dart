import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../models/avatar_catalog.dart';
import '../../providers/auth_provider.dart';
import 'avatar_picker_modal.dart';

class ProfileSetupModal extends ConsumerStatefulWidget {
  const ProfileSetupModal({Key? key}) : super(key: key);

  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const ProfileSetupModal(),
    );
  }

  @override
  ConsumerState<ProfileSetupModal> createState() => _ProfileSetupModalState();
}

class _ProfileSetupModalState extends ConsumerState<ProfileSetupModal> {
  final _nameController = TextEditingController();
  final _dobController = TextEditingController();
  String _selectedCountry = 'India';
  late String _selectedAvatar;
  bool _isLoading = false;
  String? _errorMessage;

  final List<String> _countries = [
    'India',
    'United States',
    'United Kingdom',
    'Canada',
    'Australia',
    'Singapore',
    'United Arab Emirates',
    'Germany',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _selectedAvatar = AvatarCatalog.getRandom().id;
    final user = ref.read(authProvider);
    if (user != null) {
      _nameController.text = user.displayName.isNotEmpty ? user.displayName : user.name;
      if (user.photoURL.isNotEmpty) {
        _selectedAvatar = user.photoURL;
      }
    }
  }

  ImageProvider _getAvatarProvider(String avatarId) {
    if (AvatarCatalog.isCustomPhoto(avatarId)) {
      if (avatarId.startsWith('data:image')) {
        try {
          final base64String = avatarId.split(',').last;
          return MemoryImage(base64Decode(base64String));
        } catch (_) {}
      } else if (avatarId.startsWith('http')) {
        return NetworkImage(avatarId);
      }
    }
    final item = AvatarCatalog.find(avatarId);
    return AssetImage(item?.thumbPath ?? AvatarCatalog.defaultAvatar.thumbPath);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _selectDateOfBirth() async {
    final now = DateTime.now();
    final initialDate = DateTime(now.year - 20, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1920),
      lastDate: DateTime(now.year - 13), // 13+ age requirement
      builder: (ctx, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.accent,
              onPrimary: Colors.black,
              surface: Color(0xFF0F1E36),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dobController.text = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _handleSubmit() async {
    final name = _nameController.text.trim();
    final dob = _dobController.text.trim();

    if (name.isEmpty) {
      setState(() => _errorMessage = 'Please enter your full name.');
      return;
    }
    if (dob.isEmpty) {
      setState(() => _errorMessage = 'Please select your Date of Birth.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authProvider.notifier).completeProfile(
        name: name,
        dateOfBirth: dob,
        country: _selectedCountry,
        photoURL: _selectedAvatar,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1B5E20),
            content: Row(
              children: const [
                Icon(Icons.stars_rounded, color: AppColors.accent),
                SizedBox(width: 10),
                Text('Account created! 5,000 Welcome Coins added to your vault! 🪙',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      String msg = e.toString().replaceAll('Exception: ', '');
      try {
        final dynamic dyn = e;
        if (dyn.error != null) {
          msg = dyn.error.toString().replaceAll('Exception: ', '');
        } else if (dyn.message != null) {
          msg = dyn.message.toString();
        }
      } catch (_) {}
      setState(() {
        _errorMessage = msg;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.accent, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'COMPLETE PLAYER PROFILE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Claim your 5,000 welcome virtual coins',
                        style: TextStyle(color: AppColors.textGold, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Google Authenticated Email (Readonly, client cannot change!)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF060E18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_user_rounded, color: Colors.greenAccent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('AUTHENTICATED GOOGLE EMAIL',
                            style: TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(
                          user?.email ?? 'Google Account',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.lock_outline_rounded, color: Colors.white30, size: 16),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Avatar Selection Row
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF14243B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.accent,
                    child: CircleAvatar(
                      radius: 24,
                      backgroundImage: _getAvatarProvider(_selectedAvatar),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AvatarCatalog.find(_selectedAvatar)?.name ?? 'Custom Photo / Avatar',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Sits in your chair at multiplayer tables',
                          style: TextStyle(color: AppColors.textGold, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                    icon: const Icon(Icons.style_rounded, size: 14),
                    label: const Text('Change', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      final chosen = await AvatarPickerModal.show(context, initialAvatar: _selectedAvatar);
                      if (chosen != null && mounted) {
                        setState(() => _selectedAvatar = chosen);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Name
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Full Name / Display Name',
                labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF14243B),
                prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.accent, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 14),

            // Date of Birth
            InkWell(
              onTap: _selectDateOfBirth,
              child: IgnorePointer(
                child: TextField(
                  controller: _dobController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Date of Birth (YYYY-MM-DD)',
                    labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
                    hintText: 'Tap to select date',
                    hintStyle: const TextStyle(color: Colors.white30),
                    filled: true,
                    fillColor: const Color(0xFF14243B),
                    prefixIcon: const Icon(Icons.calendar_today_rounded, color: AppColors.accent, size: 20),
                    suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.white60),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Country
            DropdownButtonFormField<String>(
              value: _selectedCountry,
              dropdownColor: const Color(0xFF0F1E36),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Country of Residence',
                labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF14243B),
                prefixIcon: const Icon(Icons.public_rounded, color: AppColors.accent, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
              items: _countries.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedCountry = val);
              },
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Submit Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _isLoading ? null : _handleSubmit,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.card_giftcard_rounded, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'CREATE ACCOUNT & CLAIM 5,000 COINS',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
