import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'core.dart';
import 'home.dart';
import 'ui.dart';

// ════════════════════════════════════════════════════════════════════
//  تفعيل الشاشة: باركود + رمز ⇐ الهاتف يمسحه (المزيد ← ربط شاشة بالباركود)
//  ⇐ الشاشة تدخل بنفس الحساب والاشتراك فوراً
// ════════════════════════════════════════════════════════════════════
class PairScreen extends StatefulWidget {
  const PairScreen({super.key});
  @override State<PairScreen> createState() => _PairScreenState();
}

class _PairScreenState extends State<PairScreen> {
  String _code = '', _secret = '', _link = '', _err = '';
  Timer? _poll, _renew;
  bool _busy = false;

  @override
  void initState() { super.initState(); _new(); }
  @override
  void dispose() { _poll?.cancel(); _renew?.cancel(); super.dispose(); }

  Future<void> _new() async {
    _poll?.cancel(); _renew?.cancel();
    try {
      final r = await Api.pub('tv_pair_new', {'name': 'TV'});
      if (!mounted) return;
      setState(() { _code = '${r['code']}'; _secret = '${r['secret']}'; _link = '${r['link']}'; _err = ''; });
      _poll = Timer.periodic(const Duration(seconds: 3), (_) => _check());
      _renew = Timer(Duration(seconds: ((r['ttl'] as num?)?.toInt() ?? 600) - 20), _new);
    } catch (e) {
      if (mounted) setState(() => _err = 'تعذّر الاتصال — تحقق من الإنترنت');
      _renew = Timer(const Duration(seconds: 8), _new);
    }
  }

  Future<void> _check() async {
    if (_busy || _code.isEmpty) return;
    try {
      final r = await Api.pub('tv_pair_poll', {'code': _code, 'secret': _secret});
      if (r['ok'] == true && '${r['token'] ?? ''}'.isNotEmpty) {
        _busy = true;
        _poll?.cancel(); _renew?.cancel();
        await Auth.withCustomToken('${r['token']}');
        await Sub.load();
        if (!mounted) return;
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeShell()));
      } else if (r['error'] == 'expired') {
        _new();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: K.bg,
    body: Directionality(textDirection: TextDirection.rtl, child: Center(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 32),
      child: Row(children: [
        Expanded(flex: 6, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('TOTV+', style: K.s(30, w: FontWeight.w900, c: K.gold)),
          const SizedBox(height: 6),
          Text('فعّل الشاشة من هاتفك', style: K.s(24, w: FontWeight.w900)),
          const SizedBox(height: 18),
          for (final (i, t) in const [
            (1, 'افتح تطبيق TOTV+ على هاتفك'),
            (2, 'المزيد ← ربط شاشة بالباركود'),
            (3, 'امسح الباركود — تفتح الشاشة باشتراكك فوراً'),
          ]) Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [
            Container(width: 26, height: 26, alignment: Alignment.center,
                decoration: const BoxDecoration(color: K.gold, shape: BoxShape.circle),
                child: Text('$i', style: K.s(13, w: FontWeight.w900, c: Colors.black))),
            const SizedBox(width: 12),
            Expanded(child: Text(t, style: K.s(15, c: K.t2))),
          ])),
          const SizedBox(height: 16),
          Text('أو اكتب الرمز في الهاتف', style: K.s(13, c: K.t3)),
          Text(_code.isEmpty ? '— — — — — —' : _code.split('').join(' '), textDirection: TextDirection.ltr,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 34, fontWeight: FontWeight.w900, color: K.t1, letterSpacing: 5)),
          if (_err.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_err, style: K.s(13, c: K.red))),
          const SizedBox(height: 18),
          TvFocus(autofocus: true, onTap: _new, radius: 8, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10), color: K.card,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.refresh_rounded, color: K.t1, size: 18), const SizedBox(width: 8),
              Text('رمز جديد', style: K.s(14, w: FontWeight.w700)),
            ]))),
          const SizedBox(height: 14),
          Text('الشاشة متاحة في باقات 3 أشهر فأكثر · اطلبها من وكيلك', style: K.s(12, c: K.t3)),
        ])),
        const SizedBox(width: 48),
        Expanded(flex: 4, child: AspectRatio(aspectRatio: 1, child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
          child: _link.isEmpty ? const Loading() : QrImageView(data: _link, backgroundColor: Colors.white),
        ))),
      ]),
    ))),
  );
}
