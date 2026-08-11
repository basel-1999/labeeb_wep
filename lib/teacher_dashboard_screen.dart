import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart'; // ✨ تم إضافة استيراد go_router

// 🔴 استدعاء الملفات المعتمدة لديك
import 'session_check_service.dart';
import 'live_session_screen.dart';
import 'package:labeeb_wep/core/theme.dart';

class TeacherDashboardScreen extends StatefulWidget {
  final String teacherName;

  const TeacherDashboardScreen({
    super.key,
    this.teacherName = 'أ. باسل أبو هدة',
  });

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  Timer? _refreshTimer;
  StreamSubscription<QuerySnapshot>? _sessionsSubscription;

  // 📚 حالة المعلم وتسجيل البيانات
  bool _isLoadingProfile = true;
  String? _teacherStatus; // null (غير مسجل), 'pending_approval', 'approved'

  // نموذج التسجيل ورفع الشهادة
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  Uint8List? _certificateBytes;
  String? _certificateFileName;
  bool _isUploading = false;

  // 📚 قائمة الطلبات الحقيقية المسندة للمعلم
  List<Map<String, dynamic>> acceptedRequests = [];

  @override
  void initState() {
    super.initState();
    _checkTeacherAccount();

    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  // 🔍 فحص هل للمعلم حساب في Firestore وإذا كان معتمداً يتم تفعيل الاستماع الحي للطلبات
  Future<void> _checkTeacherAccount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots()
            .listen((doc) {
          if (doc.exists && mounted) {
            final status = doc.data()?['status'] ?? 'pending_approval';

            setState(() {
              _teacherStatus = status;
              _isLoadingProfile = false;
            });

            if (status == 'approved') {
              _startListeningToPendingSessions();
            }
          }
        });
      } else {
        if (mounted) setState(() => _isLoadingProfile = false);
      }
    } catch (e) {
      debugPrint('Error checking teacher profile: $e');
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  // 🔔 الاستماع للجلسات (المعلقة للمزاحمة + المقبولة الخاصة بالمعلم)
  void _startListeningToPendingSessions() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _sessionsSubscription?.cancel();

    _sessionsSubscription = FirebaseFirestore.instance
        .collection('sessions')
        .snapshots()
        .listen((snapshot) {
      final List<Map<String, dynamic>> loadedSessions = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final status = data['status'] ?? 'pending';
        final teacherId = data['teacherId'];

        if (status == 'pending' || teacherId == user.uid) {
          DateTime startTime;
          final String bookingType = data['bookingType'] ?? 'now';
          final dynamic scheduledAt = data['scheduledAt'];

          if (bookingType == 'schedule' && scheduledAt != null && scheduledAt is Timestamp) {
            startTime = scheduledAt.toDate();
          } else if (data['createdAt'] != null) {
            startTime = (data['createdAt'] as Timestamp).toDate().add(const Duration(minutes: 5));
          } else {
            startTime = DateTime.now().add(const Duration(minutes: 10));
          }

          loadedSessions.add({
            'id': doc.id,
            'student': data['studentName'] ?? 'طالب لبيب',
            'grade': data['grade'] ?? 'المرحلة الدراسية',
            'subject': data['subject'] ?? 'عام',
            'topic': data['topic'] ?? data['subject'] ?? 'درس مباشر',
            'timeText': data['scheduledTime'] ?? 'الموعد المحدد',
            'startTime': startTime,
            'rawStatus': status,
            'status': status == 'completed' ? 'مكتملة' : (status == 'pending' ? 'طلب جديد بانتظار القبول' : 'جاهزة للبدء'),
          });
        }
      }

      if (mounted) {
        setState(() {
          acceptedRequests = loadedSessions;
        });
      }
    }, onError: (error) {
      debugPrint("Stream Error: $error");
    });
  }

  // 📎 اختيار ملف الشهادة من متصفح الويب
  void _pickCertificate() {
    final html.FileUploadInputElement input = html.FileUploadInputElement()
      ..accept = 'image/*,.pdf';
    input.click();

    input.onChange.listen((event) {
      final file = input.files?.first;
      if (file != null) {
        final reader = html.FileReader();
        reader.readAsArrayBuffer(file);
        reader.onLoadEnd.listen((_) {
          setState(() {
            _certificateBytes = reader.result as Uint8List?;
            _certificateFileName = file.name;
          });
        });
      }
    });
  }

  // ☁️ دالة رفع الشهادة مباشرة إلى Cloudinary
  Future<String?> _uploadCertificateToCloudinary(Uint8List bytes, String fileName) async {
    try {
      const String cloudName = 'f4t8ayoq';
      const String uploadPreset = 'lzgw58tq';

      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/auto/upload');
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
        ));

      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final jsonMap = jsonDecode(responseData);
        return jsonMap['secure_url'] as String?;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  // 📤 رفع الشهادة وحفظ بيانات المعلم
  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;
    if (_certificateBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار ملف الشهادة أولاً'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid ?? DateTime.now().millisecondsSinceEpoch.toString();

      final String? certificateUrl = await _uploadCertificateToCloudinary(
        _certificateBytes!,
        _certificateFileName ?? 'certificate.pdf',
      );

      if (certificateUrl == null) {
        throw Exception('فشل رفع الملف إلى Cloudinary.');
      }

      final teacherData = {
        'uid': uid,
        'name': widget.teacherName,
        'fullName': widget.teacherName,
        'subject': _subjectController.text.trim(),
        'subjects': [_subjectController.text.trim()],
        'role': 'teacher',
        'experienceYears': int.tryParse(_experienceController.text.trim()) ?? 0,
        'certificates': [certificateUrl],
        'certificateUrl': certificateUrl,
        'certificateName': _certificateFileName,
        'status': 'pending_approval',
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('users').doc(uid).set(teacherData, SetOptions(merge: true));

      setState(() {
        _teacherStatus = 'pending_approval';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال بياناتك وشهادتك للإدارة بنجاح!'), backgroundColor: LabeebTheme.oliveGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء الرفع: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _sessionsSubscription?.cancel();
    _subjectController.dispose();
    _experienceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LabeebTheme.beigeBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        automaticallyImplyLeading: false,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              const Text(
                'لبيب | بوابة المعلم',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: LabeebTheme.oliveGreen,
                  fontFamily: 'Cairo',
                ),
              ),
              const Spacer(),
              CircleAvatar(
                backgroundColor: LabeebTheme.oliveGreen.withOpacity(0.15),
                child: const Icon(Icons.person, color: LabeebTheme.oliveGreen),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.teacherName,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: LabeebTheme.textDark, fontFamily: 'Cairo'),
                  ),
                  Text(
                    _teacherStatus == 'approved'
                        ? 'معلم معتمد'
                        : (_teacherStatus == 'pending_approval' ? 'قيد المراجعة' : 'حساب جديد'),
                    style: const TextStyle(fontSize: 11, color: Colors.black45, fontFamily: 'Cairo'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SelectionArea( // ✨ تمت إضافة SelectionArea لتمكين نسخ النصوص
          child: _isLoadingProfile
              ? const Center(child: CircularProgressIndicator(color: LabeebTheme.oliveGreen))
              : _buildBodyContent(),
        ),
      ),
    );
  }

  Widget _buildBodyContent() {
    if (_teacherStatus == null) {
      return _buildRegistrationForm();
    }

    if (_teacherStatus == 'pending_approval') {
      return _buildPendingApprovalWidget();
    }

    return _buildDashboardView();
  }

  Widget _buildRegistrationForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 30.0),
      child: Center(
        child: Container(
          width: 600,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🎓 إكمال ملف المعلم ورفع الشهادات',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: LabeebTheme.oliveGreen, fontFamily: 'Cairo'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'يرجى تعبئة بيانات التخصص وإرفاق الشهادة الجامعية للاعتماد من قبل إدارة المنصة.',
                  style: TextStyle(fontSize: 13, color: Colors.black54, fontFamily: 'Cairo'),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _subjectController,
                  decoration: const InputDecoration(
                    labelText: 'التخصص / المادة التعليمية',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'يرجى إدخال التخصص' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _experienceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'سنوات الخبرة',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'يرجى إدخال عدد السنوات' : null,
                ),
                const SizedBox(height: 20),
                const Text('الشهادة الجامعية أو المؤهل:', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _pickCertificate,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: LabeebTheme.oliveGreen.withOpacity(0.5)),
                      borderRadius: BorderRadius.circular(8),
                      color: LabeebTheme.beigeCard,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_upload_outlined, color: LabeebTheme.oliveGreen),
                        const SizedBox(width: 8),
                        Text(
                          _certificateFileName ?? 'اضغط لاختيار ملف الشهادة (PDF / الصورة)',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: _certificateFileName != null ? FontWeight.bold : FontWeight.normal,
                            color: LabeebTheme.oliveGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: LabeebTheme.oliveGreen, foregroundColor: Colors.white),
                    onPressed: _isUploading ? null : _submitRegistration,
                    child: _isUploading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('إرسال الطلب للاعتماد', style: TextStyle(fontSize: 15, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPendingApprovalWidget() {
    return Center(
      child: Container(
        width: 500,
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hourglass_top_rounded, size: 64, color: LabeebTheme.accentOrange),
            const SizedBox(height: 16),
            const Text(
              'طلبك قيد المراجعة',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: LabeebTheme.textDark),
            ),
            const SizedBox(height: 8),
            const Text(
              'شكراً لتقديمك! يتم حالياً تدقيق شهاداتك وبياناتك من قبل فريق منصة "لبيب". سنقوم بتفعيل لوحة تحكمك فور الاعتماد.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.black54, fontFamily: 'Cairo', height: 1.6),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _checkTeacherAccount,
              icon: const Icon(Icons.refresh, color: LabeebTheme.oliveGreen),
              label: const Text('تحديث حالة الطلب', style: TextStyle(fontFamily: 'Cairo', color: LabeebTheme.oliveGreen)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 30.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: LabeebTheme.oliveGreen.withOpacity(0.3)),
            ),
            child: Row(
              children: const [
                Icon(Icons.phone_android_rounded, color: LabeebTheme.oliveGreen, size: 28),
                SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'ملاحظة: لوحة التحكم خالية من النوافذ التلقائية. يمكنك بدء الجلسات المقبولة مباشرة في مواعيدها.',
                    style: TextStyle(fontSize: 13, color: LabeebTheme.textDark, fontFamily: 'Cairo', height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          const Text(
            '📋 جدول الجلسات المقبولة والقادمة',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: LabeebTheme.textDark, fontFamily: 'Cairo'),
          ),
          const SizedBox(height: 16),
          acceptedRequests.isEmpty
              ? Container(
            width: double.infinity,
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: const Text('لا توجد جلسات مسندة إليك حالياً.', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Cairo', color: Colors.black54)),
          )
              : ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: acceptedRequests.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final req = acceptedRequests[index];

              final DateTime startTime = req['startTime'] as DateTime;
              final DateTime now = DateTime.now();
              final Duration diff = startTime.difference(now);
              final int secondsRemaining = diff.inSeconds;

              final bool isStartAllowed = secondsRemaining <= (15 * 60) && secondsRemaining >= -(60 * 60);
              final bool isPending = req['rawStatus'] == 'pending';

              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: LabeebTheme.oliveGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                child: Text('طلب #${req['id']}', style: const TextStyle(color: LabeebTheme.oliveGreen, fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Cairo')),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                isPending
                                    ? '🟡 طلب جديد بانتظار القبول'
                                    : (isStartAllowed ? '🔴 القاعة جاهزة للبدء الآن' : '${req['timeText']} (تبدأ خلال ${diff.inMinutes} دقيقة)'),
                                style: TextStyle(
                                  color: isPending ? Colors.grey : (isStartAllowed ? Colors.green : LabeebTheme.accentOrange),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text('الطالب: ${req['student']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, fontFamily: 'Cairo')),
                          const SizedBox(height: 4),
                          Text('${req['subject']} • ${req['grade']} (موضوع الدرس: ${req['topic']})', style: const TextStyle(color: Colors.black54, fontSize: 13, fontFamily: 'Cairo')),
                        ],
                      ),
                    ),

                    if (isPending) ...[
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                          backgroundColor: LabeebTheme.oliveGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          try {
                            final user = FirebaseAuth.instance.currentUser;
                            if (user != null) {
                              bool success = await SessionCheckService.acceptSession(
                                sessionId: req['id'],
                                teacherId: user.uid,
                                teacherName: widget.teacherName,
                              );
                              if (success && mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('تم قبول الطلب بنجاح! 🎯'), backgroundColor: Colors.green),
                                );
                              }
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('فشل القبول: $e'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.bolt_rounded, size: 20),
                        label: const Text('قبول الطلب الآن', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                      ),
                    ] else ...[
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                          side: const BorderSide(color: LabeebTheme.oliveGreen),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم فتح نافذة رفع المواد والملخصات.'), backgroundColor: LabeebTheme.oliveGreen),
                          );
                        },
                        icon: const Icon(Icons.attach_file_rounded, color: LabeebTheme.oliveGreen, size: 20),
                        label: const Text('إرفاق ملفات', style: TextStyle(color: LabeebTheme.oliveGreen, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                          backgroundColor: isStartAllowed ? LabeebTheme.accentOrange : Colors.grey[300],
                          foregroundColor: isStartAllowed ? Colors.white : Colors.black45,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: isStartAllowed
                            ? () => _showPreFlightChecklistModal(context, req)
                            : null,
                        icon: Icon(isStartAllowed ? Icons.play_arrow_rounded : Icons.lock_clock_rounded, size: 22),
                        label: Text(
                          isStartAllowed ? 'بدء الجلسة / الفحص 🎙️' : 'في انتظار الموعد',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                        ),
                      ),
                    ]
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // 🩺 نافذة الفحص المسبق
  void _showPreFlightChecklistModal(BuildContext context, Map<String, dynamic> sessionData) {
    bool isChecking = false;
    bool micReady = false;
    bool networkReady = false;
    int latency = 0;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            void runChecks() async {
              setState(() => isChecking = true);

              bool micStatus = await SessionCheckService.checkMicrophone();
              int ping = await SessionCheckService.checkNetworkLatency();
              bool netStatus = ping > 0 && ping < 1000;

              setState(() {
                micReady = micStatus;
                networkReady = netStatus;
                latency = ping;
                isChecking = false;
              });
            }

            return AlertDialog(
              title: const Text('الفحص المسبق للجلسة', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Cairo')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Icon(
                      micReady ? Icons.check_circle : Icons.mic_off,
                      color: micReady ? Colors.green : Colors.red,
                    ),
                    title: const Text('فحص الميكروفون', style: TextStyle(fontFamily: 'Cairo')),
                    subtitle: Text(micReady ? 'الميكروفون يعمل بنجاح' : 'لم يتم اكتشاف ميكروفون', style: const TextStyle(fontFamily: 'Cairo')),
                  ),
                  ListTile(
                    leading: Icon(
                      networkReady ? Icons.wifi : Icons.wifi_off,
                      color: networkReady ? Colors.green : Colors.red,
                    ),
                    title: const Text('اتصال الإنترنت', style: TextStyle(fontFamily: 'Cairo')),
                    subtitle: Text(networkReady ? 'الاتصال ممتاز ($latency ms)' : 'الشبكة غير متصلة أو ضعيفة', style: const TextStyle(fontFamily: 'Cairo')),
                  ),
                  const SizedBox(height: 15),
                  if (isChecking)
                    const CircularProgressIndicator()
                  else
                    ElevatedButton.icon(
                      onPressed: runChecks,
                      icon: const Icon(Icons.refresh),
                      label: const Text('إجراء الفحص الآن', style: TextStyle(fontFamily: 'Cairo')),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    if (!micReady) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('⚠️ تنبيه: لم يتم اكتشاف ميكروفون. يتم الدخول للجلسة والمحاولة بالخلفية...'),
                          backgroundColor: Colors.orange,
                          duration: Duration(seconds: 4),
                        ),
                      );
                    }

                    // ✨ تم التعديل لاستخدام go_router لدعم أزرار الرجوع والتحديث
                    final sessionId = Uri.encodeComponent(sessionData['id'] ?? 'unknown_session');
                    final studentName = Uri.encodeComponent(sessionData['student'] ?? 'طالب');
                    context.push('/live-session?sessionId=$sessionId&role=teacher&studentName=$studentName');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: const Text('بدء الجلسة الآن 🎓', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}