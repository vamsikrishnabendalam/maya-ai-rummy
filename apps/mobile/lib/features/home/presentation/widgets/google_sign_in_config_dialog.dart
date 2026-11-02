import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/providers/auth_provider.dart';

class GoogleSignInConfigDialog extends ConsumerStatefulWidget {
  const GoogleSignInConfigDialog({super.key});

  static Future<void> show(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const GoogleSignInConfigDialog(),
    );
  }

  @override
  ConsumerState<GoogleSignInConfigDialog> createState() => _GoogleSignInConfigDialogState();
}

class _GoogleSignInConfigDialogState extends ConsumerState<GoogleSignInConfigDialog> {
  static const String sha1Fingerprint = '45:5D:AE:7A:CB:65:C4:C7:F9:86:2A:23:20:A7:57:1C:19:4A:7B:C6';
  static const String sha256Fingerprint =
      '8A:5F:21:EC:DB:42:41:61:2A:D3:F7:F9:24:6B:A2:3D:D8:95:6A:CE:06:BB:59:67:09:C9:68:90:89:CE:9D:CE';
  static const String packageName = 'com.maya.rummy.maya_ai_rummy_mobile';
  static const String projectId = 'maya-rummy-vk';

  final _nameController = TextEditingController(text: 'Vamsi');
  final _emailController = TextEditingController(text: 'vamsikrishben@gmail.com');
  bool _isSigningIn = false;
  bool _copiedSha1 = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0A1526),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.accent, width: 1.2),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 600),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.key_rounded, color: Colors.amber, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Google Sign-In Configuration Notice',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Error 10 (DEVELOPER_ERROR) — SHA-1 Registration Required',
                          style: TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(color: AppColors.glassBorder, height: 24),

              // Explanation
              const Text(
                'Why did this error occur?',
                style: TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Google Play Services verifies your app using the cryptographic SHA-1 signature of the APK. '
                'Because this device runs the build signed with your local debug key, Google rejects the login until '
                'this SHA-1 fingerprint is added under your Android app in the Firebase Console.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 14),

              // Configuration Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF040A12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Project: maya-rummy-vk', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    const SizedBox(height: 2),
                    const Text('Package: $packageName', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    const SizedBox(height: 8),
                    const Text('Debug SHA-1 Fingerprint:', style: TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    SelectableText(
                      sha1Fingerprint,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        color: Colors.amberAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: _copiedSha1 ? Colors.greenAccent : AppColors.accent,
                          backgroundColor: (_copiedSha1 ? Colors.green : AppColors.accent).withValues(alpha: 0.12),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        ),
                        icon: Icon(_copiedSha1 ? Icons.check_rounded : Icons.copy_rounded, size: 14),
                        label: Text(_copiedSha1 ? 'Copied to Clipboard!' : 'Copy SHA-1 to Clipboard', style: const TextStyle(fontSize: 11)),
                        onPressed: () {
                          Clipboard.setData(const ClipboardData(text: sha1Fingerprint));
                          setState(() => _copiedSha1 = true);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('SHA-1 fingerprint copied! Add it to Firebase Console > Project Settings.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Instant In-App Sign In Form
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF142E54).withValues(alpha: 0.5),
                      const Color(0xFF0A1E38).withValues(alpha: 0.5),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.flash_on_rounded, color: AppColors.accent, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Instant Sign-In (+1,000 Coins)',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Don’t want to configure Firebase right now? Sign in instantly as a verified player with your name and email:',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: InputDecoration(
                        labelText: 'Player Display Name',
                        labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                        isDense: true,
                        filled: true,
                        fillColor: const Color(0xFF060F1A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.white24),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: InputDecoration(
                        labelText: 'Email Address',
                        labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                        isDense: true,
                        filled: true,
                        fillColor: const Color(0xFF060F1A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.white24),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: _isSigningIn
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                            : const Icon(Icons.login_rounded, size: 16),
                        label: Text(
                          _isSigningIn ? 'Signing In...' : 'Sign In Instantly',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        onPressed: _isSigningIn
                            ? null
                            : () async {
                                final name = _nameController.text.trim();
                                final email = _emailController.text.trim();
                                if (name.isEmpty) return;

                                setState(() => _isSigningIn = true);
                                try {
                                  final user = await ref.read(authProvider.notifier).signInWithProfileDetails(
                                        name: name,
                                        email: email,
                                      );
                                  if (mounted) {
                                    Navigator.of(context).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Welcome, ${user.displayName}! Signed in as verified player.'),
                                        backgroundColor: const Color(0xFF10B981),
                                        duration: const Duration(seconds: 3),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Notice: $e'), backgroundColor: Colors.redAccent),
                                    );
                                  }
                                } finally {
                                  if (mounted) setState(() => _isSigningIn = false);
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
