import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'api.dart';
import 'ui.dart';
import 'player.dart';
import 'series_detail.dart';
import 'login.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

enum Section { home, movies, series, live, search, account }

class _HomePageState extends State<HomePage> {
  Section _sec = Section.home;
  bool _loading = true;
  String _backdrop = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!Api.loaded) await Api.loadAll();
    _pickBackdrop();
    if (mounted) setState(() => _loading = false);
  }

  void _pickBackdrop() {
    for (final m in Api.movies) {
      final l = sLogo(m);
      if (l.isNotEmpty) { _backdrop = l; break; }
    }
  }

  // تجميع العناصر حسب الفئة
  Map<String, List<dynamic>> _group(List<dynamic> items, List<dynamic> cats) {
    final catName = <String, String>{
      for (final c in cats) (c['category_id']?.toString() ?? ''): (c['category_name'] ?? c['name'] ?? '').toString()
    };
    final out = <String, List<dynamic>>{};
    for (final it in items) {
      final name = catName[sCat(it)] ?? 'أخرى';
      (out[name] ??= []).add(it);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: K.gold)),
      );
    }
    return Scaffold(
      body: Row(children: [
        _sidebar(),
        Expanded(child: _content()),
      ]),
    );
  }

  // ── الشريط الجانبي ──────────────────────────────────────────
  Widget _sidebar() {
    Widget item(Section s, IconData ic, String label) {
      final on = _sec == s;
      return TvFocus(
        scale: 1.0,
        onSelect: () => setState(() => _sec = s),
        builder: (f) => Container(
          width: 168,
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: f ? K.gold.withOpacity(0.16) : (on ? Colors.white10 : Colors.transparent),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: f ? K.gold : Colors.transparent, width: 2),
          ),
          child: Row(children: [
            Icon(ic, color: f || on ? K.gold : K.sub, size: 22),
            const SizedBox(width: 12),
            Text(label, style: K.ar(s: 15, w: f || on ? FontWeight.w800 : FontWeight.w500,
                c: f || on ? K.gold : K.sub)),
          ]),
        ),
      );
    }

    return Container(
      width: 190,
      color: K.bg2,
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
            child: Text('TOTV+', style: K.en(s: 24, c: K.gold, ls: 2))),
          item(Section.home, Icons.home_rounded, 'الرئيسية'),
          item(Section.movies, Icons.movie_rounded, 'أفلام'),
          item(Section.series, Icons.live_tv_rounded, 'مسلسلات'),
          item(Section.live, Icons.podcasts_rounded, 'البث المباشر'),
          item(Section.search, Icons.search_rounded, 'بحث'),
          item(Section.account, Icons.person_rounded, 'حسابي'),
          const Spacer(),
          TvFocus(
            scale: 1.0,
            onSelect: () async {
              await Session.logout();
              if (mounted) {
                Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (_) => const LoginPage()));
              }
            },
            builder: (f) => Container(
              width: 168,
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: f ? const Color(0xFFE53935).withOpacity(0.16) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: f ? const Color(0xFFE53935) : Colors.transparent, width: 2),
              ),
              child: Row(children: [
                Icon(Icons.logout_rounded, color: f ? const Color(0xFFE53935) : K.sub, size: 22),
                const SizedBox(width: 12),
                Text('خروج', style: K.ar(s: 15, w: f ? FontWeight.w800 : FontWeight.w500,
                    c: f ? const Color(0xFFE53935) : K.sub)),
              ]),
            ),
          ),
          const SizedBox(height: 10),
        ]),
      ),
    );
  }

  // ── المحتوى حسب القسم ───────────────────────────────────────
  Widget _content() {
    switch (_sec) {
      case Section.movies:
        return CategoryBrowse(items: Api.movies, cats: Api.movieCats, type: 'movie', onOpen: _open);
      case Section.series:
        return CategoryBrowse(items: Api.series, cats: Api.seriesCats, type: 'series', onOpen: _open);
      case Section.live:
        return CategoryBrowse(items: Api.live, cats: Api.liveCats, type: 'live', onOpen: _open);
      case Section.search:
        return SearchView(onPlay: _open);
      case Section.account:
        return AccountView(backdrop: _backdrop);
      case Section.home:
        return _homeView();
    }
  }

  Widget _homeView() {
    // الرئيسية: مزيج — أحدث الأفلام + المسلسلات + المباشر
    final rails = <String, List<dynamic>>{
      '🎬 أفلام مختارة': Api.movies.take(20).toList(),
      '📺 مسلسلات': Api.series.take(20).toList(),
      '🔴 قنوات مباشرة': Api.live.take(20).toList(),
    };
    return Stack(children: [
      // خلفية بوستر فخمة
      if (_backdrop.isNotEmpty)
        Positioned.fill(child: Opacity(opacity: 0.18,
          child: CachedNetworkImage(imageUrl: _backdrop, fit: BoxFit.cover,
              errorWidget: (_, __, ___) => const SizedBox()))),
      Positioned.fill(child: Container(decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight,
          colors: [K.bg, K.bg.withOpacity(0.6)])))),
      _railsList(rails, mixedType: true),
    ]);
  }

  Widget _rails(Map<String, List<dynamic>> groups, String type) {
    if (groups.isEmpty) {
      return Center(child: Text('لا يوجد محتوى', style: K.ar(s: 16, c: K.sub)));
    }
    return _railsList(groups, forcedType: type);
  }

  Widget _railsList(Map<String, List<dynamic>> groups, {String? forcedType, bool mixedType = false}) {
    final entries = groups.entries.toList();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 30),
      itemCount: entries.length,
      itemBuilder: (_, ri) {
        final e = entries[ri];
        final type = forcedType ?? _guessType(e.key);
        final isLive = type == 'live';
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(bottom: 10, top: 6),
            child: Text(e.key, style: K.ar(s: 18, w: FontWeight.w800))),
          SizedBox(
            height: isLive ? 150 : 250,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: e.value.length,
              itemBuilder: (_, i) {
                final it = e.value[i];
                final auto = ri == 0 && i == 0;
                if (isLive) {
                  return LiveCard(title: sName(it), logo: sLogo(it), autofocus: auto,
                      onSelect: () => _open(it, 'live'));
                }
                final t = mixedType ? _typeOf(it) : type;
                return PosterCard(title: sName(it), logo: sLogo(it), autofocus: auto,
                    onSelect: () => _open(it, t));
              },
            ),
          ),
          const SizedBox(height: 12),
        ]);
      },
    );
  }

  String _guessType(String railKey) {
    if (railKey.contains('مباشر') || railKey.contains('🔴')) return 'live';
    if (railKey.contains('مسلسل') || railKey.contains('📺')) return 'series';
    return 'movie';
  }

  String _typeOf(dynamic it) {
    if (it is Map && it['series_id'] != null) return 'series';
    if (it is Map && (it['stream_type'] == 'live')) return 'live';
    return 'movie';
  }

  void _open(dynamic item, String type) {
    if (type == 'series') {
      Navigator.push(context, MaterialPageRoute(
          builder: (_) => SeriesDetailPage(item: item)));
    } else if (type == 'live') {
      // ★ المباشر عبر HLS (m3u8) — متوافق مع ExoPlayer، مع احتياطي ts
      final id = sId(item);
      Navigator.push(context, MaterialPageRoute(
          builder: (_) => PlayerPage(
            url: Api.streamUrl('live', id, 'm3u8'),
            fallbackUrl: Api.streamUrl('live', id, 'ts'),
            title: sName(item), isLive: true)));
    } else {
      final url = Api.streamUrl('movie', sId(item), sExt(item));
      Navigator.push(context, MaterialPageRoute(
          builder: (_) => PlayerPage(url: url, title: sName(item), isLive: false)));
    }
  }
}

