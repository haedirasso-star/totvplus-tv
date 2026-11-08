import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ════════════════════════════════════════════════════════════════════
//  هوية الشاشة: داكنة · ذهبي TOTV · أحجام مضغوطة (10 أقدام بلا تضخيم)
//  كل عنصر قابل للضغط = TvFocus: يكبر قليلاً ويأخذ إطاراً ذهبياً عند التركيز
// ════════════════════════════════════════════════════════════════════
class K {
  static const bg = Color(0xFF07070A);
  static const panel = Color(0xFF101015);
  static const card = Color(0xFF17171E);
  static const line = Color(0xFF24242E);
  static const gold = Color(0xFFF5B82E);
  static const red = Color(0xFFE5484D);
  static const green = Color(0xFF2FBF71);
  static const t1 = Color(0xFFF4F4F6);
  static const t2 = Color(0xFFA3A3B2);
  static const t3 = Color(0xFF6B6B7A);

  static TextStyle s(double size, {FontWeight w = FontWeight.w600, Color c = t1, double h = 1.3}) =>
      TextStyle(fontSize: size, fontWeight: w, color: c, height: h);
}

/// عنصر قابل للتركيز بالريموت (OK = onTap)
class TvFocus extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool autofocus;
  final double radius, scale;
  final FocusNode? node;
  final ValueChanged<bool>? onFocus;
  const TvFocus({super.key, required this.child, this.onTap, this.autofocus = false, this.radius = 10, this.scale = 1.06,
      this.node, this.onFocus});
  @override State<TvFocus> createState() => _TvFocusState();
}

class _TvFocusState extends State<TvFocus> {
  bool _f = false;
  @override
  Widget build(BuildContext context) => Focus(
    focusNode: widget.node,
    autofocus: widget.autofocus,
    onFocusChange: (v) {
      setState(() => _f = v);
      widget.onFocus?.call(v);
      if (v) Scrollable.ensureVisible(context, alignment: .5, duration: const Duration(milliseconds: 160));
    },
    onKeyEvent: (_, e) {
      if (e is KeyDownEvent && (e.logicalKey == LogicalKeyboardKey.select || e.logicalKey == LogicalKeyboardKey.enter ||
          e.logicalKey == LogicalKeyboardKey.numpadEnter || e.logicalKey == LogicalKeyboardKey.gameButtonA)) {
        widget.onTap?.call();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _f ? widget.scale : 1,
        duration: const Duration(milliseconds: 130),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius + 2),
            border: Border.all(color: _f ? K.gold : Colors.transparent, width: 2),
            boxShadow: _f ? [BoxShadow(color: K.gold.withValues(alpha: .25), blurRadius: 14)] : null,
          ),
          child: ClipRRect(borderRadius: BorderRadius.circular(widget.radius), child: widget.child),
        ),
      ),
    ),
  );
}

/// صورة شبكية خفيفة (حجم الذاكرة مضبوط حسب حجم العرض)
class NetImg extends StatelessWidget {
  final String url;
  final double? w, h;
  final BoxFit fit;
  final String fallback;
  const NetImg(this.url, {super.key, this.w, this.h, this.fit = BoxFit.cover, this.fallback = ''});
  @override
  Widget build(BuildContext context) {
    final ph = Container(width: w, height: h, color: K.card, alignment: Alignment.center,
        child: Padding(padding: const EdgeInsets.all(6),
            child: Text(fallback, textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis, style: K.s(11, c: K.t2))));
    if (url.isEmpty) return ph;
    final dpr = MediaQuery.of(context).devicePixelRatio;
    return CachedNetworkImage(imageUrl: url, width: w, height: h, fit: fit,
        memCacheWidth: w == null ? null : (w! * dpr).round(),
        fadeInDuration: const Duration(milliseconds: 120),
        placeholder: (_, __) => Container(width: w, height: h, color: K.card),
        errorWidget: (_, __, ___) => ph);
  }
}

/// صف أفقي بعنوان
class Rail extends StatelessWidget {
  final String title;
  final List<Widget> items;
  final double height;
  const Rail({super.key, required this.title, required this.items, required this.height});
  @override
  Widget build(BuildContext context) => items.isEmpty ? const SizedBox.shrink() : Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(padding: const EdgeInsets.fromLTRB(4, 14, 4, 8), child: Text(title, style: K.s(15, w: FontWeight.w800))),
      SizedBox(height: height, child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => items[i],
      )),
    ],
  );
}

/// بطاقة بوستر (فيلم/مسلسل)
class PosterCard extends StatelessWidget {
  final Map<String, dynamic> m;
  final String img;
  final VoidCallback onTap;
  final bool autofocus;
  static const w = 104.0, h = 152.0;
  const PosterCard({super.key, required this.m, required this.img, required this.onTap, this.autofocus = false});
  @override
  Widget build(BuildContext context) => SizedBox(width: w, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    TvFocus(onTap: onTap, autofocus: autofocus, child: NetImg(img, w: w, h: h, fallback: '${m['name'] ?? ''}')),
    const SizedBox(height: 5),
    Text('${m['name'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: K.s(11.5, c: K.t2)),
  ]));
}

/// بطاقة قناة
class ChannelCard extends StatelessWidget {
  final Map<String, dynamic> m;
  final String img;
  final VoidCallback onTap;
  final bool autofocus;
  static const w = 128.0, h = 76.0;
  const ChannelCard({super.key, required this.m, required this.img, required this.onTap, this.autofocus = false});
  @override
  Widget build(BuildContext context) => SizedBox(width: w, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    TvFocus(onTap: onTap, autofocus: autofocus, child: Container(width: w, height: h, color: K.card, padding: const EdgeInsets.all(10),
        child: NetImg(img, fit: BoxFit.contain, fallback: '${m['name'] ?? ''}'))),
    const SizedBox(height: 5),
    Text('${m['name'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: K.s(11, c: K.t2)),
  ]));
}

void toast(BuildContext c, String m, {bool err = false}) {
  ScaffoldMessenger.of(c).showSnackBar(SnackBar(
    behavior: SnackBarBehavior.floating, width: 520,
    backgroundColor: err ? K.red : K.card,
    content: Text(m, textAlign: TextAlign.center, style: K.s(14)),
  ));
}

class Loading extends StatelessWidget {
  const Loading({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: SizedBox(width: 28, height: 28,
      child: CircularProgressIndicator(strokeWidth: 2.4, color: K.gold)));
}
