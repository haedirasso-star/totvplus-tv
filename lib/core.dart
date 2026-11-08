import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ════════════════════════════════════════════════════════════════════
//  TOTV+ TV — النواة: الحساب (Firebase عبر REST بلا SDK) · الخادم · العقل المدبر · الفهرس
//  خفيف عمداً: لا Firebase SDK ولا Firestore — نفس حساب واشتراك تطبيق الهاتف
// ════════════════════════════════════════════════════════════════════
const kFbKey = 'AIzaSyBR9NjEZHm9RhngSfYNMmphaH_gDLTApTY';
const kSupa = 'https://hlmaksidfqdarwunedqj.supabase.co';
const kSupaKey = 'sb_publishable_-lEvqrjoQgkXJdN4lZExxw_1cycMoEj';
const kBrain = 'https://totv-brain.haedirasso.workers.dev';
const kCdn = 'https://cdn.totv.app';
const kVersion = '2.0.0';

final _dio = Dio(BaseOptions(
  connectTimeout: const Duration(seconds: 8),
  receiveTimeout: const Duration(seconds: 25),
  validateStatus: (_) => true,
));

class Prefs {
  static late SharedPreferences p;
  static Future<void> init() async => p = await SharedPreferences.getInstance();
}

class ApiErr implements Exception {
  final String msg;
  ApiErr(this.msg);
  @override String toString() => msg;
}

// ── الحساب: رمز الدخول من الهاتف (باركود) ⇐ idToken يتجدد وحده ──────
class Auth {
  static String uid = '', _id = '', _refresh = '', name = '';
  static DateTime _exp = DateTime(2000);
  static bool get signedIn => _refresh.isNotEmpty;

  static Future<void> restore() async {
    uid = Prefs.p.getString('a_uid') ?? '';
    _refresh = Prefs.p.getString('a_rt') ?? '';
    name = Prefs.p.getString('a_name') ?? '';
  }

  static Future<void> _save() async {
    await Prefs.p.setString('a_uid', uid);
    await Prefs.p.setString('a_rt', _refresh);
    await Prefs.p.setString('a_name', name);
  }

  static Future<void> withCustomToken(String token) async {
    final r = await _dio.post('https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=$kFbKey',
        data: {'token': token, 'returnSecureToken': true});
    final d = r.data is Map ? r.data as Map : const {};
    if (d['idToken'] == null) throw ApiErr('تعذّر تسجيل الدخول');
    _id = '${d['idToken']}';
    _refresh = '${d['refreshToken']}';
    _exp = DateTime.now().add(Duration(seconds: int.tryParse('${d['expiresIn']}') ?? 3600) - const Duration(minutes: 5));
    uid = _uidOf(_id);
    await _save();
  }

  static String _uidOf(String jwt) {
    try {
      final p = jwt.split('.')[1];
      final j = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(p)))) as Map;
      return '${j['user_id'] ?? j['sub'] ?? ''}';
    } catch (_) { return ''; }
  }

  static Future<String> token() async {
    if (_id.isNotEmpty && DateTime.now().isBefore(_exp)) return _id;
    if (_refresh.isEmpty) throw ApiErr('سجّل الدخول');
    final r = await _dio.post('https://securetoken.googleapis.com/v1/token?key=$kFbKey',
        data: 'grant_type=refresh_token&refresh_token=$_refresh',
        options: Options(contentType: 'application/x-www-form-urlencoded'));
    final d = r.data is Map ? r.data as Map : const {};
    if (d['id_token'] == null) {
      if ((r.statusCode ?? 0) == 400) await signOut();   // الحساب أُزيل أو الرمز أُلغي
      throw ApiErr('انتهت الجلسة — اربط الشاشة من جديد');
    }
    _id = '${d['id_token']}';
    _refresh = '${d['refresh_token'] ?? _refresh}';
    _exp = DateTime.now().add(Duration(seconds: int.tryParse('${d['expires_in']}') ?? 3600) - const Duration(minutes: 5));
    await _save();
    return _id;
  }

  static Future<void> signOut() async {
    try { await Brain.release(); } catch (_) {}
    uid = ''; _id = ''; _refresh = ''; name = '';
    await Prefs.p.remove('a_uid'); await Prefs.p.remove('a_rt'); await Prefs.p.remove('a_name');
    Brain.reset();
  }
}