/// ── البحث ─────────────────────────────────────────────────────
class SearchView extends StatefulWidget {
  final void Function(dynamic, String) onPlay;
  const SearchView({super.key, required this.onPlay});
  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  final _c = TextEditingController();
  List<MapEntry<dynamic, String>> _res = [];

  void _search(String raw) {
    final q = raw.trim().toLowerCase();
    if (q.length < 2) { setState(() => _res = []); return; }
    final out = <MapEntry<dynamic, String>>[];
    for (final m in Api.movies) {
      if (sName(m).toLowerCase().contains(q)) { out.add(MapEntry(m, 'movie')); if (out.length >= 80) break; }
    }
    for (final s in Api.series) {
      if (sName(s).toLowerCase().contains(q)) { out.add(MapEntry(s, 'series')); if (out.length >= 130) break; }
    }
    for (final l in Api.live) {
      if (sName(l).toLowerCase().contains(q)) { out.add(MapEntry(l, 'live')); if (out.length >= 160) break; }
    }
    setState(() => _res = out);
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final res = _res;
    final q = _c.text.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          decoration: BoxDecoration(color: K.card, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: K.gold.withOpacity(0.4))),
          child: TextField(
            controller: _c,
            autofocus: true,
            style: K.ar(s: 16),
            onChanged: _search,
            decoration: InputDecoration(
              hintText: 'ابحث عن فيلم أو مسلسل أو قناة…',
              hintStyle: K.ar(s: 14, c: K.dim),
              prefixIcon: const Icon(Icons.search_rounded, color: K.gold),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(child: res.isEmpty
          ? Center(child: Text(q.length < 2 ? 'اكتب حرفين على الأقل للبحث' : 'لا نتائج', style: K.ar(s: 15, c: K.sub)))
          : GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 170, childAspectRatio: 0.62,
                crossAxisSpacing: 4, mainAxisSpacing: 14),
              itemCount: res.length,
              itemBuilder: (_, i) {
                final e = res[i];
                return PosterCard(title: sName(e.key), logo: sLogo(e.key), autofocus: i == 0,
                    onSelect: () => widget.onPlay(e.key, e.value));
              },
            )),
      ]),
    );
  }
}

