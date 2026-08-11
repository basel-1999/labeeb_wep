import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // 🔗 استيراد مكتبة الفيربيس الأساسية
import 'package:firebase_auth/firebase_auth.dart'; // ✨ تمت إضافة هذا الاستيراد لإلغاء حفظ الجلسة
import 'firebase_options.dart'; // 🔗 استيراد إعدادات الفيربيس الخاصة بمشروعك
import 'app_router.dart'; // 🔗 استيراد ملف المسارات الجديد
import 'package:flutter_web_plugins/url_strategy.dart';

void main() async {
  // 1️⃣ التأكد من تهيئة بيئة Flutter قبل استدعاء أي خدمات Asynchronous
  WidgetsFlutterBinding.ensureInitialized();

  // 2️⃣ تهيئة Firebase بالخيارات المولدة لمشروع labeeb-app-2026
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ✨ إجبار Firebase على عدم تذكر المستخدم (عدم حفظ الجلسة)
  await FirebaseAuth.instance.setPersistence(Persistence.NONE);

  usePathUrlStrategy();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 🚀 استخدام MaterialApp.router لتفعيل نظام go_router مع المتصفح
    return MaterialApp.router(
      title: 'منصة لبيب التعليمية',
      debugShowCheckedModeBanner: false,

      // بناء ThemeData يعتمد على الهوية اللونية المعتمدة للبيب
      theme: ThemeData(
        primaryColor: const Color(0xFFD97706), // البرتقالي الجذاب الرئيسي
        scaffoldBackgroundColor: const Color(0xFFFAF8F5), // البيج الدافئ للخلفية
        fontFamily: 'Cairo',
      ),

      // 🔗 ربط إعدادات التوجيه بدلاً من خاصية home القديمة
      routerConfig: appRouter,
    );
  }
}