// ── الخادم (نفس Edge Function تطبيق الهاتف) ─────────────────────────
class Api {
  static Future<Map<String, dynamic>> _post(Map<String, dynamic> body) async {
    final r = await _dio.post('$kSupa/functions/v1/push', data: body,
        options: Options(headers: {'apikey': kSupaKey}, contentType: 'application/json'));
    final d = r.data is Map ? Map<String, dynamic>.from(r.data as Map) : <String, dynamic>{};
    if ((r.statusCode ?? 0) >= 300 || d['error'] != null) throw ApiErr('${d['error'] ?? 'الخدمة غير متاحة (${r.statusCode})'}');
    return d;
  }
  static Future<Map<String, dynamic>> pub(String action, [Map<String, dynamic> b = const {}]) => _post({...b, 'action': action});
  static Future<Map<String, dynamic>> call(String action, [Map<String, dynamic> b = const {}]) async =>
      _post({...b, 'action': action, 'idToken': await Auth.token()});
}

// ── الاشتراك ────────────────────────────────────────────────────────
class Sub {
  static bool active = false, loaded = false;
  static DateTime? expiry;
  static List<String> devices = const [];
  static String agent = '';
  static final rev = ValueNotifier(0);

  static Future<void> load() async {
    try {
      final r = await Api.call('my_sub');
      final s = r['sub'] is Map ? Map<String, dynamic>.from(r['sub'] as Map) : null;
      expiry = DateTime.tryParse('${s?['expiry_date'] ?? ''}')?.toLocal();
      active = expiry != null && expiry!.isAfter(DateTime.now());
      devices = [for (final x in (s?['devices'] as List? ?? const [])) '$x'];
      agent = r['agent'] is Map ? '${(r['agent'] as Map)['name'] ?? ''}' : '';
      loaded = true;
      rev.value++;
    } catch (e) { debugPrint('[sub] $e'); }
  }
}

// ── العقل المدبر: خط لكل تشغيل ─────────────────────────────────────
class Brain {
  static String host = '', user = '', pass = '', reason = '';
  static int line = 0;
  static String _did = '';
  static Timer? _beat;

  static String get did {
    if (_did.isNotEmpty) return _did;
    _did = Prefs.p.getString('did') ?? '';
    if (_did.isEmpty) {
      final r = math.Random.secure();
      _did = 'tv${List.generate(16, (_) => r.nextInt(36).toRadixString(36)).join()}';
      Prefs.p.setString('did', _did);
    }
    return _did;
  }

  static void reset() { host = ''; user = ''; pass = ''; line = 0; _beat?.cancel(); _beat = null; }

  static Future<bool> lease({int? bad}) async {
    try {
      final t = await Auth.token();
      final r = await _dio.post('$kBrain/lease', data: {'did': did, 'dev': 'tv', 'v': kVersion, if (bad != null) 'bad': bad},
          options: Options(headers: {'Authorization': 'Bearer $t'}, contentType: 'application/json'));
      final d = r.data is Map ? r.data as Map : const {};
      if (d['ok'] == true) {
        host = '${d['host'] ?? ''}'.replaceAll(RegExp(r'/+$'), '');
        user = '${d['username'] ?? ''}'; pass = '${d['password'] ?? ''}';
        line = (d['line'] as num?)?.toInt() ?? 0;
        reason = '';
        return true;
      }
      reason = '${d['reason'] ?? r.statusCode}';
      return false;
    } catch (e) { reason = 'net'; return host.isNotEmpty; }
  }

  /// أثناء المشاهدة: تجديد كل دقيقتين — يتوقف عند الخروج (الخط يرجع للمخزن)
  static void hold() {
    _beat?.cancel();
    _beat = Timer.periodic(const Duration(minutes: 2), (_) => lease());
  }

  static Future<void> release() async {
    _beat?.cancel(); _beat = null;
    if (!Auth.signedIn) return;
    try {
      final t = await Auth.token();
      await _dio.post('$kBrain/release', data: {'did': did},
          options: Options(headers: {'Authorization': 'Bearer $t'}, contentType: 'application/json'));
    } catch (_) {}
  }

  static String live(Object id) => '$host/live/$user/$pass/$id.ts';
  static String movie(Object id, String ext) => '$host/movie/$user/$pass/$id.${ext.isEmpty ? 'mp4' : ext}';
  static String episode(Object id, String ext) => '$host/series/$user/$pass/$id.${ext.isEmpty ? 'mp4' : ext}';

  static String get reasonText => switch (reason) {
        'sub' => 'اشتراكك منتهٍ أو موقوف — جدّده من هاتفك أو من وكيلك',
        'limit' => 'وصلت للحد الأقصى من الأجهزة التي تشاهد معاً — أغلق المشاهدة على جهاز آخر',
        'no_lines' => 'الخدمة مشغولة الآن — حاول بعد قليل',
        'auth' => 'انتهت الجلسة — اربط الشاشة من جديد',
        _ => 'تعذّر الاتصال — تحقق من الإنترنت',
      };
}

