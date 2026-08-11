import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  ConfirmationResult? _webConfirmationResult;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();  int? _resendToken;

  // 1️⃣ إرسال رمز التحقق (يدعم الويب والجوال معاً)
  Future<void> sendOtp({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(FirebaseAuthException e) onError,
    Function(UserCredential credential)? onAutoVerified,
  }) async {
    try {
      if (kIsWeb) {
        // 🌐 في المتصفح: استخدام signInWithPhoneNumber مباشرة وسيقوم Firebase بالتعامل مع reCAPTCHA تلقائياً عبر الـ container في index.html
        final ConfirmationResult confirmationResult =
        await _auth.signInWithPhoneNumber(phoneNumber);

        // حفظ نتيجة الجلسة للويب
        _webConfirmationResult = confirmationResult;

        // إرجاع الـ verificationId الخاص بـ Firebase للويب
        onCodeSent(confirmationResult.verificationId);
      } else {
        // 📱 في تطبيقات الجوال (Android / iOS)
        await _auth.verifyPhoneNumber(
          phoneNumber: phoneNumber,
          timeout: const Duration(seconds: 120),
          verificationCompleted: (PhoneAuthCredential credential) async {
            final userCredential = await _auth.signInWithCredential(credential);
            if (onAutoVerified != null) {
              onAutoVerified(userCredential);
            }
          },
          verificationFailed: onError,
          codeSent: (String verificationId, int? resendToken) {
            _resendToken = resendToken;
            onCodeSent(verificationId);
          },
          codeAutoRetrievalTimeout: (String verificationId) {},
          forceResendingToken: _resendToken,
        );
      }
    } on FirebaseAuthException catch (e) {
      onError(e);
    } catch (e) {
      onError(FirebaseAuthException(
        code: 'web-auth-error',
        message: e.toString(),
      ));
    }
  }

  // 2️⃣ التحقق من الرمز
  Future<UserCredential?> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      if (kIsWeb) {
        if (_webConfirmationResult != null) {
          return await _webConfirmationResult!.confirm(smsCode);
        } else {
          throw FirebaseAuthException(
            code: 'null-confirmation-result',
            message: 'انتهت الجلسة، يرجى طلب رمز تحقق جديد.',
          );
        }
      } else {
        final credential = PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: smsCode,
        );
        return await _auth.signInWithCredential(credential);
      }
    } catch (e) {
      rethrow;
    }
  }

  // 3️⃣ حفظ بيانات المستخدم
  Future<void> saveUserData({
    required String uid,
    required String name,
    required String phone,
    required String role,
    String? country,
    String? city,
    String? grade,
    List<String>? subjects,
    String status = 'active',
  }) async {
    await _db.collection('users').doc(uid).set({
      'uid': uid,
      'name': name,
      'phone': phone,
      'role': role,
      'country': country ?? '',
      'city': city ?? '',
      if (grade != null) 'grade': grade,
      if (subjects != null) 'subjects': subjects,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // 4️⃣ جلب بيانات المستخدم
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.exists ? doc.data() : null;
  }

  // 5️⃣ تسجيل الخروج
  Future<void> signOut() async {
    _webConfirmationResult = null;
    await _auth.signOut();
  }
}