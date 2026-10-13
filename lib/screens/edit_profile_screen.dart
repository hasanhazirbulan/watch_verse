import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/services/pro_service.dart';
import 'package:watch_verse/theme/app_theme.dart';
import 'package:watch_verse/theme/avatar_backgrounds.dart';
import 'package:watch_verse/widgets/async_state_view.dart';
import 'package:watch_verse/widgets/paywall_sheet.dart';

/// Dedicated profile-photo/name editor, reached from Settings and kept off
/// the main profile view so that screen stays a read-only summary. Fetches
/// its own starting values so the caller doesn't need a Firestore read just
/// to open this page.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _characterQuoteController =
      TextEditingController();
  String _photoURL = '';
  int _avatarBg = 0;
  // Guests (reachable via Settings) have nothing to load — starting at true
  // with no user left them on an endless spinner.
  bool _loading = FirebaseAuth.instance.currentUser != null;
  // Set when the initial profile read fails. The form is NOT shown then:
  // its empty fields would overwrite the real name/quote on Save.
  Object? _loadError;
  bool _uploadingPhoto = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (_loadError != null) {
      setState(() {
        _loadError = null;
        _loading = true;
      });
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!mounted) return;
      setState(() {
        _nameController.text = (doc.data()?['name'] ?? '') as String;
        _characterQuoteController.text =
            (doc.data()?['characterQuote'] ?? '') as String;
        _photoURL = (doc.data()?['photoURL'] ?? '') as String;
        _avatarBg = ((doc.data()?['avatarBg'] ?? 0) as num).toInt();
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = e;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _characterQuoteController.dispose();
    super.dispose();
  }

  Future<void> _setAvatarBg(int index) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (isProBackground(index) && !ProService.instance.isPatron) {
      showPaywallSheet(context);
      return;
    }
    setState(() => _avatarBg = index);
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'avatarBg': index,
    }, SetOptions(merge: true));
  }

  Future<void> _changePhoto() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        imageQuality: 80,
      );
      if (picked == null || !mounted) return;
      setState(() => _uploadingPhoto = true);
      final ref = FirebaseStorage.instance.ref(
        'profile_images/${user.uid}.jpg',
      );
      await ref.putFile(File(picked.path));
      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'photoURL': url,
      }, SetOptions(merge: true));
      if (!mounted) return;
      setState(() {
        _photoURL = url;
        _uploadingPhoto = false;
      });
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() => _uploadingPhoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.profileUpdatePhotoError(e.toString()))),
      );
    }
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': _nameController.text.trim(),
        'characterQuote': _characterQuoteController.text.trim(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.profileSaveNameError(e.toString()))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(l10n.profileEditProfileTitle),
        actions: [
          TextButton(
            onPressed: _saving || _loading || _loadError != null || user == null
                ? null
                : _save,
            child: Text(
              l10n.save,
              style: TextStyle(
                color: context.colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: user == null
          ? Center(child: Text(l10n.profileSignInPrompt))
          : _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                asyncErrorView(context, _loadError!),
                TextButton(
                  onPressed: _fetchUserData,
                  child: Text(l10n.homeRetryAction),
                ),
              ],
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _uploadingPhoto ? null : _changePhoto,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: avatarBackgroundFor(_avatarBg),
                          ),
                          child: CircleAvatar(
                            radius: 52,
                            backgroundColor: context.colors.surfaceAlt,
                            backgroundImage: _photoURL.isNotEmpty
                                ? NetworkImage(_photoURL)
                                : null,
                            child: _uploadingPhoto
                                ? const CircularProgressIndicator()
                                : (_photoURL.isEmpty
                                      ? Text(
                                          (user.email ?? '?')
                                              .substring(0, 1)
                                              .toUpperCase(),
                                          style: const TextStyle(
                                            fontSize: 34,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      : null),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: context.colors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: context.colors.background,
                              width: 2.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 15,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      l10n.profileAvatarBackgroundLabel,
                      style: TextStyle(
                          color: context.colors.textSecondary, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder<bool>(
                    stream: ProService.instance.isPatronStream,
                    initialData: ProService.instance.isPatron,
                    builder: (context, proSnap) {
                      final isPro = proSnap.data ?? false;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (var i = 0; i < avatarBackgrounds.length; i++)
                            GestureDetector(
                              onTap: () => _setAvatarBg(i),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: avatarBackgrounds[i],
                                      border: i == _avatarBg
                                          ? Border.all(
                                              color: context.colors.textPrimary,
                                              width: 2.5)
                                          : null,
                                    ),
                                  ),
                                  if (isProBackground(i) && !isPro)
                                    Positioned(
                                      right: -2,
                                      bottom: -2,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: context.colors.surface,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: context.colors.background,
                                              width: 1.5),
                                        ),
                                        child: Icon(Icons.lock_rounded,
                                            size: 10,
                                            color: context.colors.accent),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      labelText: l10n.profileYourNameHint,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _characterQuoteController,
                    maxLength: 60,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      labelText: l10n.profileCharacterQuoteHint,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      user.email ?? '',
                      style: TextStyle(color: context.colors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
