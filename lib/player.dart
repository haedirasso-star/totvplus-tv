import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'core.dart';
import 'ui.dart';

// ════════════════════════════════════════════════════════════════════
//  المشغّل — خفيف بالريموت
//  OK: إيقاف/تشغيل وإظهار الشريط · ◀▶: ±10 ث (VOD) · ▲▼: القناة السابقة/التالية (المباشر) · رجوع: خروج
//  الخط من العقل المدبر لحظة التشغيل · رفض الخط ⇐ خط آخر فوراً · الخروج ⇐ الخط يرجع للمخزن
// ════════════════════════════════════════════════════════════════════
class PlayItem {
  final String title;
  final String Function()? url;       // يُبنى بعد إعارة الخط
  final List<String> direct;          // روابط جاهزة (قناتنا)
  final bool live;
  const PlayItem({required this.title, this.url, this.direct = const [], this.live = false});
}

class PlayerPage extends StatefulWidget {
  final List<PlayItem> list;
  final int index;
  const PlayerPage({super.key, required this.list, this.index = 0});

  static Future<void> open(BuildContext c, List<PlayItem> list, [int i = 0]) =>
      Navigator.of(c).push(PageRouteBuilder(pageBuilder: (_, __, ___) => PlayerPage(list: list, index: i),
          transitionDuration: const Duration(milliseconds: 120), transitionsBuilder: (_, a, __, ch) => FadeTransition(opacity: a, child: ch)));

  @override State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  VideoPlayerController? _c;
  late int _i = widget.index;
  String _msg = '', _err = '';
  bool _ui = true, _rotated = false;
  Timer? _hide;
  int _di = 0;
  final _focus = FocusNode();

