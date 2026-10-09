import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/ballpark_style.dart';
import '../theme/ballpark_themes.dart';

/// Home Run PRO: Free-vs-Pro comparison, real purchase, restore, tip jar.
/// All prices come from the store — never hardcoded, never placeholders.
class ProScreen extends StatefulWidget {
  final BallparkAudio audio;
  final HomerunSettings settings;
  final StoreService store;

  const ProScreen({
    super.key,
    required this.audio,
    required this.settings,
    required this.store,
  });

  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends State<ProScreen> {
  BallparkTheme get _t => Ballparks.byId(
        widget.settings.themeId,
        custom: widget.settings.customTheme,
      );

  @override
  void initState() {
    super.initState();
    widget.store.proPurchased.addListener(_onPro);
    widget.store.lastThanks.addListener(_onThanks);
  }

  void _onPro() {
    if (widget.store.proPurchased.value && mounted) {
      widget.settings.setPro(true);
      widget.audio.win();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PRO unlocked — enjoy everything!',
              style: Ballpark.body(15, theme: _t)),
          backgroundColor: _t.surface,
        ),
      );
      widget.store.proPurchased.value = false;
    }
  }

  void _onThanks() {
    final msg = widget.store.lastThanks.value;
    if (msg == null || !mounted) return;
    widget.audio.win();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: Ballpark.body(15, theme: _t)),
        backgroundColor: _t.surface,
      ),
    );
    widget.store.lastThanks.value = null;
  }

  @override
  void dispose() {
    widget.store.proPurchased.removeListener(_onPro);
    widget.store.lastThanks.removeListener(_onThanks);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final s = widget.settings;
    final store = widget.store;
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
          title: Text('Home Run PRO', style: Ballpark.display(22, theme: t)),
        ),
        body: SafeArea(
          child: ListenableBuilder(
            listenable: s,
            builder: (_, _) => SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              child: Column(
                children: [
                  _ComparisonCard(theme: t, isPro: s.isPro),
                  const SizedBox(height: 16),
                  _BuyCard(
                    theme: t,
                    settings: s,
                    store: store,
                    audio: widget.audio,
                  ),
                  const SizedBox(height: 16),
                  _TipsCard(
                    theme: t,
                    store: store,
                    audio: widget.audio,
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      widget.audio.click();
                      store.restore();
                    },
                    child: Text('Restore purchases',
                        style: Ballpark.body(14, theme: t, color: t.accent)),
                  ),
                  if (store.purchaseError.value != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(store.purchaseError.value!,
                          style:
                              Ballpark.body(13, theme: t, color: Colors.redAccent)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  final BallparkTheme theme;
  final bool isPro;
  const _ComparisonCard({required this.theme, required this.isPro});

  @override
  Widget build(BuildContext context) {
    const rows = [
      ('Full derby game', true, true),
      ('3 pitch difficulties', true, true),
      ('9 classic ballparks', true, true),
      ('4 wooden bats + 4 balls', true, true),
      ('Bot Battle + 2-player derby', true, true),
      ('All-Star pitch speed', false, true),
      ('All-Star bot skill', false, true),
      ('3 night-game ballparks', false, true),
      ('4 pro bats + 4 pro balls', false, true),
      ('Custom ballpark creator', false, true),
    ];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: Ballpark.card(theme),
      child: Column(
        children: [
          Text('FREE vs PRO', style: Ballpark.label(14, theme: theme)),
          const SizedBox(height: 12),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(3),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(1),
            },
            children: [
              TableRow(
                children: [
                  const SizedBox.shrink(),
                  Center(
                      child: Text('FREE',
                          style: Ballpark.body(13,
                              theme: theme, color: theme.muted))),
                  Center(
                      child: Text('PRO',
                          style: Ballpark.body(13,
                              theme: theme, color: theme.accent))),
                ],
              ),
              for (final r in rows)
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Text(r.$1,
                          style: Ballpark.body(14, theme: theme)),
                    ),
                    Center(
                        child: Text(r.$2 ? '✅' : '—',
                            style: const TextStyle(fontSize: 15))),
                    Center(
                        child: Text(r.$3 ? '✅' : '—',
                            style: const TextStyle(fontSize: 15))),
                  ],
                ),
            ],
          ),
          if (isPro)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text('⭐ You are PRO — everything unlocked!',
                  style: Ballpark.body(14,
                      theme: theme, color: theme.accent)),
            ),
        ],
      ),
    );
  }
}

