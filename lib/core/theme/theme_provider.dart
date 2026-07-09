import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// App-wide theme mode — defaults to light, user-changeable from
/// [SettingsScreen]'s Light/Dark/System selector. Session-only for now (not
/// yet persisted across app restarts); wiring it to secure storage is a
/// small follow-up once a place to store per-device preferences exists.
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);