/// ── حسابي ─────────────────────────────────────────────────────
class AccountView extends StatelessWidget {
  final String backdrop;
  const AccountView({super.key, required this.backdrop});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      if (backdrop.isNotEmpty)
        Positioned.fill(child: Opacity(opacity: 0.14,
          child: CachedNetworkImage(imageUrl: backdrop, fit: BoxFit.cover,
              errorWidget: (_, __, ___) => const SizedBox()))),
      Positioned.fill(child: Container(color: K.bg.withOpacity(0.7))),
      Center(child: SingleChildScrollView(
        child: Container(
          width: 560,
          padding: const EdgeInsets.all(34),
          decoration: BoxDecoration(
            color: K.bg2.withOpacity(0.85),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: K.gold.withOpacity(0.25)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // شارة بريميوم
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFFD479), K.gold]),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [BoxShadow(color: K.gold.withOpacity(0.4), blurRadius: 20)]),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.workspace_premium_rounded, color: Colors.black, size: 22),
                const SizedBox(width: 9),
                Text('PREMIUM', style: K.en(s: 18, c: Colors.black, ls: 3)),
              ]),
            ),
            const SizedBox(height: 12),
            Text('مرحباً ${Session.user}', style: K.ar(s: 18, w: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('اشتراكك فعّال — استمتع بكل المحتوى', style: K.ar(s: 13, c: K.sub)),
            const SizedBox(height: 28),

            // زر تلجرام
            _ContactBtn(
              icon: Icons.telegram_rounded, label: 'قناة تلجرام', sub: 'آخر الأخبار والتحديثات',
              color: const Color(0xFF2AABEE), autofocus: true,
              onTap: () => openUrl(kTelegram)),
            const SizedBox(height: 12),
            // زر واتساب
            _ContactBtn(
              icon: Icons.support_agent_rounded, label: 'واتساب الدعم / شراء اشتراك',
              sub: kWhatsAppDisplay, color: const Color(0xFF25D366),
              onTap: () => openUrl('https://wa.me/$kWhatsApp?text=${Uri.encodeComponent("مرحباً، أريد الاستفسار عن اشتراك TOTV+")}')),
            const SizedBox(height: 12),
            // تسجيل خروج
            _ContactBtn(
              icon: Icons.logout_rounded, label: 'تسجيل الخروج', sub: 'الخروج من الحساب',
              color: const Color(0xFFE53935),
              onTap: () async {
                await Session.logout();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(context,
                      MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false);
                }
              }),
          ]),
        ),
      )),
    ]);
  }
}

