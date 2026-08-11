import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 🔗 استيراد الشاشات
import 'features/auth/presentation/main_gate_screen.dart';
import 'auth_flow_screen.dart';
import 'teacher_dashboard_screen.dart';
import 'student_dashboard_screen.dart';
import 'live_session_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  redirect: (BuildContext context, GoRouterState state) {
    final bool isLoggedIn = FirebaseAuth.instance.currentUser != null;
    final bool isAuthRoute = state.matchedLocation == '/' || state.matchedLocation == '/auth';

    // إذا لم يكن مسجلاً ويحاول الدخول لصفحة محمية، أرجعه للرئيسية
    if (!isLoggedIn && !isAuthRoute) {
      return '/';
    }

    // ✨ تم إزالة كود النقل التلقائي للوحة التحكم
    // الآن حتى لو كان مسجلاً للدخول، سيفتح الموقع على الصفحة الرئيسية ليختار بنفسه
    return null; // دعه يكمل مساره
  },
  routes: [
    // 1️⃣ البوابة الرئيسية
    GoRoute(
      path: '/',
      builder: (context, state) => const MainGateScreen(),
    ),

    // 2️⃣ تدفق التسجيل والتحقق
    GoRoute(
      path: '/auth',
      builder: (context, state) {
        final role = state.uri.queryParameters['role'] ?? 'student';
        return AuthFlowScreen(role: role);
      },
    ),

    // 3️⃣ لوحة تحكم المعلم
    GoRoute(
      path: '/teacher-dashboard',
      builder: (context, state) {
        final teacherName = state.uri.queryParameters['name'] ?? 'أ. باسل أبو هدة';
        return TeacherDashboardScreen(teacherName: teacherName);
      },
    ),

    // 4️⃣ لوحة تحكم الطالب
    GoRoute(
      path: '/student-dashboard',
      builder: (context, state) {
        final studentUid = state.uri.queryParameters['uid'] ?? FirebaseAuth.instance.currentUser!.uid;
        final studentName = state.uri.queryParameters['name'] ?? 'طالب لبيب';
        final subject = state.uri.queryParameters['subject'] ?? 'الرياضيات';
        final bookingType = state.uri.queryParameters['type'] ?? 'مباشر';

        return StudentDashboardScreen(
          studentUid: studentUid,
          studentName: studentName,
          selectedSubject: subject,
          bookingType: bookingType,
        );
      },
    ),

    // 5️⃣ مسار غرفة البث الحية
    GoRoute(
      path: '/live-session',
      builder: (context, state) {
        final sessionId = state.uri.queryParameters['sessionId'] ?? 'unknown_session';
        final role = state.uri.queryParameters['role'] ?? 'student';
        final studentName = state.uri.queryParameters['studentName'] ?? 'طالب';

        if (role == 'admin') {
          return LiveSessionScreen(
            sessionId: sessionId,
            studentName: 'مراقبة الأدمن',
            isTeacher: false,
          );
        } else if (role == 'teacher') {
          return LiveSessionScreen(
            sessionId: sessionId,
            studentName: studentName,
            isTeacher: true,
          );
        }

        return LiveSessionScreen(
          sessionId: sessionId,
          studentName: studentName,
          isTeacher: false,
        );
      },
    ),
  ],
);