class _BuyCard extends StatelessWidget {
  final BallparkTheme theme;
  final HomerunSettings settings;
  final StoreService store;
  final BallparkAudio audio;
  const _BuyCard({
    required this.theme,
    required this.settings,
    required this.store,
    required this.audio,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: Ballpark.card(t),
      child: Column(
        children: [
          Text('UNLOCK PRO', style: Ballpark.label(14, theme: t)),
          const SizedBox(height: 6),
          Text('One-time purchase. Yours forever, on every device.',
              textAlign: TextAlign.center,
              style: Ballpark.body(13, theme: t, color: t.muted)),
          const SizedBox(height: 12),
          if (!store.available)
            Text('Store unavailable on this device.',
                style: Ballpark.body(14, theme: t, color: t.muted))
          else if (!store.storeReady)
            Text(
              store.error ?? 'Pro unlock appears here after store setup.',
              textAlign: TextAlign.center,
              style: Ballpark.body(14, theme: t, color: t.muted),
            )
          else if (settings.isPro)
            Text('⭐ PRO is active on this device.',
                style: Ballpark.body(15, theme: t, color: t.accent))
          else
            _buyButton(t, store.proProduct),
        ],
      ),
    );
  }

  Widget _buyButton(BallparkTheme t, ProductDetails? p) {
    if (p == null) {
      return Text('Pro product not configured yet.',
          style: Ballpark.body(14, theme: t, color: t.muted));
    }
    final busy = store.purchaseInProgress.value == StoreService.proId;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: busy
            ? null
            : () {
                audio.click();
                store.buyPro();
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: t.accent,
          foregroundColor: const Color(0xFF241A08),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: busy
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
            : Text('GO PRO — ${p.price}',
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class _TipsCard extends StatelessWidget {
  final BallparkTheme theme;
  final StoreService store;
  final BallparkAudio audio;
  const _TipsCard(
      {required this.theme, required this.store, required this.audio});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: Ballpark.card(t),
      child: Column(
        children: [
          Text('☕ TIP JAR', style: Ballpark.label(14, theme: t)),
          const SizedBox(height: 6),
          Text('Love the game? Buy the dev a coffee or chocolate!',
              textAlign: TextAlign.center,
              style: Ballpark.body(13, theme: t, color: t.muted)),
          const SizedBox(height: 12),
          if (!store.storeReady)
            Text('Tips appear here after store setup.',
                style: Ballpark.body(14, theme: t, color: t.muted))
          else
            Row(
              children: [
                Expanded(child: _tipButton(t, store.coffeeProduct, '☕')),
                const SizedBox(width: 10),
                Expanded(child: _tipButton(t, store.chocolateProduct, '🍫')),
              ],
            ),
        ],
      ),
    );
  }

  Widget _tipButton(BallparkTheme t, ProductDetails? p, String emoji) {
    if (p == null) return const SizedBox.shrink();
    final busy = store.purchaseInProgress.value == p.id;
    return OutlinedButton(
      onPressed: busy
          ? null
          : () {
              audio.click();
              store.buyTip(p);
            },
      style: OutlinedButton.styleFrom(
        foregroundColor: t.text,
        side: BorderSide(color: t.accent.withValues(alpha: 0.6)),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: busy
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2))
          : Text('$emoji ${p.price}',
              style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}
