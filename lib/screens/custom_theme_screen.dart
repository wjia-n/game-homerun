import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/ballpark_style.dart';
import '../theme/ballpark_themes.dart';
import 'pro_screen.dart';

/// Ballpark picker + bat/ball pickers + custom ballpark creator (Pro).
class CustomThemeScreen extends StatefulWidget {
  final BallparkAudio audio;
  final HomerunSettings settings;
  final StoreService store;
  final int initialTab;
  const CustomThemeScreen(
      {super.key,
      required this.audio,
      required this.settings,
      required this.store,
      this.initialTab = 0});

  @override
  State<CustomThemeScreen> createState() => _CustomThemeScreenState();
}

class _CustomThemeScreenState extends State<CustomThemeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  BallparkTheme get _t => Ballparks.byId(
        widget.settings.themeId,
        custom: widget.settings.customTheme,
      );

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
        length: 3, vsync: this, initialIndex: widget.initialTab.clamp(0, 2));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _needsPro() {
    widget.audio.click();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('That\'s a PRO perk — unlock everything in PRO!',
            style: Ballpark.body(14, theme: _t)),
        action: SnackBarAction(
          label: 'VIEW PRO',
          textColor: _t.accent,
          onPressed: () {
            Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ProScreen(
                    audio: widget.audio,
                    settings: widget.settings,
                    store: widget.store)));
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final s = widget.settings;
    return FieldBackdrop(
      theme: t,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              widget.audio.click();
              Navigator.of(context).pop();
            },
          ),
          title: Text('Clubhouse', style: Ballpark.display(22, theme: t)),
          bottom: TabBar(
            controller: _tabs,
            indicatorColor: t.accent,
            labelColor: t.accent,
            unselectedLabelColor: t.muted,
            tabs: const [
              Tab(text: '🏟️ Ballparks'),
              Tab(text: '🏏 Bats'),
              Tab(text: '⚾ Balls'),
            ],
          ),
        ),
        body: ListenableBuilder(
          listenable: s,
          builder: (_, _) => TabBarView(
            controller: _tabs,
            children: [
              _ballparksTab(t, s),
              _batsTab(t, s),
              _ballsTab(t, s),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ ballparks
  Widget _ballparksTab(BallparkTheme t, HomerunSettings s) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        _themeTile(t, s, id: 'custom', name: '🎨 My Ballpark', locked: !s.isPro,
            custom: true),
        const SizedBox(height: 10),
        for (final th in Ballparks.all)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _themeTile(t, s,
                id: th.id, name: th.name, locked: th.isPro && !s.isPro),
          ),
        if (!s.isPro) ...[
          const SizedBox(height: 6),
          _customCreatorTeaser(t, s),
        ] else
          _customCreator(t, s),
      ],
    );
  }

  Widget _themeTile(BallparkTheme t, HomerunSettings s,
      {required String id,
      required String name,
      required bool locked,
      bool custom = false}) {
    final selected = s.themeId == id;
    final preview = custom ? s.customTheme : Ballparks.byId(id);
    return GestureDetector(
      onTap: () {
        if (locked) {
          _needsPro();
          return;
        }
        widget.audio.click();
        s.setTheme(id);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? t.accent.withValues(alpha: 0.22)
              : t.surface,
          borderRadius: Ballpark.radius,
          border: Border.all(
              color: selected ? t.accent : t.accent.withValues(alpha: 0.3),
              width: selected ? 3 : 1),
        ),
        child: Row(
          children: [
            // Mini field preview.
            Container(
              width: 64,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    preview.skyBottom,
                    preview.grassLight,
                    preview.dirt,
                  ],
                  stops: const [0.0, 0.45, 0.75],
                ),
                border:
                    Border.all(color: Colors.black45, width: 1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('${locked ? '🔒 ' : ''}$name',
                  style: Ballpark.body(16, theme: t)),
            ),
            if (selected)
              Icon(Icons.check_circle, color: t.accent),
          ],
        ),
      ),
    );
  }

  Widget _customCreatorTeaser(BallparkTheme t, HomerunSettings s) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: Ballpark.card(t),
      child: Column(
        children: [
          Text('🎨 DESIGN YOUR OWN BALLPARK',
              style: Ballpark.label(13, theme: t)),
          const SizedBox(height: 6),
          Text('Pick the sky, grass, dirt, wall and trim colors.',
              textAlign: TextAlign.center,
              style: Ballpark.body(13, theme: t, color: t.muted)),
          const SizedBox(height: 10),
          SluggerButton(
              label: 'UNLOCK WITH PRO',
              emoji: '⭐',
              theme: t,
              primary: true,
              onTap: () {
                widget.audio.click();
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ProScreen(
                        audio: widget.audio,
                        settings: s,
                        store: widget.store)));
              }),
        ],
      ),
    );
  }

  Widget _customCreator(BallparkTheme t, HomerunSettings s) {
    const labels = {
      'skyTop': 'Sky top',
      'skyBottom': 'Sky bottom',
      'grassLight': 'Grass light',
      'grassDark': 'Grass dark',
      'dirt': 'Dirt',
      'wall': 'Outfield wall',
      'accent': 'Trim & accents',
      'crowd': 'Crowd',
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: Ballpark.card(t),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('🎨 MY BALLPARK', style: Ballpark.label(13, theme: t)),
              TextButton(
                onPressed: () {
                  widget.audio.click();
                  s.resetCustomColors();
                },
                child: Text('Reset',
                    style: Ballpark.body(13, theme: t, color: t.accent)),
              ),
            ],
          ),
          for (final e in labels.entries)
            _colorRow(t, s, e.key, e.value),
        ],
      ),
    );
  }

  Widget _colorRow(
      BallparkTheme t, HomerunSettings s, String key, String label) {
    const palette = [
      0xFF7EC8F7, 0xFF4C9A4C, 0xFFC68B59, 0xFF2F5D34,
      0xFFC9A227, 0xFFFF9E5E, 0xFF24335E, 0xFF8A5A2E,
      0xFFD9D9D9, 0xFF3A3A3A, 0xFFB04A3A, 0xFF3E6E9E,
    ];
    final current = s.customColors[key] ?? 0xFF000000;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                      color: Color(current),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white30))),
              const SizedBox(width: 8),
              Text(label, style: Ballpark.body(14, theme: t)),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in palette)
                GestureDetector(
                  onTap: () {
                    widget.audio.click();
                    s.setCustomColor(key, c);
                  },
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: current == c
                              ? t.accent
                              : Colors.white24,
                          width: current == c ? 3 : 1),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- bats
  Widget _batsTab(BallparkTheme t, HomerunSettings s) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        for (int i = 0; i < Ballparks.bats.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _batTile(t, s, i),
          ),
      ],
    );
  }

  Widget _batTile(BallparkTheme t, HomerunSettings s, int i) {
    final b = Ballparks.bats[i];
    final locked = b.isPro && !s.isPro;
    final selected = s.batStyle == i;
    return GestureDetector(
      onTap: () {
        if (locked) {
          _needsPro();
          return;
        }
        widget.audio.click();
        s.setBatStyle(i);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:
              selected ? t.accent.withValues(alpha: 0.22) : t.surface,
          borderRadius: Ballpark.radius,
          border: Border.all(
              color: selected ? t.accent : t.accent.withValues(alpha: 0.3),
              width: selected ? 3 : 1),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              height: 56,
              child: CustomPaint(painter: _BatPreview(b)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('${locked ? '🔒 ' : ''}${b.name}',
                  style: Ballpark.body(16, theme: t)),
            ),
            if (selected) Icon(Icons.check_circle, color: t.accent),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- balls
  Widget _ballsTab(BallparkTheme t, HomerunSettings s) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        for (int i = 0; i < Ballparks.balls.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ballTile(t, s, i),
          ),
      ],
    );
  }

  Widget _ballTile(BallparkTheme t, HomerunSettings s, int i) {
    final b = Ballparks.balls[i];
    final locked = b.isPro && !s.isPro;
    final selected = s.ballStyle == i;
    return GestureDetector(
      onTap: () {
        if (locked) {
          _needsPro();
          return;
        }
        widget.audio.click();
        s.setBallStyle(i);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:
              selected ? t.accent.withValues(alpha: 0.22) : t.surface,
          borderRadius: Ballpark.radius,
          border: Border.all(
              color: selected ? t.accent : t.accent.withValues(alpha: 0.3),
              width: selected ? 3 : 1),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: CustomPaint(painter: _BallPreview(b)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('${locked ? '🔒 ' : ''}${b.name}',
                  style: Ballpark.body(16, theme: t)),
            ),
            if (selected) Icon(Icons.check_circle, color: t.accent),
          ],
        ),
      ),
    );
  }
}

