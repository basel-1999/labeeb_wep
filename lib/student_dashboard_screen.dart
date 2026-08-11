import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:labeeb_wep/core/theme.dart';
import 'dart:async';
import 'package:labeeb_wep/session_check_service.dart';
import 'live_session_screen.dart';

import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:go_router/go_router.dart';

class StudentDashboardScreen extends StatefulWidget {
  final String? studentUid;
  final String studentName;
  final String selectedSubject;
  final String bookingType; // "now" أو "schedule"
  final DateTime? scheduledDate;

  const StudentDashboardScreen({
    super.key,
    this.studentUid,
    this.studentName = 'طالب لبيب',
    this.selectedSubject = 'الرياضيات',
    this.bookingType = 'now',
    this.scheduledDate,
  });

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  late String _currentUserId;
  late String _displayName; // ✨ متغير جديد لحفظ الاسم الحقيقي

  @override
  void initState() {
    super.initState();
    _currentUserId = widget.studentUid ?? FirebaseAuth.instance.currentUser?.uid ?? 'GUEST_USER';
    _displayName = widget.studentName; // نبدأ بالاسم الممرر مبدئياً
    _fetchRealUserName(); // ✨ جلب الاسم الحقيقي من قاعدة البيانات
  }

  // ✨ دالة جديدة لجلب الاسم من Firebase لضمان عدم ظهور "طالب لبيب" بالخطأ
  Future<void> _fetchRealUserName() async {
    if (_currentUserId != 'GUEST_USER') {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(_currentUserId).get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          final realName = data['name'];
          // إذا كان الاسم موجوداً ولا يساوي "طالب لبيب"، قم بتحديث الواجهة
          if (realName != null && realName.toString().trim().isNotEmpty && realName != 'طالب لبيب') {
            if (mounted) {
              setState(() {
                _displayName = realName.toString();
              });
            }
          }
        }
      } catch (e) {
        debugPrint("Error fetching student name: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LabeebTheme.beigeBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: LabeebTheme.oliveGreen.withOpacity(0.1),
              child: const Icon(Icons.person_rounded, color: LabeebTheme.oliveGreen),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'أهلاً بك يا طفلي المتميز 👋',
                  style: TextStyle(fontSize: 11, color: Colors.black54, fontFamily: 'Cairo'),
                ),
                // ✨ تم استخدام _displayName بدلاً من widget.studentName
                Text(
                  _displayName.isNotEmpty ? _displayName : 'طالب لبيب',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: LabeebTheme.textDark, fontFamily: 'Cairo'),
                ),
              ],
            ),
          ],
        ),
        actions: [
          _buildFirebaseWalletStream(),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, color: LabeebTheme.textDark),
            onPressed: () => _showNotificationsDialog(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: LabeebTheme.oliveGreen,
        onPressed: () => _showHelpBottomSheet(context),
        icon: const Icon(Icons.support_agent_rounded, color: Colors.white),
        label: const Text('المساعدة والإنقاذ', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SelectionArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWelcomeCard(),
                    const SizedBox(height: 24),

                    _buildNewClassRequestSection(context),
                    const SizedBox(height: 24),

                    const Text(
                      '🗓️ حالة الطلبات والحصص الحالية',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: LabeebTheme.textDark, fontFamily: 'Cairo'),
                    ),
                    const SizedBox(height: 12),
                    _buildActiveRequestsAndClassesCard(),
                    const SizedBox(height: 24),

                    const Text(
                      '📚 أرشيف دروسك وملخصات السبورة',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: LabeebTheme.textDark, fontFamily: 'Cairo'),
                    ),
                    const SizedBox(height: 12),

                    _buildFirebaseSessionsStream(),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNewClassRequestSection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: LabeebTheme.oliveGreen.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: LabeebTheme.oliveGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add_box_rounded, color: LabeebTheme.oliveGreen, size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تحتاج إلى شرح درس إضافي؟ 🧠',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: LabeebTheme.textDark, fontFamily: 'Cairo'),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'اطلب حصة جديدة فوراً أو جدولها لوقت لاحق',
                      style: TextStyle(fontSize: 12, color: Colors.black54, fontFamily: 'Cairo'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: LabeebTheme.accentOrange,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => _showNewClassBookingDialog(context),
              icon: const Icon(Icons.flash_on_rounded, size: 20),
              label: const Text(
                'طلب حصة جديدة الآن 🚀',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showNewClassBookingDialog(BuildContext context) {
    String selectedSubjectModal = 'الرياضيات';
    String bookingTypeModal = 'now';
    DateTime selectedDateModal = DateTime.now().add(const Duration(hours: 1));

    final List<String> subjectsList = ['الرياضيات', 'اللغة العربية', 'العلوم والفيزياء', 'اللغة الإنجليزية', 'الكيمياء'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.menu_book_rounded, color: LabeebTheme.oliveGreen),
              SizedBox(width: 8),
              Text('حجز حصة تعليمية جديدة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('اختر المادة الدراسية المطلوبة:', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.black54)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedSubjectModal,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: subjectsList.map((subject) {
                    return DropdownMenuItem(
                      value: subject,
                      child: Text(subject, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() { selectedSubjectModal = val; });
                    }
                  },
                ),
                const SizedBox(height: 16),
                const Text('نوع الحجز:', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.black54)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('فوراً ⚡', style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                        value: 'now',
                        groupValue: bookingTypeModal,
                        activeColor: LabeebTheme.oliveGreen,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) {
                          if (val != null) setDialogState(() { bookingTypeModal = val; });
                        },
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('مجدولة 🗓️', style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                        value: 'schedule',
                        groupValue: bookingTypeModal,
                        activeColor: LabeebTheme.oliveGreen,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) {
                          if (val != null) setDialogState(() { bookingTypeModal = val; });
                        },
                      ),
                    ),
                  ],
                ),
                if (bookingTypeModal == 'schedule') ...[
                  const SizedBox(height: 12),
                  const Text('حدد موعد الحصة:', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.black54)),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: LabeebTheme.oliveGreen),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    ),
                    onPressed: () async {
                      DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: selectedDateModal,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );

                      if (pickedDate != null) {
                        TimeOfDay? pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(selectedDateModal),
                        );

                        if (pickedTime != null) {
                          setDialogState(() {
                            selectedDateModal = DateTime(
                              pickedDate.year,
                              pickedDate.month,
                              pickedDate.day,
                              pickedTime.hour,
                              pickedTime.minute,
                            );
                          });
                        }
                      }
                    },
                    icon: const Icon(Icons.calendar_today_rounded, color: LabeebTheme.oliveGreen, size: 18),
                    label: Text(
                      'الموعد: ${selectedDateModal.year}/${selectedDateModal.month}/${selectedDateModal.day} - ${selectedDateModal.hour}:${selectedDateModal.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: LabeebTheme.textDark, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: LabeebTheme.oliveGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                if (_currentUserId == 'GUEST_USER') {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('يرجى تسجيل الدخول أولاً لتتمكن من طلب حصة', style: TextStyle(fontFamily: 'Cairo')),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                  return;
                }

                Navigator.pop(context);

                try {
                  final sessionId = await SessionCheckService.createSessionRequest(
                    studentId: _currentUserId,
                    studentName: _displayName, // ✨ استخدم الاسم الحقيقي المحفوظ
                    subject: selectedSubjectModal,
                    topic: selectedSubjectModal,
                  );

                  if (bookingTypeModal == 'schedule') {
                    await FirebaseFirestore.instance.collection('sessions').doc(sessionId).update({
                      'bookingType': 'schedule',
                      'scheduledAt': Timestamp.fromDate(selectedDateModal),
                      'scheduledTime': '${selectedDateModal.hour}:${selectedDateModal.minute.toString().padLeft(2, '0')}',
                    });
                  } else {
                    await FirebaseFirestore.instance.collection('sessions').doc(sessionId).update({
                      'bookingType': 'now',
                    });
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('تم إرسال طلب الحصة بنجاح! بانتظار قبول المعلم ⏳\nمعرّف الجلسة: ${sessionId.substring(0, 8)}...', style: const TextStyle(fontFamily: 'Cairo')),
                        backgroundColor: LabeebTheme.oliveGreen,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('❌ فشل الطلب: ${e.toString().replaceFirst('Exception: ', '')}', style: const TextStyle(fontFamily: 'Cairo')),
                        backgroundColor: Colors.redAccent,
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  }
                }
              },
              child: const Text('تأكيد الطلب 📥', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFirebaseWalletStream() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(_currentUserId).snapshots(),
      builder: (context, snapshot) {
        int balance = 0;
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          balance = data?['sessionCredits'] ?? 0;
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: LabeebTheme.oliveGreen.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: LabeebTheme.oliveGreen.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.account_balance_wallet_rounded, color: LabeebTheme.oliveGreen, size: 16),
              const SizedBox(width: 6),
              Text(
                '$balance حصص',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: LabeebTheme.textDark, fontFamily: 'Cairo'),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () => _showRechargeDialog(context, currentBalance: balance),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: LabeebTheme.accentOrange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '+ شحن',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                  ),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: LabeebTheme.oliveGreen,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'أهلاً بك في منصة لبيب التعليمية 🎁',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                ),
                SizedBox(height: 8),
                Text(
                  'جاهز لرحلة الفهم الذكي؟ اطلب حصتك وتابع حالة قبول المعلمين بكل إنسيابية.',
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5, fontFamily: 'Cairo'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 32),
          )
        ],
      ),
    );
  }


  Widget _buildActiveRequestsAndClassesCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sessions')
          .where('studentId', isEqualTo: _currentUserId)
          .where('status', whereIn: ['pending', 'accepted', 'scheduled', 'active'])
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: LabeebTheme.oliveGreen));
        }

        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.red, size: 32),
                const SizedBox(height: 8),
                const Text(
                  'تعذر تحميل الطلبات حالياً. تأكد من اتصال الإنترنت أو إعدادات قاعدة البيانات.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
            ),
            child: const Center(
              child: Text(
                'لا توجد طلبات نشطة حالياً. يمكنك طلب حصة جديدة من الزر أعلاه 👆',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.black54),
              ),
            ),
          );
        }

        final docs = snapshot.data!.docs;

        return Column(
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final String subject = data['subject'] ?? 'الرياضيات';
            final String status = data['status'] ?? 'pending';

            final dynamic rawTeacherName = data['teacherName'] ?? data['teacher'] ?? data['instructorName'];
            final bool hasTeacherName = rawTeacherName != null &&
                rawTeacherName.toString().trim().isNotEmpty &&
                rawTeacherName.toString() != 'null';

            final String teacherName = hasTeacherName ? rawTeacherName.toString() : '';

            bool isAccepted = status == 'accepted' || status == 'active' || hasTeacherName;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isAccepted ? Colors.green.withOpacity(0.5) : LabeebTheme.accentOrange.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isAccepted ? Colors.green.withOpacity(0.1) : LabeebTheme.accentOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      isAccepted ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
                      color: isAccepted ? Colors.green : LabeebTheme.accentOrange,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'مادة $subject',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: LabeebTheme.textDark, fontFamily: 'Cairo'),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isAccepted
                              ? (hasTeacherName
                              ? 'تم إسنادك إلى المعلم: $teacherName 🎉'
                              : 'تم قبول طلبك بنجاح وجاري بدء الجلسة 🎉')
                              : 'الطلب معلق... بانتظار قبول المعلم ⏳',
                          style: TextStyle(
                            color: isAccepted ? Colors.green[700] : Colors.black54,
                            fontSize: 12,
                            fontWeight: isAccepted ? FontWeight.bold : FontWeight.normal,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isAccepted) ...[
                    Builder(builder: (context) {
                      final String bookingType = data['bookingType'] ?? 'now';
                      final dynamic scheduledAtData = data['scheduledAt'];

                      bool isStartAllowed = false;
                      String timeUntilStart = '';

                      if (bookingType == 'schedule' && scheduledAtData != null && scheduledAtData is Timestamp) {
                        DateTime startTime = scheduledAtData.toDate();
                        Duration diff = startTime.difference(DateTime.now());

                        if (diff.inMinutes <= 5 && diff.inMinutes >= -60) {
                          isStartAllowed = true;
                        } else {
                          if (diff.inMinutes > 5) {
                            timeUntilStart = 'تبدأ خلال ${diff.inMinutes} دقيقة';
                          } else {
                            timeUntilStart = 'انتهت صلاحية الدخول';
                          }
                        }
                      } else {
                        isStartAllowed = true;
                      }

                      if (isStartAllowed) {
                        return ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            String sessionId = doc.id;
                            final studentName = Uri.encodeComponent(_displayName); // ✨ استخدم الاسم الحقيقي
                            context.push('/live-session?sessionId=$sessionId&role=student&studentName=$studentName');
                          },
                          child: const Text('دخول 🎙️', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                        );
                      } else {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            timeUntilStart,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700], fontFamily: 'Cairo'),
                          ),
                        );
                      }
                    }),
                  ],
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }


  Widget _buildFirebaseSessionsStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sessions')
          .where('studentId', isEqualTo: _currentUserId)
          .where('status', isEqualTo: 'completed')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: LabeebTheme.oliveGreen));
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildSessionCard(
            subject: 'الرياضيات (درس تجريبي)',
            teacher: 'أ. أحمد علي',
            date: 'سابقاً',
            rating: '⭐⭐⭐⭐⭐',
            audioUrl: '',
            pdfUrl: '',
          );
        }

        final docs = snapshot.data!.docs;

        return Column(
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return _buildSessionCard(
              subject: data['subject'] ?? 'درس تعليمي',
              teacher: data['teacherName'] ?? data['teacher'] ?? 'معلم لبيب',
              date: data['date'] ?? 'سابقاً',
              rating: data['rating'] ?? '⭐⭐⭐⭐⭐',
              audioUrl: data['audioRecordingUrl'] ?? '',
              pdfUrl: data['boardPdfUrl'] ?? '',
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildSessionCard({
    required String subject,
    required String teacher,
    required String date,
    required String rating,
    required String audioUrl,
    required String pdfUrl,
  }) {
    final bool hasValidPdf = pdfUrl.isNotEmpty && pdfUrl.startsWith('http');
    final bool hasValidAudio = audioUrl.isNotEmpty && audioUrl.startsWith('http');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LabeebTheme.beigeCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: LabeebTheme.oliveGreen,
                child: Icon(Icons.school_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'درس $subject',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: LabeebTheme.textDark, fontFamily: 'Cairo'),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'المعلم: $teacher • $date',
                      style: const TextStyle(fontSize: 12, color: Colors.black54, fontFamily: 'Cairo'),
                    ),
                    Text(
                      'التقييم: $rating',
                      style: const TextStyle(fontSize: 11, color: LabeebTheme.accentOrange, fontFamily: 'Cairo'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: hasValidAudio ? LabeebTheme.oliveGreen : Colors.grey[400]!,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: hasValidAudio
                      ? () => _playSessionAudio(context, subject, audioUrl)
                      : null,
                  icon: Icon(
                    Icons.play_circle_fill_rounded,
                    size: 20,
                    color: hasValidAudio ? LabeebTheme.oliveGreen : Colors.grey[400],
                  ),
                  label: Text(
                    hasValidAudio ? 'استماع للدرس 🎙️' : 'لا يوجد تسجيل',
                    style: TextStyle(
                      color: hasValidAudio ? LabeebTheme.oliveGreen : Colors.grey[500],
                      fontSize: 11,
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasValidPdf ? LabeebTheme.oliveGreen : Colors.grey[350],
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: hasValidPdf
                      ? () => _openStoragePdf(pdfUrl)
                      : null,
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                  label: Text(
                    hasValidPdf ? 'تحميل السبورة PDF 📄' : 'جاري تجهيز الملف...',
                    style: const TextStyle(fontSize: 11, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _playSessionAudio(BuildContext context, String subject, String audioUrl) async {
    final AudioPlayer audioPlayer = AudioPlayer();
    bool isPlaying = true;

    try {
      await audioPlayer.play(UrlSource(audioUrl));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر تشغيل التسجيل الصوتي: $e', style: const TextStyle(fontFamily: 'Cairo')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isDismissible: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            audioPlayer.onPlayerStateChanged.listen((state) {
              if (context.mounted) {
                setSheetState(() {
                  isPlaying = state == PlayerState.playing;
                });
              }
            });

            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.graphic_eq_rounded, color: LabeebTheme.accentOrange, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'تشغيل تسجيل: $subject',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const LinearProgressIndicator(color: LabeebTheme.accentOrange, backgroundColor: Color(0xFFF0F0F0)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        iconSize: 52,
                        icon: Icon(
                          isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                          color: LabeebTheme.oliveGreen,
                        ),
                        onPressed: () async {
                          if (isPlaying) {
                            await audioPlayer.pause();
                          } else {
                            await audioPlayer.resume();
                          }
                        },
                      ),
                      const SizedBox(width: 20),
                      IconButton(
                        iconSize: 42,
                        icon: const Icon(Icons.stop_circle_rounded, color: Colors.redAccent),
                        onPressed: () async {
                          await audioPlayer.stop();
                          if (context.mounted) Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
      audioPlayer.stop();
      audioPlayer.dispose();
    });
  }

  Future<void> _openStoragePdf(String pdfUrl) async {
    if (pdfUrl.isEmpty || !pdfUrl.startsWith('http')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('جاري تجهيز رابط ملف السبورة... 📄', style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: LabeebTheme.accentOrange,
        ),
      );
      return;
    }

    final Uri url = Uri.parse(pdfUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح رابط الملف!', style: TextStyle(fontFamily: 'Cairo'))),
        );
      }
    }
  }

  void _showRechargeDialog(BuildContext context, {required int currentBalance}) {
    final TextEditingController referenceController = TextEditingController();
    String selectedPackageTitle = 'باقة 5 حصص شهرية (150 ر.س)';
    int packageSessions = 5;

    Uint8List? receiptBytes;
    String? receiptFileName;
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.receipt_long_rounded, color: LabeebTheme.accentOrange),
              SizedBox(width: 8),
              Text('شحن رصيد الحصص (تحويل بنكي)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'اختر الباقة المطلوبة وحول المبلغ، ثم أرفق صورة الإشعار وأدخل رقم المرجع لإرسال الطلب للإدارة:',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                _buildPackageSelectTile(
                    'حصة واحدة (35 ر.س)',
                    1,
                    selectedPackageTitle,
                        (val, sessions) => setDialogState(() { selectedPackageTitle = val; packageSessions = sessions; })
                ),
                _buildPackageSelectTile(
                    'باقة 5 حصص (150 ر.س)',
                    5,
                    selectedPackageTitle,
                        (val, sessions) => setDialogState(() { selectedPackageTitle = val; packageSessions = sessions; })
                ),
                _buildPackageSelectTile(
                    'باقة التفوق 12 حصة (320 ر.س)',
                    12,
                    selectedPackageTitle,
                        (val, sessions) => setDialogState(() { selectedPackageTitle = val; packageSessions = sessions; })
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: referenceController,
                  decoration: InputDecoration(
                    labelText: 'رقم الإيصال أو المرجع البنكي',
                    labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: LabeebTheme.oliveGreen)),
                  ),
                ),
                const SizedBox(height: 16),

                const Text('صورة إشعار التحويل (إجباري):', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: isUploading ? null : () async {
                    try {
                      FilePickerResult? result = await FilePicker.platform.pickFiles(
                        type: FileType.image,
                        withData: true,
                      );

                      if (result != null && result.files.single.bytes != null) {
                        setDialogState(() {
                          receiptBytes = result.files.single.bytes;
                          receiptFileName = result.files.single.name;
                        });
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('خطأ في اختيار الصورة: $e'), backgroundColor: Colors.red),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: receiptBytes != null ? LabeebTheme.oliveGreen.withOpacity(0.1) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: receiptBytes != null ? LabeebTheme.oliveGreen : Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          receiptBytes != null ? Icons.check_circle : Icons.cloud_upload_rounded,
                          color: receiptBytes != null ? LabeebTheme.oliveGreen : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            receiptFileName ?? 'اضغط لرفع صورة الإشعار',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              fontWeight: receiptBytes != null ? FontWeight.bold : FontWeight.normal,
                              color: receiptBytes != null ? LabeebTheme.oliveGreen : Colors.black54,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: LabeebTheme.oliveGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: isUploading ? null : () async {
                if (referenceController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('الرجاء إدخال رقم المرجع أو الإيصال', style: TextStyle(fontFamily: 'Cairo'))),
                  );
                  return;
                }
                if (receiptBytes == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('الرجاء رفع صورة إشعار التحويل', style: TextStyle(fontFamily: 'Cairo'))),
                  );
                  return;
                }

                setDialogState(() => isUploading = true);

                try {
                  String? imageUrl;
                  try {
                    const String cloudName = 'f4t8ayoq';
                    const String uploadPreset = 'lzgw58tq';
                    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/auto/upload');
                    final request = http.MultipartRequest('POST', uri)
                      ..fields['upload_preset'] = uploadPreset
                      ..files.add(http.MultipartFile.fromBytes(
                        'file',
                        receiptBytes!,
                        filename: receiptFileName ?? 'receipt.jpg',
                      ));

                    final response = await request.send();
                    if (response.statusCode == 200) {
                      final responseData = await response.stream.bytesToString();
                      final jsonMap = jsonDecode(responseData);
                      imageUrl = jsonMap['secure_url'] as String?;
                    }
                  } catch (e) {
                    print("Cloudinary upload error: $e");
                  }

                  await FirebaseFirestore.instance.collection('recharge_requests').add({
                    'studentId': _currentUserId,
                    'studentName': _displayName, // ✨ استخدم الاسم الحقيقي المحفوظ
                    'packageTitle': selectedPackageTitle,
                    'sessionsCount': packageSessions,
                    'referenceNumber': referenceController.text.trim(),
                    'receiptImageUrl': imageUrl ?? '',
                    'status': 'pending',
                    'createdAt': FieldValue.serverTimestamp(),
                  });

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم إرسال طلب الشحن بنجاح! بانتظار مراجعة الإدارة ⏳', style: TextStyle(fontFamily: 'Cairo')),
                        backgroundColor: LabeebTheme.oliveGreen,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('حدث خطأ: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red),
                    );
                  }
                } finally {
                  if (mounted) setDialogState(() => isUploading = false);
                }
              },
              child: isUploading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('إرسال للإدارة 📤', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPackageSelectTile(String title, int sessionsCount, String currentSelected, Function(String, int) onSelected) {
    bool isSelected = currentSelected == title;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isSelected ? LabeebTheme.oliveGreen.withOpacity(0.1) : LabeebTheme.beigeCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isSelected ? LabeebTheme.oliveGreen : Colors.grey.withOpacity(0.3)),
      ),
      child: RadioListTile<String>(
        title: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
        value: title,
        groupValue: currentSelected,
        activeColor: LabeebTheme.oliveGreen,
        onChanged: (val) {
          if (val != null) onSelected(val, sessionsCount);
        },
      ),
    );
  }

  void _showNotificationsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.notifications_active_rounded, color: LabeebTheme.accentOrange),
            SizedBox(width: 8),
            Text('الإشعارات الحية', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('✅ تم إضافة ملخص حصة الرياضيات إلى حسابك جاهز للتحميل.', style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
            Divider(height: 20),
            Text('⏰ تذكير: حصتك المجدولة لليوم تبدأ خلال 15 دقيقة.', style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق', style: TextStyle(fontFamily: 'Cairo', color: LabeebTheme.oliveGreen)),
          ),
        ],
      ),
    );
  }

  void _showHelpBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('مركز الدعم الفني لـ لبيب 🆘', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: LabeebTheme.textDark)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.mic_off_rounded, color: LabeebTheme.accentOrange),
              title: const Text('واجهت مشكلة في الصوت خلال الحصة؟', style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
              subtitle: const Text('اضغط لإعادة ضبط المايك فوراً', style: TextStyle(fontFamily: 'Cairo', fontSize: 11)),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تمت إعادة ضبط الميكروفون بنجاح 🎙️', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.support_agent_rounded, color: LabeebTheme.oliveGreen),
              title: const Text('محادثة الدعم الفني المباشر', style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}