  PlayItem get _it => widget.list[_i];

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _start();
  }

  @override
  void dispose() {
    _hide?.cancel();
    _c?.dispose();
    WakelockPlus.disable();
    Brain.release();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() { _msg = 'جاري التشغيل…'; _err = ''; _ui = true; });
    _c?.dispose(); _c = null;
    String url;
    if (_it.direct.isNotEmpty) {
      url = _it.direct[_di.clamp(0, _it.direct.length - 1)];
    } else {
      if (!await Brain.lease()) { setState(() { _msg = ''; _err = Brain.reasonText; }); return; }
      Brain.hold();
      url = _it.url!();
    }
    await _open(url);
  }

  Future<void> _open(String url) async {
    final c = VideoPlayerController.networkUrl(Uri.parse(url),
        formatHint: url.contains('.m3u8') ? VideoFormat.hls : null,
        httpHeaders: const {'User-Agent': 'TOTV-TV/2.0'});
    _c = c;
    try {
      await c.initialize().timeout(const Duration(seconds: 15));
      if (!mounted || _c != c) return;
      await c.play();
      c.addListener(_tick);
      setState(() => _msg = '');
      _autoHide();
    } catch (e) {
      if (!mounted || _c != c) return;
      await _fail('$e');
    }
  }

  void _tick() {
    final v = _c?.value;
    if (v == null) return;
    if (v.hasError) { _c!.removeListener(_tick); _fail(v.errorDescription ?? 'error'); return; }
    final b = v.isBuffering && v.isPlaying;
    if (b && _msg.isEmpty) setState(() => _msg = 'تحميل…');
    if (!b && _msg == 'تحميل…') setState(() => _msg = '');
  }

  Future<void> _fail(String why) async {
    // قناتنا: الرابط الاحتياطي · الخطوط: خط آخر مرة واحدة
    if (_it.direct.length > _di + 1) { _di++; return _start(); }
    if (_it.direct.isEmpty && !_rotated && Brain.line > 0) {
      _rotated = true;
      setState(() => _msg = 'تبديل الخط…');
      if (await Brain.lease(bad: Brain.line)) { await _open(_it.url!()); return; }
    }
    setState(() { _msg = ''; _err = 'تعذّر تشغيل هذا المحتوى الآن'; });
  }

  void _autoHide() {
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 4), () { if (mounted && (_c?.value.isPlaying ?? false)) setState(() => _ui = false); });
  }

  void _zap(int d) {
    if (widget.list.length < 2) return;
    _i = (_i + d) % widget.list.length;
    if (_i < 0) _i += widget.list.length;
    _di = 0; _rotated = false;
    _start();
  }

  KeyEventResult _key(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    setState(() => _ui = true);
    _autoHide();
    final c = _c;
    if (k == LogicalKeyboardKey.select || k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.mediaPlayPause || k == LogicalKeyboardKey.space) {
      if (_err.isNotEmpty) { _di = 0; _rotated = false; _start(); return KeyEventResult.handled; }
      if (c != null && c.value.isInitialized) { c.value.isPlaying ? c.pause() : c.play(); setState(() {}); }
      return KeyEventResult.handled;
    }
    if (_it.live) {
      if (k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.channelUp) { _zap(-1); return KeyEventResult.handled; }
      if (k == LogicalKeyboardKey.arrowDown || k == LogicalKeyboardKey.channelDown) { _zap(1); return KeyEventResult.handled; }
    } else if (c != null && c.value.isInitialized) {
      if (k == LogicalKeyboardKey.arrowRight || k == LogicalKeyboardKey.mediaFastForward) {
        c.seekTo(c.value.position + const Duration(seconds: 10)); return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.mediaRewind) {
        c.seekTo(c.value.position - const Duration(seconds: 10)); return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  String _t(Duration d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}' : '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final ready = c != null && c.value.isInitialized;
    return Focus(
      focusNode: _focus, autofocus: true, onKeyEvent: _key,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(fit: StackFit.expand, children: [
          if (ready) Center(child: AspectRatio(aspectRatio: c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio, child: VideoPlayer(c))),
          if (_msg.isNotEmpty) Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Loading(), const SizedBox(height: 12), Text(_msg, style: K.s(14, c: K.t2)),
          ])),
          if (_err.isNotEmpty) Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline_rounded, color: K.red, size: 40),
            const SizedBox(height: 10),
            Text(_err, textAlign: TextAlign.center, style: K.s(15)),
            const SizedBox(height: 6),
            Text('OK لإعادة المحاولة · رجوع للخروج', style: K.s(12, c: K.t3)),
          ])),
          AnimatedOpacity(
            opacity: _ui ? 1 : 0, duration: const Duration(milliseconds: 200),
            child: Align(alignment: Alignment.bottomCenter, child: Container(
              padding: const EdgeInsets.fromLTRB(40, 40, 40, 26),
              decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xDD000000)])),
              child: Directionality(textDirection: TextDirection.rtl, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  if (_it.live) Container(margin: const EdgeInsets.only(left: 10), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: K.red, borderRadius: BorderRadius.circular(5)),
                      child: Text('مباشر', style: K.s(11.5, w: FontWeight.w800))),
                  Expanded(child: Text(_it.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: K.s(18, w: FontWeight.w800))),
                  if (_it.live && widget.list.length > 1) Text('▲▼ تبديل القناة', style: K.s(12, c: K.t3)),
                ]),
                if (ready && !_it.live) ...[
                  const SizedBox(height: 10),
                  ValueListenableBuilder<VideoPlayerValue>(valueListenable: c, builder: (_, v, __) {
                    final tot = v.duration.inMilliseconds;
                    return Row(textDirection: TextDirection.ltr, children: [
                      Text(_t(v.position), style: K.s(12, c: K.t2)),
                      const SizedBox(width: 10),
                      Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(
                          value: tot <= 0 ? 0 : (v.position.inMilliseconds / tot).clamp(0.0, 1.0), minHeight: 4,
                          color: K.gold, backgroundColor: Colors.white24))),
                      const SizedBox(width: 10),
                      Text(_t(v.duration), style: K.s(12, c: K.t2)),
                    ]);
                  }),
                ],
              ])),
            )),
          ),
        ]),
      ),
    );
  }
}