/// Mini bat preview.
class _BatPreview extends CustomPainter {
  final BatStyleDef b;
  _BatPreview(this.b);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(size.width / 2, size.height - 6);
    canvas.rotate(0.5);
    final wood = Paint()..color = b.wood;
    final handle = Paint()..color = b.handle;
    final barrel = Path()
      ..moveTo(-5, -18)
      ..quadraticBezierTo(-8, -38, -6, -50)
      ..quadraticBezierTo(0, -54, 6, -50)
      ..quadraticBezierTo(8, -38, 5, -18)
      ..close();
    canvas.drawPath(barrel, wood);
    canvas.drawRect(const Rect.fromLTWH(-3.5, -12, 7, 12), handle);
    canvas.drawCircle(const Offset(0, 2), 6, handle);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Bats & balls shortcut: opens the Clubhouse straight on the bat picker.
class BatsBallsScreen extends StatelessWidget {
  final BallparkAudio audio;
  final HomerunSettings settings;
  final StoreService store;
  const BatsBallsScreen(
      {super.key,
      required this.audio,
      required this.settings,
      required this.store});

  @override
  Widget build(BuildContext context) => CustomThemeScreen(
        audio: audio,
        settings: settings,
        store: store,
        initialTab: 1,
      );
}

/// Mini ball preview.
class _BallPreview extends CustomPainter {
  final BallStyleDef b;
  _BallPreview(this.b);
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 2;
    canvas.drawCircle(c, r, Paint()..color = b.shadow);
    canvas.drawCircle(c - const Offset(1, 1), r - 1, Paint()..color = b.hide);
    final seam = Paint()
      ..color = b.seam
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawArc(Rect.fromCircle(center: c, radius: r * 0.6), -1.1, 2.2,
        false, seam);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r * 0.6), 3.14 - 1.1,
        2.2, false, seam);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
