import 'package:flutter/material.dart';

/// Preset gradients a user can pick for the ring/backdrop behind their
/// profile photo (Settings > Edit Profile). Stored as an index (`avatarBg`
/// field on the user doc) rather than raw colors, so new presets can be
/// appended later without invalidating saved picks. Index 0 matches the
/// app's own brand gradient, so accounts that never picked one still render
/// exactly as before.
///
/// The free set is unchanged (same 6 gradients, same order — existing saved
/// indices 0-5 must keep resolving to exactly what they always have). The
/// Pro set is appended after it, so indices only ever grow; nothing here
/// ever renumbers an existing gradient.
const List<LinearGradient> avatarBackgroundsFree = [
  LinearGradient(
      colors: [Color(0xFFFF6A3D), Color(0xFFFF2E63)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight),
  LinearGradient(
      colors: [Color(0xFF4DA3FF), Color(0xFF3DDC97)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight),
  LinearGradient(
      colors: [Color(0xFFFFC531), Color(0xFFFF6A3D)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight),
  LinearGradient(
      colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight),
  LinearGradient(
      colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight),
  LinearGradient(
      colors: [Color(0xFF636363), Color(0xFF1A1A2E)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight),
];

/// WatchVerse Pro-exclusive presets — locked in the picker for free accounts.
const List<LinearGradient> avatarBackgroundsPro = [
  LinearGradient(
      colors: [Color(0xFFFF0080), Color(0xFF7928CA)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight),
  LinearGradient(
      colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight),
  LinearGradient(
      colors: [Color(0xFFF7971E), Color(0xFFFFD200)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight),
  LinearGradient(
      colors: [Color(0xFF0F2027), Color(0xFF2C5364)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight),
  LinearGradient(
      colors: [Color(0xFFEE0979), Color(0xFFFF6A00)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight),
  LinearGradient(
      colors: [Color(0xFF134E5E), Color(0xFF71B280)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight),
];

/// Full picker order: free presets first, Pro presets after. This is the
/// list `avatarBg` indexes into.
const List<LinearGradient> avatarBackgrounds = [
  ...avatarBackgroundsFree,
  ...avatarBackgroundsPro,
];

LinearGradient avatarBackgroundFor(int index) =>
    avatarBackgrounds[index.clamp(0, avatarBackgrounds.length - 1)];

/// Whether preset [index] is one of the WatchVerse Pro-exclusive gradients.
bool isProBackground(int index) => index >= avatarBackgroundsFree.length;
