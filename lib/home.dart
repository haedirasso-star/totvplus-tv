import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core.dart';
import 'pair.dart';
import 'player.dart';
import 'ui.dart';

// ════════════════════════════════════════════════════════════════════
//  الواجهة: شريط جانبي (الرئيسية · TOTV Live · القنوات · أفلام · مسلسلات · بحث · المزيد)
//  الرئيسية تبدأ بقناتنا TOTV Live ثم الأحدث — كل شيء بالريموت
// ════════════════════════════════════════════════════════════════════
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  final _tabs = const [
    (Icons.home_rounded, 'الرئيسية'), (Icons.live_tv_rounded, 'TOTV Live'), (Icons.tv_rounded, 'القنوات'),
    (Icons.movie_rounded, 'أفلام'), (Icons.video_library_rounded, 'مسلسلات'), (Icons.search_rounded, 'بحث'),
    (Icons.more_horiz_rounded, 'المزيد'),
  ];
  DateTime _back = DateTime(2000);

  @override
  void initState() {
    super.initState();
    Catalog.rev.addListener(_r); Sub.rev.addListener(_r);
    Catalog.load();
    if (!Sub.loaded) Sub.load();
  }
  @override
  void dispose() { Catalog.rev.removeListener(_r); Sub.rev.removeListener(_r); super.dispose(); }
  void _r() { if (mounted) setState(() {}); }

  Widget _page() => switch (_tab) {
        0 => const HomePage(),
        1 => const TotvLivePage(),
        2 => const ChannelsPage(),
        3 => const VodPage(series: false),
        4 => const VodPage(series: true),
        5 => const SearchPage(),
        _ => const MorePage(),
      };

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (did, _) {
      if (did) return;
      if (_tab != 0) { setState(() => _tab = 0); return; }
      if (DateTime.now().difference(_back).inSeconds < 2) { SystemNavigator.pop(); return; }
      _back = DateTime.now();
      toast(context, 'اضغط رجوع مرة أخرى للخروج');
    },
    child: Scaffold(
      backgroundColor: K.bg,
      body: Directionality(textDirection: TextDirection.rtl, child: Row(children: [
        // ── الشريط الجانبي ──
        Container(
          width: 168, color: K.panel,
          padding: const EdgeInsets.fromLTRB(10, 22, 10, 16),
          child: FocusTraversalGroup(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(padding: const EdgeInsets.fromLTRB(8, 0, 8, 18), child: Text('TOTV+', style: K.s(22, w: FontWeight.w900, c: K.gold))),
            for (var i = 0; i < _tabs.length; i++) Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: TvFocus(
                autofocus: i == 0, scale: 1.02, radius: 9,
                onFocus: (f) { if (f && _tab != i) setState(() => _tab = i); },
                onTap: () => setState(() => _tab = i),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  color: _tab == i ? K.gold.withValues(alpha: .12) : Colors.transparent,
                  child: Row(children: [
                    Icon(_tabs[i].$1, size: 19, color: _tab == i ? K.gold : (i == 1 ? K.red : K.t2)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_tabs[i].$2, style: K.s(13.5, w: _tab == i ? FontWeight.w800 : FontWeight.w600, c: _tab == i ? K.t1 : K.t2))),
                  ]),
                ),
              ),
            ),
            const Spacer(),
            if (Sub.loaded) Padding(padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(Sub.active ? 'مشترك حتى ${Sub.expiry!.year}/${Sub.expiry!.month}/${Sub.expiry!.day}' : 'لا يوجد اشتراك فعّال',
                    style: K.s(10.5, c: Sub.active ? K.t3 : K.red))),
          ])),
        ),
        // ── المحتوى ──
        Expanded(child: FocusTraversalGroup(child: KeyedSubtree(key: ValueKey(_tab), child: _page()))),
      ])),
    ),
  );
}

