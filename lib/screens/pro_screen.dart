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
    widget.store.lastThanks.addListener(_onThanks);
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
