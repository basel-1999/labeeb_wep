import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'package:labeeb_wep/core/theme.dart';
import 'session_check_service.dart';

// ==========================================
// 1. شاشة AuthFlowScreen
// ==========================================
class AuthFlowScreen extends StatefulWidget {
  final String role; // "student" أو "teacher"
  const AuthFlowScreen({super.key, required this.role});

  @override
  State<AuthFlowScreen> createState() => _AuthFlowScreenState();
}

class _AuthFlowScreenState extends State<AuthFlowScreen> {
  final AuthService _authService = AuthService();
  final CloudinaryService _cloudinaryService = CloudinaryService();

  int _currentStep = 0;
  bool _isSignUpMode = false;
  bool _isLoading = false;
  String? _verificationId;

  final TextEditingController _phoneController = TextEditingController();
  final List<TextEditingController> _otpControllers =
  List.generate(6, (i) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (i) => FocusNode());

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _specialtyController = TextEditingController();
  final TextEditingController _signUpPhoneController = TextEditingController();

  String? _selectedCountry;
  String? _selectedCity;
  String? _selectedTargetAge;
  String? _selectedSubject;

  // متغيرات الشهادة
  bool _isFileUploaded = false;
  String? _certificateFileName;
  String? _certificateUrl;
  bool _isProcessingFile = false;

  // 🆔 متغيرات الهوية الشخصية أو جواز السفر الجديدة
  bool _isIdFileUploaded = false;
  String? _idFileName;
  String? _idUrl;
  bool _isProcessingIdFile = false;

  String _bookingType = 'now';
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  final List<String> _countries = [
    'المملكة العربية السعودية',
    'فلسطين',
    'جمهورية مصر العربية',
    'الإمارات العربية المتحدة',
    'الأردن'
  ];
  final Map<String, List<String>> _cities = {
    'المملكة العربية السعودية': ['الرياض', 'جدة', 'مكة المكرمة', 'المدينة المنورة', 'الدمام'],
    'فلسطين': ['غزة', 'خان يونس', 'القدس', 'رام الله', 'الخليل'],
    'جمهورية مصر العربية': ['القاهرة', 'الإسكندرية', 'المنصورة'],
  };

  final List<Map<String, dynamic>> _subjects = [
    {'name': 'الرياضيات', 'icon': Icons.calculate_rounded},
    {'name': 'العلوم', 'icon': Icons.science_rounded},
    {'name': 'اللغة الإنجليزية', 'icon': Icons.language_rounded},
    {'name': 'لغتي الجميلة', 'icon': Icons.menu_book_rounded},
    {'name': 'الدراسات الإسلامية', 'icon': Icons.mosque_rounded},
    {'name': 'الحاسب الآلي', 'icon': Icons.computer_rounded},
  ];

  String _selectedCountryCode = '+966';

  final List<Map<String, String>> _countryCodes = [
    {'code': '+966', 'flag': '🇸🇦', 'name': 'السعودية'},
    {'code': '+970', 'flag': '🇵🇸', 'name': 'فلسطين'},
    {'code': '+971', 'flag': '🇦🇪', 'name': 'الإمارات'},
    {'code': '+965', 'flag': '🇰🇼', 'name': 'الكويت'},
    {'code': '+962', 'flag': '🇯🇴', 'name': 'الأردن'},
    {'code': '+20', 'flag': '🇪🇬', 'name': 'مصر'},
  ];
  int _timerSeconds = 59;
  Timer? _otpTimer;