// ── الرئيسية ──────────────────────────────────────────────────────
class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    final mv = Catalog.homeMovies(), sr = Catalog.homeSeries();
    final ch = Catalog.live.take(20).toList();
    return ListView(padding: const EdgeInsets.fromLTRB(28, 22, 28, 30), children: [
      const _LiveHero(),
      if (mv.isEmpty && sr.isEmpty) const Padding(padding: EdgeInsets.all(40), child: Loading()),
      Rail(title: 'أحدث الأفلام', height: PosterCard.h + 32, items: [
        for (final m in mv.take(30)) PosterCard(m: m, img: Catalog.img(m), onTap: () => openMovie(context, m)),
      ]),
      Rail(title: 'أحدث المسلسلات', height: PosterCard.h + 32, items: [
        for (final s in sr.take(30)) PosterCard(m: s, img: Catalog.img(s), onTap: () => openSeries(context, s)),
      ]),
      Rail(title: 'قنوات مباشرة', height: ChannelCard.h + 30, items: [
        for (var i = 0; i < ch.length; i++) ChannelCard(m: ch[i], img: Catalog.img(ch[i]), onTap: () => playChannels(context, ch, i)),
      ]),
    ]);
  }
}

/// بطاقة قناتنا في أعلى الرئيسية
class _LiveHero extends StatelessWidget {
  const _LiveHero();
  @override
  Widget build(BuildContext context) => TvFocus(
    autofocus: false, scale: 1.015, radius: 16,
    onTap: () => playTotvLive(context),
    child: Container(
      height: 168,
      decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF3A0D10), Color(0xFF15151C)],
          begin: Alignment.centerRight, end: Alignment.centerLeft)),
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(children: [
        Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(color: K.red, borderRadius: BorderRadius.circular(6)),
              child: Text('● مباشر', style: K.s(11.5, w: FontWeight.w800))),
          const SizedBox(height: 10),
          Text('TOTV Live', style: K.s(28, w: FontWeight.w900)),
          Text('قناتنا الحصرية — المباريات والبرامج بجودة عالية', style: K.s(13.5, c: K.t2)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(color: K.gold, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            const Icon(Icons.play_arrow_rounded, color: Colors.black),
            const SizedBox(width: 4),
            Text('شاهد الآن', style: K.s(14, w: FontWeight.w900, c: Colors.black)),
          ]),
        ),
      ]),
    ),
  );
}

// ── قناتنا ─────────────────────────────────────────────────────────
class TotvLivePage extends StatelessWidget {
  const TotvLivePage({super.key});
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(28, 22, 28, 30), children: [
    const _LiveHero(),
    const SizedBox(height: 18),
    Text('تبث TOTV Live المباريات الكبرى والبرامج الرياضية مباشرة. إن لم يكن هناك بث الآن ستظهر رسالة بموعد البث القادم.',
        style: K.s(13.5, c: K.t2, h: 1.6)),
  ]);
}

Future<void> playTotvLive(BuildContext c) async {
  try {
    final (urls, xt) = await TotvLive.urls();
    if (!c.mounted) return;
    PlayerPage.open(c, [PlayItem(title: 'TOTV Live', live: true, direct: urls,
        url: xt.isEmpty ? null : () => Brain.live(xt))]);
  } catch (e) { if (c.mounted) toast(c, '$e', err: true); }
}

void playChannels(BuildContext c, List<Map<String, dynamic>> list, int i) {
  PlayerPage.open(c, [for (final m in list) PlayItem(title: '${m['name'] ?? ''}', live: true, url: () => Brain.live(m['stream_id']))], i);
}

void openMovie(BuildContext c, Map<String, dynamic> m) => Navigator.of(c).push(MaterialPageRoute(builder: (_) => MovieDetail(m: m)));
void openSeries(BuildContext c, Map<String, dynamic> s) => Navigator.of(c).push(MaterialPageRoute(builder: (_) => SeriesDetail(s: s)));

// ── القنوات: الأقسام يميناً والقنوات شبكة ─────────────────────────
class ChannelsPage extends StatefulWidget {
  const ChannelsPage({super.key});
  @override State<ChannelsPage> createState() => _ChannelsPageState();
}

class _ChannelsPageState extends State<ChannelsPage> {
  String _cat = '';
  @override
  Widget build(BuildContext context) {
    final cats = Catalog.cats['live'] ?? const [];
    final list = _cat.isEmpty ? Catalog.live : Catalog.live.where((x) => '${x['category_id']}' == _cat).toList();
    if (Catalog.live.isEmpty) return const Loading();
    return Row(children: [
      SizedBox(width: 190, child: ListView(padding: const EdgeInsets.fromLTRB(8, 22, 8, 20), children: [
        _catTile('', 'كل القنوات'),
        for (final c in cats) _catTile('${c['category_id']}', '${c['category_name'] ?? ''}'),
      ])),
      Expanded(child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: ChannelCard.w + 12, mainAxisExtent: ChannelCard.h + 34,
            crossAxisSpacing: 12, mainAxisSpacing: 8),
        itemCount: list.length,
        itemBuilder: (_, i) => ChannelCard(m: list[i], img: Catalog.img(list[i]), onTap: () => playChannels(context, list, i)),
      )),
    ]);
  }

  Widget _catTile(String id, String name) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: TvFocus(scale: 1.0, radius: 8, onFocus: (f) { if (f) setState(() => _cat = id); }, onTap: () => setState(() => _cat = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: _cat == id ? K.gold.withValues(alpha: .1) : Colors.transparent,
        child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: K.s(12.5, c: _cat == id ? K.gold : K.t2)),
      )),
  );
}

