import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'screens/lfg/lfg_feed_screen.dart';
import 'screens/auth_screen.dart';

const _neonViolet = Color(0xFF7C3AED);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var firebaseReady = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseReady = true;
  } catch (_) {
    // Firebase platform config is supplied by the project owner.
  }
  runApp(PartyUpApp(firebaseReady: firebaseReady));
}

class PartyUpApp extends StatefulWidget {
  const PartyUpApp({super.key, required this.firebaseReady});
  final bool firebaseReady;

  @override
  State<PartyUpApp> createState() => _PartyUpAppState();
}

class _PartyUpAppState extends State<PartyUpApp> {
  bool _darkMode = true;
  bool _enteredApp = false;
  String _playerName = 'ผู้เล่น PartyUp';
  String _playerBio = 'สายแข่ง · เล่นเพื่อทีม';
  List<String> _games = ['VALORANT'];
  Map<String, String> _ranks = {'VALORANT': 'Diamond'};
  StreamSubscription<User?>? _authSubscription;
  bool _initialAuthStateReceived = false;

  @override
  void initState() {
    super.initState();
    if (widget.firebaseReady) {
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen((
        user,
      ) {
        if (!_initialAuthStateReceived) {
          _initialAuthStateReceived = true;
          return;
        }
        if (user != null && mounted && !_enteredApp) {
          setState(() => _enteredApp = true);
        }
      });
    }
    _loadSettings();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _darkMode = prefs.getBool('partyup_dark_mode') ?? true;
      _playerName = prefs.getString('partyup_player_name') ?? _playerName;
      _playerBio = prefs.getString('partyup_player_bio') ?? _playerBio;
      _games = prefs.getStringList('partyup_games') ?? _games;
      for (final game in _games) {
        _ranks[game] =
            prefs.getString('partyup_rank_$game') ?? _ranks[game] ?? 'Unranked';
      }
    });
  }

  Future<void> _setDarkMode(bool value) async {
    setState(() => _darkMode = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('partyup_dark_mode', value);
  }

  Future<void> _saveProfile(
    String name,
    String bio,
    List<String> games,
    Map<String, String> ranks,
  ) async {
    setState(() {
      _playerName = name;
      _playerBio = bio;
      _games = games;
      _ranks = ranks;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('partyup_player_name', name);
    await prefs.setString('partyup_player_bio', bio);
    await prefs.setStringList('partyup_games', games);
    for (final entry in ranks.entries) {
      await prefs.setString('partyup_rank_${entry.key}', entry.value);
    }
  }

  Future<void> _logout() async {
    if (widget.firebaseReady) {
      await FirebaseAuth.instance.signOut();
    }
    if (mounted) setState(() => _enteredApp = false);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'PartyUp · หาเพื่อนเล่นเกม',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF2F2F7),
      colorScheme: ColorScheme.fromSeed(seedColor: _neonViolet),
    ),
    darkTheme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0B0E17),
      splashColor: _neonViolet.withValues(alpha: .12),
      highlightColor: Colors.white.withValues(alpha: .04),
      colorScheme: ColorScheme.fromSeed(
        seedColor: _neonViolet,
        brightness: Brightness.dark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0F121C),
        foregroundColor: Color(0xFFF5F7FF),
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Color(0xFF161B26),
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF161B26),
        surfaceTintColor: Colors.transparent,
      ),
    ),
    themeMode: _darkMode ? ThemeMode.dark : ThemeMode.light,
    home: _enteredApp
        ? LfgFeedScreen(
            firebaseReady: widget.firebaseReady,
            isDarkMode: _darkMode,
            onDarkModeChanged: _setDarkMode,
            playerName: _playerName,
            playerBio: _playerBio,
            games: _games,
            ranks: _ranks,
            onProfileChanged: _saveProfile,
            onLogout: _logout,
          )
        : AuthScreen(
            firebaseReady: widget.firebaseReady,
            onAuthenticated: () => setState(() => _enteredApp = true),
          ),
  );
}