// ── الفهرس من موقعنا (نفس ملفات تطبيق الهاتف) ────────────────────────
class Catalog {
  static List<Map<String, dynamic>> live = [], movies = [], series = [];
  static Map<String, List<Map<String, dynamic>>> cats = {};
  static Map<String, dynamic> home = {};
  static Map<String, String> _ver = {};
  static final rev = ValueNotifier(0);
  static bool loading = false;

  static List<Map<String, dynamic>> _list(Object? v) =>
      [for (final x in (v is List ? v : const [])) if (x is Map) Map<String, dynamic>.from(x)];

  static Future<dynamic> _json(String path, String ver) async {
    final key = 'c_$path';
    final cachedVer = Prefs.p.getString('${key}_v');
    if (ver.isNotEmpty && cachedVer == ver) {
      final c = Prefs.p.getString(key);
      if (c != null) { try { return jsonDecode(c); } catch (_) {} }
    }
    final r = await _dio.get<String>('$kCdn/catalog/$path', queryParameters: {'v': ver.isEmpty ? DateTime.now().millisecondsSinceEpoch ~/ 600000 : ver},
        options: Options(responseType: ResponseType.plain));
    if ((r.statusCode ?? 0) != 200 || r.data == null) throw ApiErr('تعذّر تحميل المحتوى');
    final raw = r.data!;
    final out = raw.length > 200000 ? await compute(jsonDecode, raw) : jsonDecode(raw);
    if (ver.isNotEmpty && raw.length < 4000000) {           // الملفات الكبيرة جداً لا تُخزَّن في الإعدادات
      unawaited(Prefs.p.setString(key, raw));
      unawaited(Prefs.p.setString('${key}_v', ver));
    }
    return out;
  }

  static Future<void> load() async {
    if (loading) return;
    loading = true;
    try {
      final idx = await _json('index.json', '');
      _ver = idx is Map && idx['ver'] is Map ? (idx['ver'] as Map).map((k, v) => MapEntry('$k', '$v')) : {};
      final h = await _json('home.json', _ver['home'] ?? '');
      home = h is Map ? Map<String, dynamic>.from(h) : {};
      final c = await _json('cats.json', _ver['cats'] ?? '');
      if (c is Map) cats = c.map((k, v) => MapEntry('$k', _list(v)));
      live = _list(await _json('live.json', _ver['live'] ?? ''));
      rev.value++;
      // القوائم الكبيرة بعد ظهور الرئيسية
      movies = _list(await _json('movies.json', _ver['movies'] ?? ''));
      rev.value++;
      series = _list(await _json('series.json', _ver['series'] ?? ''));
      rev.value++;
    } catch (e) { debugPrint('[catalog] $e'); }
    loading = false;
  }

  static List<Map<String, dynamic>> homeMovies() => _list(home['movies']);
  static List<Map<String, dynamic>> homeSeries() => _list(home['series']);

  static String img(Map m) {
    final v = '${m['stream_icon'] ?? m['cover'] ?? ''}';
    if (v.startsWith('http')) return v;
    return v.isEmpty ? '' : '$kCdn/${v.replaceAll(RegExp(r'^/+'), '')}';
  }

  // حلقات المسلسل: catalog/eps/<id % n>.json
  static Map<String, dynamic>? _epsIdx;
  static final Map<String, Map> _shards = {};
  static Future<Map<String, dynamic>?> episodes(int sid) async {
    try {
      _epsIdx ??= Map<String, dynamic>.from(await _json('eps/index.json', '') as Map);
      final n = (_epsIdx!['n'] as num?)?.toInt() ?? 64;
      final k = '${sid % n}';
      final ver = '${(_epsIdx!['ver'] is Map ? (_epsIdx!['ver'] as Map)[k] : '') ?? ''}';
      final s = _shards[k] ??= Map.from(await _json('eps/$k.json', ver) as Map);
      final e = s['$sid'];
      return e is Map ? Map<String, dynamic>.from(e) : null;
    } catch (e) { debugPrint('[eps] $e'); return null; }
  }
}

// ── قناتنا TOTV Live ───────────────────────────────────────────────
class TotvLive {
  static Future<(List<String>, String)> urls() async {
    final r = await Api.call('live_play');
    if (r['ok'] != true) {
      throw ApiErr(r['reason'] == 'sub' ? 'القناة للمشتركين — جدّد اشتراكك' : 'القناة غير متاحة الآن — تابع مواعيد البث');
    }
    return ([for (final u in (r['urls'] as List? ?? const [])) '$u'], '${r['xt'] ?? ''}');
  }
}