// ── أفلام / مسلسلات ────────────────────────────────────────────────
class VodPage extends StatefulWidget {
  final bool series;
  const VodPage({super.key, required this.series});
  @override State<VodPage> createState() => _VodPageState();
}

class _VodPageState extends State<VodPage> {
  String _cat = '';
  int _limit = 60;
  @override
  Widget build(BuildContext context) {
    final all = widget.series ? Catalog.series : Catalog.movies;
    final cats = Catalog.cats[widget.series ? 'series' : 'movie'] ?? const [];
    if (all.isEmpty) return const Loading();
    final list = _cat.isEmpty ? all : all.where((x) => '${x['category_id']}' == _cat).toList();
    return Row(children: [
      SizedBox(width: 190, child: ListView(padding: const EdgeInsets.fromLTRB(8, 22, 8, 20), children: [
        _catTile('', widget.series ? 'كل المسلسلات' : 'كل الأفلام'),
        for (final c in cats) _catTile('${c['category_id']}', '${c['category_name'] ?? ''}'),
      ])),
      Expanded(child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: PosterCard.w + 14, mainAxisExtent: PosterCard.h + 34,
            crossAxisSpacing: 14, mainAxisSpacing: 8),
        itemCount: list.length.clamp(0, _limit),
        itemBuilder: (_, i) {
          if (i == _limit - 8 && _limit < list.length) WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _limit += 60); });
          final m = list[i];
          return PosterCard(m: m, img: Catalog.img(m), onTap: () => widget.series ? openSeries(context, m) : openMovie(context, m));
        },
      )),
    ]);
  }

  Widget _catTile(String id, String name) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: TvFocus(scale: 1.0, radius: 8, onFocus: (f) { if (f && _cat != id) setState(() { _cat = id; _limit = 60; }); },
      onTap: () => setState(() { _cat = id; _limit = 60; }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: _cat == id ? K.gold.withValues(alpha: .1) : Colors.transparent,
        child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: K.s(12.5, c: _cat == id ? K.gold : K.t2)),
      )),
  );
}

// ── تفاصيل فيلم ───────────────────────────────────────────────────
class MovieDetail extends StatelessWidget {
  final Map<String, dynamic> m;
  const MovieDetail({super.key, required this.m});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: K.bg,
    body: Directionality(textDirection: TextDirection.rtl, child: Padding(
      padding: const EdgeInsets.fromLTRB(56, 40, 56, 40),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(borderRadius: BorderRadius.circular(14), child: NetImg(Catalog.img(m), w: 200, h: 296, fallback: '${m['name'] ?? ''}')),
        const SizedBox(width: 32),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${m['name'] ?? ''}', style: K.s(26, w: FontWeight.w900)),
          const SizedBox(height: 8),
          if ('${m['rating'] ?? ''}'.isNotEmpty && '${m['rating']}' != '0')
            Row(children: [const Icon(Icons.star_rounded, color: K.gold, size: 18), const SizedBox(width: 4), Text('${m['rating']}', style: K.s(14, c: K.t2))]),
          const SizedBox(height: 24),
          TvFocus(autofocus: true, radius: 10, onTap: () => PlayerPage.open(context, [
            PlayItem(title: '${m['name'] ?? ''}', url: () => Brain.movie(m['stream_id'], '${m['container_extension'] ?? ''}')),
          ]), child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12), color: K.gold,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.play_arrow_rounded, color: Colors.black), const SizedBox(width: 6),
              Text('تشغيل', style: K.s(16, w: FontWeight.w900, c: Colors.black)),
            ]))),
        ])),
      ]),
    )),
  );
}