class _ContactBtn extends StatelessWidget {
  final IconData icon; final String label, sub; final Color color;
  final VoidCallback onTap; final bool autofocus;
  const _ContactBtn({required this.icon, required this.label, required this.sub,
      required this.color, required this.onTap, this.autofocus = false});
  @override
  Widget build(BuildContext context) => TvFocus(
    autofocus: autofocus, scale: 1.03, onSelect: onTap,
    builder: (f) => Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      decoration: BoxDecoration(
        color: f ? color.withOpacity(0.18) : K.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: f ? color : Colors.white10, width: 2),
        boxShadow: f ? [BoxShadow(color: color.withOpacity(0.35), blurRadius: 18)] : null),
      child: Row(children: [
        Container(width: 44, height: 44,
          decoration: BoxDecoration(color: color.withOpacity(0.18), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 24)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: K.ar(s: 15, w: FontWeight.w800, c: f ? color : K.text)),
          Text(sub, style: K.ar(s: 12, c: K.sub)),
        ])),
        Icon(Icons.arrow_forward_ios_rounded, color: f ? color : K.dim, size: 16),
      ]),
    ),
  );
}

/// ── تصفّح حسب الفئة (يعرض كل الأقسام وكل المحتوى في شبكة) ──────
class CategoryBrowse extends StatefulWidget {
  final List<dynamic> items;
  final List<dynamic> cats;
  final String type; // movie | series | live
  final void Function(dynamic, String) onOpen;
  const CategoryBrowse({super.key, required this.items, required this.cats,
      required this.type, required this.onOpen});
  @override
  State<CategoryBrowse> createState() => _CategoryBrowseState();
}

class _CategoryBrowseState extends State<CategoryBrowse> {
  String _catId = 'all';

  // فئات مرتّبة + عدد عناصر كل فئة
  List<MapEntry<String, String>> get _cats {
    final counts = <String, int>{};
    for (final it in widget.items) {
      final c = sCat(it);
      counts[c] = (counts[c] ?? 0) + 1;
    }
    final list = <MapEntry<String, String>>[MapEntry('all', 'الكل')];
    for (final c in widget.cats) {
      final id = (c['category_id'] ?? '').toString();
      final name = (c['category_name'] ?? c['name'] ?? '').toString();
      if (id.isEmpty || name.isEmpty) continue;
      if ((counts[id] ?? 0) == 0) continue; // أخفِ الفئات الفارغة
      list.add(MapEntry(id, name));
    }
    return list;
  }

  List<dynamic> get _shown {
    if (_catId == 'all') return widget.items;
    return widget.items.where((it) => sCat(it) == _catId).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cats = _cats;
    final shown = _shown;
    final isLive = widget.type == 'live';
    return Row(children: [
      // قائمة الفئات (يسار) — قابلة للتنقّل بالريموت
      Container(
        width: 230,
        color: K.bg2.withOpacity(0.5),
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          itemCount: cats.length,
          itemBuilder: (_, i) {
            final e = cats[i];
            final on = e.key == _catId;
            return TvFocus(
              scale: 1.0,
              autofocus: i == 0,
              onSelect: () => setState(() => _catId = e.key),
              builder: (f) => Container(
                margin: const EdgeInsets.symmetric(vertical: 3),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: f ? K.gold.withOpacity(0.16) : (on ? Colors.white10 : Colors.transparent),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: f ? K.gold : Colors.transparent, width: 2),
                ),
                child: Text(e.value,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: K.ar(s: 14, w: f || on ? FontWeight.w800 : FontWeight.w500,
                        c: f || on ? K.gold : K.sub)),
              ),
            );
          },
        ),
      ),
      // الشبكة (يمين) — كل المحتوى
      Expanded(child: shown.isEmpty
        ? Center(child: Text('لا يوجد محتوى', style: K.ar(s: 16, c: K.sub)))
        : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
              child: Text('${cats.firstWhere((e) => e.key == _catId, orElse: () => const MapEntry('all','الكل')).value}  •  ${shown.length}',
                  style: K.ar(s: 15, w: FontWeight.w700, c: K.sub))),
            Expanded(child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: isLive ? 175 : 165,
                childAspectRatio: isLive ? 1.05 : 0.60,
                crossAxisSpacing: 6, mainAxisSpacing: 14),
              itemCount: shown.length,
              itemBuilder: (_, i) {
                final it = shown[i];
                if (isLive) {
                  return LiveCard(title: sName(it), logo: sLogo(it), autofocus: i == 0,
                      onSelect: () => widget.onOpen(it, 'live'));
                }
                return PosterCard(title: sName(it), logo: sLogo(it), autofocus: i == 0,
                    onSelect: () => widget.onOpen(it, widget.type));
              },
            )),
          ])),
    ]);
  }
}
