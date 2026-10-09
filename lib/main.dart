import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/splash_screen.dart';
import 'services/audio_service.dart';
import 'services/settings_service.dart';
import 'theme/ballpark_style.dart';
import 'theme/ballpark_themes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  final settings = HomerunSettings();
  await settings.load();
  final audio = BallparkAudio();
  audio.configure(
    musicOn: settings.musicOn,
    sfxOn: settings.sfxOn,
    volume: settings.volume,
  );
  runApp(HomeRunApp(settings: settings, audio: audio));
}

class HomeRunApp extends StatefulWidget {
  final HomerunSettings settings;
  final BallparkAudio audio;
  const HomeRunApp({super.key, required this.settings, required this.audio});

  @override
  State<HomeRunApp> createState() => _HomeRunAppState();
}

class _HomeRunAppState extends State<HomeRunApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.audio.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause (not stop) on interruption so music resumes exactly where it
    // left off; game screens additionally freeze their engines.
    if (state == AppLifecycleState.paused) {
      widget.audio.onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      widget.audio.onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (_, _) => MaterialApp(
        title: 'Home Run Derby',
        debugShowCheckedModeBanner: false,
        theme: Ballpark.appTheme(Ballparks.byId(widget.settings.themeId,
            custom: widget.settings.customTheme)),
        home: SplashScreen(audio: widget.audio, settings: widget.settings),
      ),
    );
  }
}