// ── تفاصيل مسلسل: المواسم ثم الحلقات ────────────────────────────────
class SeriesDetail extends StatefulWidget {
  final Map<String, dynamic> s;
  const SeriesDetail({super.key, required this.s});
  @override State<SeriesDetail> createState() => _SeriesDetailState();
}

class _SeriesDetailState extends State<SeriesDetail> {
  Map<String, dynamic>? _d;
  bool _loading = true;
  String _season = '';

  @override
  void initState() {
    super.initState();
    Catalog.episodes(int.tryParse('${widget.s['series_id']}') ?? 0).then((d) {
      if (!mounted) return;
      setState(() {
        _d = d; _loading = false;
        final eps = d?['episodes'];
        if (eps is Map && eps.isNotEmpty) _season = '${(eps.keys.toList()..sort((a, b) => (int.tryParse('$a') ?? 0).compareTo(int.tryParse('$b') ?? 0))).first}';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final eps = _d?['episodes'] is Map ? Map<String, dynamic>.from(_d!['episodes'] as Map) : <String, dynamic>{};
    final seasons = eps.keys.toList()..sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));
    final list = [for (final e in (eps[_season] as List? ?? const [])) if (e is Map) Map<String, dynamic>.from(e)];
    return Scaffold(
      backgroundColor: K.bg,
      body: Directionality(textDirection: TextDirection.rtl, child: Padding(
        padding: const EdgeInsets.fromLTRB(48, 32, 48, 24),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(borderRadius: BorderRadius.circular(14), child: NetImg(Catalog.img(widget.s), w: 170, h: 250, fallback: '${widget.s['name'] ?? ''}')),
          const SizedBox(width: 28),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${widget.s['name'] ?? ''}', style: K.s(24, w: FontWeight.w900)),
            const SizedBox(height: 12),
            if (_loading) const Padding(padding: EdgeInsets.all(30), child: Loading())
            else if (eps.isEmpty) Text('الحلقات غير متاحة الآن', style: K.s(14, c: K.t2))
            else ...[
              SizedBox(height: 40, child: ListView(scrollDirection: Axis.horizontal, children: [
                for (final s in seasons) Padding(padding: const EdgeInsets.only(left: 8), child: TvFocus(
                  autofocus: s == _season, radius: 8, scale: 1.03,
                  onTap: () => setState(() => _season = s), onFocus: (f) { if (f) setState(() => _season = s); },
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      color: s == _season ? K.gold : K.card,
                      child: Text('الموسم $s', style: K.s(13, w: FontWeight.w800, c: s == _season ? Colors.black : K.t1))),
                )),
              ])),
              const SizedBox(height: 14),
              Expanded(child: ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (_, i) {
                  final e = list[i];
                  return TvFocus(radius: 8, scale: 1.01, onTap: () => PlayerPage.open(context, [
                    for (final x in list) PlayItem(title: '${widget.s['name'] ?? ''} — ${x['title'] ?? 'الحلقة ${x['episode_num'] ?? ''}'}',
                        url: () => Brain.episode(x['id'], '${x['container_extension'] ?? ''}')),
                  ], i), child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), color: K.card,
                    child: Row(children: [
                      Text('${e['episode_num'] ?? i + 1}', style: K.s(15, w: FontWeight.w900, c: K.gold)),
                      const SizedBox(width: 14),
                      Expanded(child: Text('${e['title'] ?? 'الحلقة ${e['episode_num'] ?? i + 1}'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: K.s(13.5))),
                      const Icon(Icons.play_circle_outline_rounded, color: K.t3, size: 20),
                    ]),
                  ));
                },
              )),
            ],
          ])),
        ]),
      )),
    );
  }
}

