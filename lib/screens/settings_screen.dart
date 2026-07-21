import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:watch_verse/l10n/app_localizations.dart';
import 'package:watch_verse/theme/theme_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _displayName = '';
  String _photoURL = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  /// Fetch user data (name and photoURL)
  Future<void> _fetchUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      final l10n = AppLocalizations.of(context)!;
      try {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();

        if (userDoc.exists && mounted) {
          setState(() {
            _displayName = userDoc.data()?['name'] ?? l10n.noName;
            _photoURL = userDoc.data()?['photoURL'] ?? '';
          });
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.failedFetchUser(e.toString()))),
        );
      }
    }
  }

  /// Update user name in Firestore
  Future<void> _updateUserName(String newName) async {
    final user = _auth.currentUser;
    if (user != null) {
      final l10n = AppLocalizations.of(context)!;
      try {
        await _firestore.collection('users').doc(user.uid).update({
          'name': newName,
        });
        setState(() {
          _displayName = newName;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.nameUpdated)),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.failedUpdateName(e.toString()))),
        );
      }
    }
  }

  /// Upload profile picture to Firebase Storage and update Firestore
  Future<void> _uploadProfilePicture() async {
    final l10n = AppLocalizations.of(context)!;
    // Pre-defined avatar images
    final List<String> avatars = [
      'https://via.placeholder.com/150?text=Avatar1',
      'https://via.placeholder.com/150?text=Avatar2',
      'https://via.placeholder.com/150?text=Avatar3',
      'https://via.placeholder.com/150?text=Avatar4',
    ];

    // Avatar selection happens via this dialog
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.selectAvatarTitle),
          content: SizedBox(
            height: 200,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: avatars.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () async {
                    Navigator.pop(context); // Close the dialog
                    final selectedAvatar = avatars[index];
                    await _updateSelectedAvatar(selectedAvatar);
                  },
                  child: Image.network(
                    avatars[index],
                    fit: BoxFit.cover,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  /// Save the selected avatar to Firestore
  Future<void> _updateSelectedAvatar(String avatarURL) async {
    final user = _auth.currentUser;
    if (user != null) {
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _isLoading = true;
      });

      try {
        // Update the user document
        await _firestore.collection('users').doc(user.uid).update({
          'photoURL': avatarURL,
        });

        // Refresh the screen
        setState(() {
          _photoURL = avatarURL;
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profilePictureUpdated)),
        );
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.failedUpdateProfilePicture(e.toString()))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTitle),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Profile Picture
            GestureDetector(
              onTap: _uploadProfilePicture,
              child: CircleAvatar(
                radius: 50,
                backgroundImage:
                    _photoURL.isNotEmpty ? NetworkImage(_photoURL) : null,
                child: const Align(
                  alignment: Alignment.bottomRight,
                  child: Icon(Icons.camera_alt, color: Colors.white, size: 20),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Display Name
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.nameLabel(_displayName),
                  style: const TextStyle(fontSize: 18),
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        final dialogL10n = AppLocalizations.of(context)!;
                        String newName = '';
                        return AlertDialog(
                          title: Text(dialogL10n.editNameTitle),
                          content: TextField(
                            onChanged: (value) {
                              newName = value;
                            },
                            decoration: InputDecoration(
                              hintText: dialogL10n.enterNewNameHint,
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(dialogL10n.cancel),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _updateUserName(newName);
                              },
                              child: Text(dialogL10n.save),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(l10n.appearance,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<ThemeMode>(
              valueListenable: ThemeController.instance,
              builder: (context, mode, _) => SegmentedButton<ThemeMode>(
                segments: [
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text(l10n.themeSystem),
                    icon: const Icon(Icons.brightness_auto_rounded),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: Text(l10n.themeLight),
                    icon: const Icon(Icons.light_mode_rounded),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text(l10n.themeDark),
                    icon: const Icon(Icons.dark_mode_rounded),
                  ),
                ],
                selected: {mode},
                onSelectionChanged: (selected) =>
                    ThemeController.instance.setMode(selected.first),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
