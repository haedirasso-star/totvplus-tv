import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core.dart';
import 'home.dart';
import 'pair.dart';
import 'ui.dart';

// ════════════════════════════════════════════════════════════════════
//  TOTV+ للشاشات (v2) — تطبيق مستقل خفيف لأجهزة التلفاز والصناديق
//  الدخول بالباركود من هاتف المشترك ⇐ نفس الحساب والاشتراك · الخط من العقل المدبر
// ════════════════════════════════════════════════════════════════════
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await Prefs.init();
  await Auth.restore();
  PaintingBinding.instance.imageCache.maximumSizeBytes = 80 << 20;   // ذاكرة صور معقولة للصناديق الضعيفة
  runApp(const TotvTv());
}

class TotvTv extends StatelessWidget {
  const TotvTv({super.key});
  @override
  Widget build(BuildContext context) => Shortcuts(
    // أزرار الريموت ⇐ تفعيل العنصر المركّز
    shortcuts: const <ShortcutActivator, Intent>{
      SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
    },
    child: MaterialApp(
      title: 'TOTV+',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: K.bg,
        colorScheme: const ColorScheme.dark(primary: K.gold, surface: K.panel),
        visualDensity: VisualDensity.compact,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
      ),
      // مقياس ثابت: شاشات 4K/1080 تعرض نفس الأحجام المضغوطة (لا تضخيم)
      builder: (c, child) {
        final mq = MediaQuery.of(c);
        final s = (mq.size.width / 960).clamp(0.85, 1.25);
        return MediaQuery(data: mq.copyWith(textScaler: TextScaler.linear(s)), child: child!);
      },
      home: Auth.signedIn ? const HomeShell() : const PairScreen(),
    ),
  );
}