// ── بحث (لوحة أحرف بالريموت بلا كيبورد) ──────────────────────────
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  @override State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  String _q = '';
  static const _keys = 'ابتثجحخدذرزسشصضطظعغفقكلمنهويةى 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  Timer? _deb;
  List<Map<String, dynamic>> _res = [];

  void _run() {
    _deb?.cancel();
    _deb = Timer(const Duration(milliseconds: 250), () {
      final q = _q.trim().toLowerCase();
      if (q.length < 2) { setState(() => _res = []); return; }
      bool hit(Map m) => '${m['name'] ?? ''}'.toLowerCase().contains(q);
      setState(() => _res = [
        ...Catalog.live.where(hit).take(12).map((e) => {...e, '_k': 'live'}),
        ...Catalog.movies.where(hit).take(24).map((e) => {...e, '_k': 'movie'}),
        ...Catalog.series.where(hit).take(24).map((e) => {...e, '_k': 'series'}),
      ]);
    });
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 300, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), color: K.card,
            child: Text(_q.isEmpty ? 'اكتب اسم فيلم أو مسلسل أو قناة' : _q, style: K.s(15, c: _q.isEmpty ? K.t3 : K.t1))),
        const SizedBox(height: 10),
        Wrap(spacing: 5, runSpacing: 5, children: [
          for (final ch in _keys.split('')) TvFocus(radius: 6, scale: 1.12, autofocus: ch == 'ا',
            onTap: () { setState(() => _q += ch); _run(); },
            child: Container(width: 34, height: 32, alignment: Alignment.center, color: K.card,
                child: Text(ch == ' ' ? '␣' : ch, style: K.s(13.5, w: FontWeight.w700)))),
          TvFocus(radius: 6, onTap: () { if (_q.isNotEmpty) setState(() => _q = _q.substring(0, _q.length - 1)); _run(); },
            child: Container(width: 73, height: 32, alignment: Alignment.center, color: K.card, child: const Icon(Icons.backspace_outlined, size: 17, color: K.t1))),
          TvFocus(radius: 6, onTap: () { setState(() { _q = ''; _res = []; }); },
            child: Container(width: 73, height: 32, alignment: Alignment.center, color: K.card, child: Text('مسح', style: K.s(13)))),
        ]),
      ])),
      const SizedBox(width: 24),
      Expanded(child: _res.isEmpty
          ? Center(child: Text(_q.length < 2 ? 'النتائج تظهر هنا' : 'لا نتائج', style: K.s(14, c: K.t3)))
          : GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: PosterCard.w + 14, mainAxisExtent: PosterCard.h + 34,
                  crossAxisSpacing: 14, mainAxisSpacing: 8),
              itemCount: _res.length,
              itemBuilder: (_, i) {
                final m = _res[i];
                return PosterCard(m: m, img: Catalog.img(m), onTap: () {
                  if (m['_k'] == 'live') { playChannels(context, [m], 0); }
                  else if (m['_k'] == 'series') { openSeries(context, m); }
                  else { openMovie(context, m); }
                });
              })),
    ]),
  );
}

// ── المزيد: الاشتراك · الحساب · الدعم ────────────────────────────
class MorePage extends StatelessWidget {
  const MorePage({super.key});
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(28, 26, 28, 30), children: [
    Text('حسابي', style: K.s(20, w: FontWeight.w900)),
    const SizedBox(height: 14),
    Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: K.card, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Icon(Sub.active ? Icons.verified_rounded : Icons.error_outline_rounded, color: Sub.active ? K.green : K.red, size: 30),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(Sub.active ? 'اشتراك فعّال' : 'لا يوجد اشتراك فعّال', style: K.s(16, w: FontWeight.w800)),
          if (Sub.expiry != null) Text('ينتهي ${Sub.expiry!.year}/${Sub.expiry!.month}/${Sub.expiry!.day}', style: K.s(13, c: K.t2)),
          if (Sub.agent.isNotEmpty) Text('وكيلك: ${Sub.agent}', style: K.s(12.5, c: K.t3)),
        ])),
      ])),
    const SizedBox(height: 14),
    Text('للتجديد أو تغيير الباقة استخدم تطبيق TOTV+ على هاتفك أو تواصل مع وكيلك.', style: K.s(13, c: K.t2, h: 1.6)),
    const SizedBox(height: 22),
    Wrap(spacing: 12, runSpacing: 12, children: [
      TvFocus(radius: 10, onTap: () { Sub.load(); Catalog.load(); toast(context, 'جاري التحديث…'); },
        child: _btn(Icons.sync_rounded, 'تحديث المحتوى')),
      TvFocus(radius: 10, onTap: () async {
        await Auth.signOut();
        if (context.mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const PairScreen()), (_) => false);
      }, child: _btn(Icons.logout_rounded, 'فصل هذه الشاشة')),
    ]),
    const SizedBox(height: 30),
    Text('TOTV+ للشاشات · الإصدار $kVersion', style: K.s(11.5, c: K.t3)),
  ]);

  static Widget _btn(IconData i, String t) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12), color: K.card,
    child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(i, size: 19, color: K.t1), const SizedBox(width: 8), Text(t, style: K.s(14, w: FontWeight.w700))]));
}