  void _startOTPTimer() {
    _timerSeconds = 59;
    _otpTimer?.cancel();
    _otpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_timerSeconds > 0) {
            _timerSeconds--;
          } else {
            _otpTimer?.cancel();
          }
        });
      }
    });
  }

  String _normalizePhone(String rawPhone) {
    String trimmed = rawPhone.trim();
    if (trimmed.startsWith('+')) {
      return trimmed;
    }
    String cleaned = trimmed.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (cleaned.startsWith('0')) {
      cleaned = cleaned.substring(1);
    }
    return '$_selectedCountryCode$cleaned';
  }

  Future<void> _pickAndUploadCertificate() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        setState(() => _isProcessingFile = true);

        Uint8List fileBytes = result.files.single.bytes!;
        String fileName = result.files.single.name;

        String? uploadedUrl = await _cloudinaryService.uploadFile(
          fileBytes: fileBytes,
          fileName: fileName,
          folder: 'certificates',
        );

        if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
          setState(() {
            _isFileUploaded = true;
            _certificateFileName = fileName;
            _certificateUrl = uploadedUrl;
            _isProcessingFile = false;
          });

          _showSnackBar('تم رفع الشهادة بنجاح 📄', LabeebTheme.oliveGreen);
        } else {
          throw Exception('تعذر الحصول على رابط الملف من Cloudinary');
        }
      }
    } catch (e) {
      print('Certificate Upload Error: $e');
      setState(() => _isProcessingFile = false);
      _showSnackBar('فشل رفع الملف: $e', LabeebTheme.accentOrange);
    }
  }

  // 🆔 دالة رفع الهوية أو جواز السفر الجديدة
  Future<void> _pickAndUploadIdentity() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        setState(() => _isProcessingIdFile = true);

        Uint8List fileBytes = result.files.single.bytes!;
        String fileName = result.files.single.name;

        String? uploadedUrl = await _cloudinaryService.uploadFile(
          fileBytes: fileBytes,
          fileName: fileName,
          folder: 'identity_documents',
        );

        if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
          setState(() {
            _isIdFileUploaded = true;
            _idFileName = fileName;
            _idUrl = uploadedUrl;
            _isProcessingIdFile = false;
          });

          _showSnackBar('تم رفع الهوية أو جواز السفر بنجاح 🪪', LabeebTheme.oliveGreen);
        } else {
          throw Exception('تعذر الحصول على رابط ملف الهوية من Cloudinary');
        }
      }
    } catch (e) {
      print('Identity Upload Error: $e');
      setState(() => _isProcessingIdFile = false);
      _showSnackBar('فشل رفع ملف الهوية: $e', LabeebTheme.accentOrange);
    }
  }

  Future<void> _sendOtp(String rawPhone) async {
    setState(() => _isLoading = true);
    final fullPhone = _normalizePhone(rawPhone);

    await _authService.sendOtp(
      phoneNumber: fullPhone,
      onCodeSent: (verificationId) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _isLoading = false;
          _currentStep = 1;
        });
        _startOTPTimer();
        _showSnackBar('تم إرسال رمز التحقق بنجاح 📩', LabeebTheme.oliveGreen);
      },
      onError: (e) {
        print('Firebase Auth Send OTP Error: ${e.code} - ${e.message}');
        if (!mounted) return;
        setState(() => _isLoading = false);
        _showSnackBar('تعذر إرسال الرمز: ${e.message ?? e.code}', LabeebTheme.accentOrange);
      },
      onAutoVerified: (credential) async {
        if (!mounted) return;
        final user = credential.user;
        if (user == null) return;
        final phone = _isSignUpMode
            ? _normalizePhone(_signUpPhoneController.text)
            : _normalizePhone(_phoneController.text);

        if (_isSignUpMode) {
          await _registerTeacherDirectly();
          return;
        }

        final userData = await _authService.getUserData(user.uid);
        if (widget.role == 'student') {
          if (userData == null) {
            await _authService.saveUserData(
                uid: user.uid, name: '', phone: phone, role: 'student');
            await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
              'sessionCredits': 1,
            }, SetOptions(merge: true));
          }
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _currentStep = 4;
          });
        } else {
          if (userData != null && userData['role'] == 'teacher') {
            final String status = userData['status'] ?? 'pending_approval';

            if (status == 'approved') {
              if (!mounted) return;
              setState(() => _isLoading = false);

              final teacherName = Uri.encodeComponent(userData['name'] ?? 'معلم لبيب');
              context.go('/teacher-dashboard?name=$teacherName');
            } else {
              if (!mounted) return;
              setState(() {
                _isLoading = false;
                _currentStep = 3;
              });
              _showSnackBar(
                'حسابك قيد المراجعة، يرجى انتظار قبول طلبك من لوحة إدارة المنصة ⏳',
                LabeebTheme.accentOrange,
              );
            }
          } else {
            if (!mounted) return;
            setState(() {
              _isLoading = false;
              _currentStep = 2;
              _signUpPhoneController.text = _phoneController.text;
            });
          }
        }
      },
    );
  }

  Future<void> _verifyOtp() async {
    final otp = _otpControllers.map((e) => e.text.trim()).join();
    if (otp.length < 6) {
      _showSnackBar('الرجاء إدخال الرمز كاملاً (6 أرقام)', LabeebTheme.accentOrange);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final credential = await _authService.verifyOtp(
        verificationId: _verificationId ?? '',
        smsCode: otp,
      );
      final user = credential?.user;
      if (user == null) throw Exception('فشل التحقق من الرمز');

      final phone = _isSignUpMode
          ? _normalizePhone(_signUpPhoneController.text)
          : _normalizePhone(_phoneController.text);

      if (_isSignUpMode) {
        await _registerTeacherDirectly();
        return;
      }

      final userData = await _authService.getUserData(user.uid);

      if (widget.role == 'student') {
        if (userData == null) {
          await _authService.saveUserData(
              uid: user.uid, name: '', phone: phone, role: 'student');
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'sessionCredits': 1,
          }, SetOptions(merge: true));
        }

        // 🚀 التحقق الذكي: إن كان للطالب اسم مسجل مسبقاً ولا يساوي "طالب لبيب" ننقله مباشرة
        if (userData != null && userData['name'] != null &&
            userData['name'].toString().trim().isNotEmpty &&
            userData['name'] != 'طالب لبيب') { // ✨ تمت إضافة هذا الشرط

          final String registeredName = userData['name'];
          if (!mounted) return;
          setState(() => _isLoading = false);

          final studentName = Uri.encodeComponent(registeredName);
          context.go('/student-dashboard?uid=${user.uid}&name=$studentName&subject=الرياضيات&type=now');
          return;
        }

        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _currentStep = 4;
        });
      } else {
        if (userData != null && userData['role'] == 'teacher') {
          final String status = userData['status'] ?? 'pending_approval';

          if (status == 'approved') {
            if (!mounted) return;
            setState(() => _isLoading = false);

            final teacherName = Uri.encodeComponent(userData['name'] ?? 'معلم لبيب');
            context.go('/teacher-dashboard?name=$teacherName');
          } else {
            if (!mounted) return;
            setState(() {
              _isLoading = false;
              _currentStep = 3;
            });
            _showSnackBar(
              'حسابك قيد المراجعة، يرجى انتظار قبول طلبك من لوحة إدارة المنصة ⏳',
              LabeebTheme.accentOrange,
            );
          }
        } else {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _currentStep = 2;
            _signUpPhoneController.text = _phoneController.text;
          });
          _showSnackBar('لا يوجد حساب معلم بهذا الرقم، أكمل بياناتك للتسجيل ✨',
              LabeebTheme.accentOrange);
        }
      }
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Verification Error: ${e.code} - ${e.message}');
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar('خطأ في التحقق: ${e.message ?? e.code}', LabeebTheme.accentOrange);
    } catch (e) {
      print('General Verification Error: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar('رمز التحقق غير صحيح، حاول مجدداً', LabeebTheme.accentOrange);
    }
  }

  Future<void> _createSessionRequest() async {
    final user = _authService.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      // ✨ بما أننا أضفنا التحقق من الاسم في الخطوة السابقة، فنحن متأكدون أنه ليس فارغاً
      final studentName = _nameController.text.trim();

      // 1. حفظ اسم الطالب في قاعدة البيانات أولاً
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': studentName,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 2. محاولة إنشاء الجلسة وخصم الرصيد
      if (_selectedSubject != null) {
        final sessionId = await SessionCheckService.createSessionRequest(
          studentId: user.uid,
          studentName: studentName,
          subject: _selectedSubject!,
          topic: _selectedSubject!,
        );

        // 3. تحديث الجلسة بوقت الجدولة إذا كان الطالب قد اختار ذلك
        if (_bookingType == 'schedule' && _selectedDate != null && _selectedTime != null) {
          DateTime scheduledAt = DateTime(
            _selectedDate!.year, _selectedDate!.month, _selectedDate!.day,
            _selectedTime!.hour, _selectedTime!.minute,
          );
          await FirebaseFirestore.instance.collection('sessions').doc(sessionId).update({
            'bookingType': 'schedule',
            'scheduledAt': Timestamp.fromDate(scheduledAt),
            'studentName': studentName,
          });
        } else {
          await FirebaseFirestore.instance.collection('sessions').doc(sessionId).update({
            'bookingType': 'now',
            'studentName': studentName,
          });
        }
      }

      // 4. الدخول للوحة التحكم مباشرة بعد حفظ البيانات
      if (!mounted) return;
      setState(() => _isLoading = false);

      final studentNameEncoded = Uri.encodeComponent(studentName);
      final subjectEncoded = Uri.encodeComponent(_selectedSubject ?? 'الرياضيات');
      context.go('/student-dashboard?uid=${user.uid}&name=$studentNameEncoded&subject=$subjectEncoded&type=$_bookingType');

    } catch (e) {
      print('Create Session Error: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);

      // ✨ الحل الذكي: إظهار رسالة الخطأ، لكن نسمح للطالب بالدخول للوحة التحكم لكي لا يعلق
      _showSnackBar(
        'تم تسجيلك بنجاح، ولكن حدث خطأ أثناء إنشاء الطلب: ${e.toString().replaceFirst('Exception: ', '')}. يمكنك طلب الحصة من لوحة التحكم.',
        LabeebTheme.accentOrange,
      );

      final fallbackName = Uri.encodeComponent(_nameController.text.trim());
      final fallbackSubject = Uri.encodeComponent(_selectedSubject ?? 'الرياضيات');
      context.go('/student-dashboard?uid=${user.uid}&name=$fallbackName&subject=$fallbackSubject&type=$_bookingType');
    }
  }

  void _handlePrimaryButton() {
    if (_isLoading) return;

    if (_currentStep == 0) {
      if (_phoneController.text.trim().length < 9) {
        _showSnackBar('الرجاء إدخال رقم جوال صحيح', LabeebTheme.accentOrange);
        return;
      }
      _isSignUpMode = false;
      _sendOtp(_phoneController.text);
    } else if (_currentStep == 1) {
      _verifyOtp();
    } else if (_currentStep == 2) {
      if (_nameController.text.trim().isEmpty ||
          _signUpPhoneController.text.trim().isEmpty ||
          _selectedCountry == null ||
          _selectedCity == null ||
          _specialtyController.text.trim().isEmpty ||
          _selectedTargetAge == null ||
          !_isFileUploaded ||
          !_isIdFileUploaded) {
        _showSnackBar('الرجاء إدخال كافة الحقول ورفع الشهادة والهوية المطلوبة',
            LabeebTheme.accentOrange);
        return;
      }
      _isSignUpMode = true;
      _registerTeacherDirectly();
    } else if (_currentStep == 3) {
      context.go('/'); // العودة للرئيسية
    } else if (_currentStep == 4) {
      // ✨ التحقق من إدخال الاسم لمنع حفظ "طالب لبيب" في الداتابيز
      if (_nameController.text.trim().isEmpty) {
        _showSnackBar('الرجاء إدخال اسمك أولاً للمتابعة', LabeebTheme.accentOrange);
        return;
      }

      if (_selectedSubject == null) {
        _showSnackBar('الرجاء اختيار المادة التعليمية أولاً', LabeebTheme.accentOrange);
        return;
      }
      if (_bookingType == 'schedule' &&
          (_selectedDate == null || _selectedTime == null)) {
        _showSnackBar('الرجاء اختيار تاريخ ووقت الحصة', LabeebTheme.accentOrange);
        return;
      }
      _createSessionRequest();
    }
  }

  Future<void> _registerTeacherDirectly() async {
    final user = _authService.currentUser;

    if (user == null) {
      _sendOtp(_signUpPhoneController.text);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final phone = _normalizePhone(_signUpPhoneController.text);

      await _authService.saveUserData(
        uid: user.uid,
        name: _nameController.text.trim(),
        phone: phone,
        role: 'teacher',
        country: _selectedCountry,
        city: _selectedCity,
        subjects: [_specialtyController.text.trim()],
        status: 'pending_approval',
      );

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'targetAge': _selectedTargetAge,
        'certificates': _certificateUrl != null ? [_certificateUrl] : [],
        'certificateName': _certificateFileName ?? '',
        'identityUrl': _idUrl ?? '',
        'identityFileName': _idFileName ?? '',
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _currentStep = 3;
      });
      _showSnackBar('تم تقديم طلب التسجيل بنجاح ✅ سيتم مراجعة بياناتك قريباً', LabeebTheme.oliveGreen);
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error Code: ${e.code}');
      print('Firebase Auth Error Message: ${e.message}');
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar('خطأ فايربيز: ${e.message ?? e.code}', LabeebTheme.accentOrange);
    } catch (e) {
      print('General Registration Error: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar('حدث خطأ أثناء التسجيل: $e', LabeebTheme.accentOrange);
    }
  }

  void _showSnackBar(String text, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text,
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _previousStep() {
    if (_currentStep == 1 || _currentStep == 2 || _currentStep == 3 || _currentStep == 4) {
      setState(() => _currentStep = 0);
    } else {
      context.go('/'); // العودة للرئيسية باستخدام go_router
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked != null) setState(() => _selectedTime = picked);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _specialtyController.dispose();
    _signUpPhoneController.dispose();
    _otpTimer?.cancel();
    for (var c in _otpControllers) {
      c.dispose();
    }
    for (var n in _otpFocusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String roleTitle = widget.role == 'student' ? 'الطالب الطموح' : 'المعلم لبيب';

    return Scaffold(
      backgroundColor: LabeebTheme.beigeBackground,
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: SelectionArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22.0),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 550),
                  padding: const EdgeInsets.all(28.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 24,
                          offset: const Offset(0, 8))
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_rounded,
                                color: LabeebTheme.textDark),
                            onPressed: _previousStep,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: LabeebTheme.accentOrange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              roleTitle,
                              style: const TextStyle(
                                  color: LabeebTheme.accentOrange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: List.generate(4, (index) {
                          return Expanded(
                            child: Container(
                              height: 6,
                              margin: EdgeInsets.only(left: index == 3 ? 0 : 6),
                              decoration: BoxDecoration(
                                color: index <= _currentStep
                                    ? LabeebTheme.oliveGreen
                                    : LabeebTheme.oliveGreen.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 30),
                      _buildCurrentStepWidget(),
                      const SizedBox(height: 25),
                      if (_currentStep != 3)
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: LabeebTheme.oliveGreen,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: _isLoading ? null : _handlePrimaryButton,
                            child: _isLoading
                                ? const SizedBox(
                                width: 26,
                                height: 26,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 3))
                                : Text(
                              _currentStep == 4
                                  ? 'تأكيد الحصة والدخول الفوري 🚀'
                                  : (_currentStep == 2
                                  ? 'تقديم طلب الحساب للمراجعة ✨'
                                  : 'استمرار للمرحلة التالية'),
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Cairo'),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStepWidget() {
    switch (_currentStep) {
      case 0:
        return _buildPhoneStep();
      case 1:
        return _buildOTPStep();
      case 2:
        return _buildTeacherSignUpStep();
      case 3:
        return _buildReviewPendingStep();
      case 4:
        return _buildSubjectAndTimingStep();
      default:
        return _buildPhoneStep();
    }
  }

  Widget _buildPhoneStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'أهلاً بك، سجل دخولك برقم الجوال',
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: LabeebTheme.textDark),
        ),
        const SizedBox(height: 10),
        const Text(
          'قم بإدخال رقم هاتفك المحمول وسيصلك رمز تحقق حقيقي عبر رسالة نصية.',
          style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.5),
        ),
        const SizedBox(height: 25),
        const Text(
          'رقم الجوال لتسجيل الدخول',
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.bold, color: LabeebTheme.textDark),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            hintText: '5xxxxxxxx',
            prefixIcon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCountryCode,
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.black54),
                      items: _countryCodes.map((country) {
                        return DropdownMenuItem<String>(
                          value: country['code'],
                          child: Text(
                            '${country['flag']} ${country['code']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                            textDirection: TextDirection.ltr,
                          ),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedCountryCode = newValue;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 4),
                  const SizedBox(
                    height: 20,
                    child: VerticalDivider(
                      color: Colors.black26,
                      thickness: 1,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
              ),
            ),
            filled: true,
            fillColor: LabeebTheme.beigeCard,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (widget.role == 'teacher')
          Center(
            child: TextButton(
              onPressed: () => setState(() => _currentStep = 2),
              child: const Text(
                'ليس لدي حساب؟ عمل حساب معلم جديد الآن',
                style: TextStyle(
                    color: LabeebTheme.accentOrange,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    decoration: TextDecoration.underline),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildOTPStep() {
    final displayPhone = _isSignUpMode
        ? _signUpPhoneController.text
        : _phoneController.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'أدخل رمز التحقق الفوري',
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: LabeebTheme.textDark),
        ),
        const SizedBox(height: 8),
        RichText(
          text: TextSpan(
            style: const TextStyle(
                fontFamily: 'Cairo', fontSize: 13, color: Colors.black54, height: 1.5),
            children: [
              const TextSpan(text: 'تم إرسال رمز مكون من 6 أرقام إلى رقمك '),
              TextSpan(
                  text: '$_selectedCountryCode $displayPhone',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: LabeebTheme.accentOrange)),
            ],
          ),
        ),
        const SizedBox(height: 25),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (index) {
            return SizedBox(
              width: 48,
              height: 56,
              child: TextField(
                controller: _otpControllers[index],
                focusNode: _otpFocusNodes[index],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 1,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: LabeebTheme.beigeCard,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
                onChanged: (value) {
                  if (value.isNotEmpty && index < 5) {
                    _otpFocusNodes[index + 1].requestFocus();
                  } else if (value.isEmpty && index > 0) {
                    _otpFocusNodes[index - 1].requestFocus();
                  }
                },
              ),
            );
          }),
        ),
        const SizedBox(height: 20),
        Center(
          child: _timerSeconds > 0
              ? Text('إعادة إرسال الرمز خلال $_timerSeconds ثانية',
              style: const TextStyle(color: Colors.black54, fontSize: 13))
              : TextButton(
            onPressed: () => _sendOtp(
                _isSignUpMode ? _signUpPhoneController.text : _phoneController.text),
            child: const Text('إعادة إرسال رمز التحقق الفوري',
                style: TextStyle(
                    color: LabeebTheme.accentOrange, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildTeacherSignUpStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'إنشاء حساب معلم جديد',
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: LabeebTheme.textDark),
        ),
        const SizedBox(height: 5),
        const Text(
          'سجل معنا كمعلم معتمد. بعد تعبئة البيانات سنتحقق من رقمك برسالة نصية.',
          style: TextStyle(fontSize: 13, color: Colors.black54),
        ),
        const SizedBox(height: 18),
        const Text('رقم الموبايل', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        _buildTextField(controller: _signUpPhoneController, hint: '5xxxxxxxx', isPhone: true),
        const SizedBox(height: 12),
        const Text('الاسم رباعي بالكامل',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        _buildTextField(
            controller: _nameController, hint: 'أدخل اسمك الرباعي كما هو بالهوية الوطنية'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('الدولة',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  _buildDropdown(
                    value: _selectedCountry,
                    hint: 'اختر الدولة',
                    items: _countries,
                    onChanged: (val) {
                      setState(() {
                        _selectedCountry = val;
                        _selectedCity = null;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('المدينة',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  _buildDropdown(
                    value: _selectedCity,
                    hint: 'اختر المدينة',
                    items: _selectedCountry != null ? (_cities[_selectedCountry] ?? []) : [],
                    onChanged: (val) => setState(() => _selectedCity = val),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text('التخصص الجامعي الحالي',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        _buildTextField(
            controller: _specialtyController, hint: 'مثال: بكالوريوس رياضيات / أدب إنجليزي'),
        const SizedBox(height: 12),
        const Text('الفئة العمرية / الصف الدراسي الذي تدرسه',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        _buildDropdown(
          value: _selectedTargetAge,
          hint: 'حدد الفئة التعليمية المستهدفة',
          items: [
            'تأسيس وصفوف أولية',
            'المرحلة الابتدائية العليا',
            'المرحلة المتوسطة',
            'المرحلة الثانوية العامة',
            'التعليم الجامعي المستمر'
          ],
          onChanged: (val) => setState(() => _selectedTargetAge = val),
        ),
        const SizedBox(height: 16),

        // --- زر رفع الشهادة الدراسية ---
        InkWell(
          onTap: _isProcessingFile ? null : _pickAndUploadCertificate,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: _isFileUploaded
                  ? LabeebTheme.oliveGreen.withOpacity(0.08)
                  : Colors.black.withOpacity(0.02),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: _isFileUploaded ? LabeebTheme.oliveGreen : Colors.black12),
            ),
            child: Row(
              children: [
                _isProcessingFile
                    ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: LabeebTheme.accentOrange,
                  ),
                )
                    : Icon(
                  _isFileUploaded ? Icons.verified_rounded : Icons.cloud_upload_rounded,
                  color: _isFileUploaded
                      ? LabeebTheme.oliveGreen
                      : LabeebTheme.accentOrange,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isProcessingFile
                        ? 'جاري رفع الشهادة...'
                        : (_isFileUploaded
                        ? 'تم رفع الشهادة: $_certificateFileName'
                        : 'اختر الشهادة لرفعها مباشرة'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: _isFileUploaded ? FontWeight.bold : FontWeight.normal,
                      color: _isFileUploaded ? LabeebTheme.oliveGreen : Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),

        // --- 🆔 زر رفع الهوية الشخصية أو جواز السفر الجديد ---
        const SizedBox(height: 12),
        InkWell(
          onTap: _isProcessingIdFile ? null : _pickAndUploadIdentity,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: _isIdFileUploaded
                  ? LabeebTheme.oliveGreen.withOpacity(0.08)
                  : Colors.black.withOpacity(0.02),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: _isIdFileUploaded ? LabeebTheme.oliveGreen : Colors.black12),
            ),
            child: Row(
              children: [
                _isProcessingIdFile
                    ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: LabeebTheme.accentOrange,
                  ),
                )
                    : Icon(
                  _isIdFileUploaded ? Icons.verified_rounded : Icons.badge_rounded,
                  color: _isIdFileUploaded
                      ? LabeebTheme.oliveGreen
                      : LabeebTheme.accentOrange,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isProcessingIdFile
                        ? 'جاري رفع الهوية / جواز السفر...'
                        : (_isIdFileUploaded
                        ? 'تم رفع الهوية: $_idFileName'
                        : 'اختر الهوية الشخصية أو جواز السفر لرفعها'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: _isIdFileUploaded ? FontWeight.bold : FontWeight.normal,
                      color: _isIdFileUploaded ? LabeebTheme.oliveGreen : Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewPendingStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 15),
        const Icon(Icons.lock_clock_rounded, size: 75, color: LabeebTheme.accentOrange),
        const SizedBox(height: 20),
        const Text(
          'تم تقديم طلبك بنجاح وجاري مراجعته!',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: LabeebTheme.textDark),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            'أهلاً بك يا أستاذ ${_nameController.text.trim()} في منصة لبيب. تم رفع شهادتك وهويتك وحفظ طلبك في قاعدة البيانات، وستصلك رسالة فور تفعيل الحساب من الإدارة.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Colors.black54, height: 1.6),
          ),
        ),
        const SizedBox(height: 25),
        SizedBox(
          width: 200,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: LabeebTheme.oliveGreen),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => setState(() => _currentStep = 0),
            child: const Text('العودة للرئيسية',
                style: TextStyle(color: LabeebTheme.oliveGreen, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildSubjectAndTimingStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'تحديد تفاصيل وموعد الحصة الدراسية',
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: LabeebTheme.textDark),
        ),
        const SizedBox(height: 14),
        const Text('1. ما اسمك؟',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: LabeebTheme.oliveGreen)),
        const SizedBox(height: 8),
        _buildTextField(controller: _nameController, hint: 'اكتب اسمك هنا'),
        const SizedBox(height: 18),
        const Text('2. اختر المادة التعليمية:',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: LabeebTheme.oliveGreen)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _subjects.map((subject) {
            final bool isSelected = _selectedSubject == subject['name'];
            return InkWell(
              onTap: () => setState(() => _selectedSubject = subject['name']),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? LabeebTheme.oliveGreen : LabeebTheme.beigeCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: isSelected
                          ? LabeebTheme.oliveGreen
                          : Colors.black.withOpacity(0.06)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(subject['icon'],
                        color: isSelected ? Colors.white : LabeebTheme.accentOrange,
                        size: 18),
                    const SizedBox(width: 6),
                    Text(subject['name'],
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : LabeebTheme.textDark)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 18),
        const Text('3. متى ترغب في بدء الحصة؟',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: LabeebTheme.oliveGreen)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _bookingType = 'now'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _bookingType == 'now'
                        ? LabeebTheme.accentOrange.withOpacity(0.12)
                        : LabeebTheme.beigeCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: _bookingType == 'now'
                            ? LabeebTheme.accentOrange
                            : Colors.black12),
                  ),
                  child: Column(
                    children: const [
                      Icon(Icons.flash_on_rounded, color: LabeebTheme.accentOrange, size: 20),
                      SizedBox(height: 4),
                      Text('فوراً الآن',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _bookingType = 'schedule'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _bookingType == 'schedule'
                        ? LabeebTheme.accentOrange.withOpacity(0.12)
                        : LabeebTheme.beigeCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: _bookingType == 'schedule'
                            ? LabeebTheme.accentOrange
                            : Colors.black12),
                  ),
                  child: Column(
                    children: const [
                      Icon(Icons.calendar_month_rounded,
                          color: LabeebTheme.accentOrange, size: 20),
                      SizedBox(height: 4),
                      Text('جدولة لوقت لاحق',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_bookingType == 'schedule') ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.date_range_rounded,
                      color: LabeebTheme.oliveGreen, size: 18),
                  label: Text(
                      _selectedDate == null
                          ? 'اختر التاريخ'
                          : _selectedDate!.toLocal().toString().split(' ')[0],
                      style: const TextStyle(color: LabeebTheme.textDark, fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.access_time_rounded,
                      color: LabeebTheme.oliveGreen, size: 18),
                  label: Text(
                      _selectedTime == null ? 'اختر الوقت' : _selectedTime!.format(context),
                      style: const TextStyle(color: LabeebTheme.textDark, fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildTextField(
      {required TextEditingController controller,
        required String hint,
        bool isPhone = false}) {
    return TextField(
      controller: controller,
      keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: Colors.black38),
        filled: true,
        fillColor: LabeebTheme.beigeCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildDropdown(
      {required String? value,
        required String hint,
        required List<String> items,
        required ValueChanged<String?> onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
          color: LabeebTheme.beigeCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black.withOpacity(0.05))),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: const TextStyle(fontSize: 13, color: Colors.black38)),
          isExpanded: true,
          items: items
              .map((String val) => DropdownMenuItem<String>(
              value: val, child: Text(val, style: const TextStyle(fontSize: 13))))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ==========================================
// 2. كلاس خدمة Cloudinary (مدمج مباشرة بالأسفل)
// ==========================================
class CloudinaryService {
  static const String _cloudName = 'f4t8ayoq';
  static const String _uploadPreset = 'lzgw58tq';

  Future<String?> uploadFile({
    required Uint8List fileBytes,
    required String fileName,
    String folder = 'certificates',
  }) async {
    try {
      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/auto/upload');

      var request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = _uploadPreset
        ..fields['folder'] = folder
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            fileBytes,
            filename: fileName,
          ),
        );

      var response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final jsonMap = jsonDecode(responseData);
        return jsonMap['secure_url'] as String?;
      } else {
        debugPrint('Cloudinary Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Cloudinary Exception: $e');
      return null;
    }
  }
}