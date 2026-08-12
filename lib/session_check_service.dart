import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:js_interop';

// استدعاءات الـ JavaScript الخارجية للويب الخاصة بمشاركة الشاشة
@JS('initAgoraWebScreenShare')
external JSPromise<JSBoolean> _initAgoraWebScreenShare(JSString appId, JSString channel, JSString token, JSNumber uid);

@JS('stopAgoraWebScreenShare')
external JSPromise<JSBoolean> _stopAgoraWebScreenShare();

class SessionCheckService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ⚙️ إعدادات Cloudinary
  static const String _cloudinaryCloudName = 'f4t8ayoq';
  static const String _cloudinaryUploadPreset = 'lzgw58tq';

  // ==========================================
  //  إدارة الصوت المباشر (Agora Voice Engine)
  // ==========================================

  static const String _agoraAppId = '3a54c447b558405da3e87b1177ccc463';

  static RtcEngine? _agoraEngine;
  static bool _isMuted = false;

  static bool get isMuted => _isMuted;
  static RtcEngine? get agoraEngine => _agoraEngine; // ✨ لإظهار الفيديو في الواجهة

  /// 🛠️ دالة جلب Token ديناميكي من سيرفر Node.js
  /// 🛠️ دالة جلب Token ديناميكي من سيرفر Node.js
  /// 🛠️ دالة جلب Token ديناميكي من سيرفر Node.js
  /// 🛠️ دالة جلب Token ديناميكي من سيرفر Node.js
  static Future<String> fetchDynamicToken({required String channelName, required int uid}) async {
    try {
      // ✨ رابط السيرفر الحقيقي على Render
      const String serverBaseUrl = 'https://agora-server-59qz.onrender.com';

      final String serverUrl = '$serverBaseUrl/rtc-token?channelName=$channelName&uid=$uid';
      final response = await http.get(Uri.parse(serverUrl));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['token'] ?? '';
      } else {
        debugPrint('Failed to get token from server: ${response.statusCode}');
        return '';
      }
    } catch (e) {
      debugPrint("Error fetching token from server: $e");
      return '';
    }
  }

  /// 1. تهيئة محرك الاتصال الصوتي
  static Future<void> initAudioEngine() async {
    if (_agoraEngine != null) return;

    try {
      _agoraEngine = createAgoraRtcEngine();
      await _agoraEngine!.initialize(
        const RtcEngineContext(
          appId: _agoraAppId,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        ),
      );

      await _agoraEngine!.enableAudio();
      await _agoraEngine!.enableVideo();
      await _agoraEngine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    } catch (e) {
      debugPrint("Agora initialization error: $e");
    }
  }

  /// 2. الانضمام إلى غرفة الصوت الخاصة بالجلسة
  static Future<void> joinAudioChannel({
    required String sessionId,
    String? token,
  }) async {
    final currentUser = _auth.currentUser;
    final int numericUid = currentUser != null
        ? currentUser.uid.hashCode.abs() % 100000
        : DateTime.now().millisecondsSinceEpoch % 100000;

    final String activeToken = token ?? await fetchDynamicToken(channelName: sessionId, uid: numericUid);

    if (_agoraEngine == null) {
      await initAudioEngine();
    }

    try {
      await _agoraEngine!.setClientRole(
        role: ClientRoleType.clientRoleBroadcaster,
      );

      await _agoraEngine!.joinChannel(
        token: activeToken,
        channelId: sessionId,
        uid: numericUid,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          publishMicrophoneTrack: true,
          autoSubscribeAudio: true,
          publishCameraTrack: false,
          publishScreenTrack: false,
          autoSubscribeVideo: true,
        ),
      );
      _isMuted = false;
    } catch (e) {
      debugPrint("Join Agora channel error: $e");
    }
  }

  /// 2. أ - انضمام المدير للمراقبة بصمت تام
  static Future<void> joinAudioChannelAsAdmin({
    required String sessionId,
    required String adminToken,
  }) async {
    if (_agoraEngine == null) {
      await initAudioEngine();
    }

    final currentUser = _auth.currentUser;
    final int adminNumericUid = currentUser != null
        ? currentUser.uid.hashCode.abs() % 100000
        : DateTime.now().millisecondsSinceEpoch % 100000;

    final String activeAdminToken = adminToken.isNotEmpty
        ? adminToken
        : await fetchDynamicToken(channelName: sessionId, uid: adminNumericUid);

    try {
      await _agoraEngine!.setClientRole(
        role: ClientRoleType.clientRoleAudience,
      );

      await _agoraEngine!.joinChannel(
        token: activeAdminToken,
        channelId: sessionId,
        uid: adminNumericUid,
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          clientRoleType: ClientRoleType.clientRoleAudience,
          publishMicrophoneTrack: false,
          publishCameraTrack: false,
          publishScreenTrack: false,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
        ),
      );
      _isMuted = true;
    } catch (e) {
      debugPrint("Join Agora channel as admin error: $e");
    }
  }

  /// 3. كتم / تشغيل المايك
  static Future<bool> toggleMuteAudio() async {
    if (_agoraEngine == null) return false;
    _isMuted = !_isMuted;
    await _agoraEngine!.muteLocalAudioStream(_isMuted);
    return _isMuted;
  }

  /// 3. ب - تفعيل أو إيقاف مشاركة الشاشة
  /// 3. ب - تفعيل أو إيقاف مشاركة الشاشة (يدعم الويب والموبايل بدون أكواد JS)
  static Future<bool> toggleScreenShare(bool enable, {String sessionId = '', String? token}) async {
    if (_agoraEngine == null) return false;
    try {
      if (enable) {
        // تفعيل مشاركة الشاشة
        await _agoraEngine!.startScreenCapture(
          const ScreenCaptureParameters2(
            captureVideo: true,
            captureAudio: false,
          ),
        );
        await _agoraEngine!.updateChannelMediaOptions(
          const ChannelMediaOptions(
            publishScreenTrack: true,
            publishCameraTrack: false,
            publishMicrophoneTrack: true, // إبقاء الصوت يعمل أثناء مشاركة الشاشة
          ),
        );
      } else {
        // إيقاف مشاركة الشاشة
        await _agoraEngine!.stopScreenCapture();
        await _agoraEngine!.updateChannelMediaOptions(
          const ChannelMediaOptions(
            publishScreenTrack: false,
            publishCameraTrack: false,
            publishMicrophoneTrack: true,
          ),
        );
      }
      return enable;
    } catch (e) {
      debugPrint("Screen share exact error: $e");
      return !enable;
    }
  }

  /// 4. مغادرة قناة الصوت وتفريغ الموارد
  static Future<void> leaveAndReleaseAudio() async {
    if (_agoraEngine != null) {
      try {
        await _agoraEngine!.leaveChannel();
        await _agoraEngine!.release();
      } catch (e) {
        debugPrint("Release Agora error: $e");
      } finally {
        _agoraEngine = null;
        _isMuted = false;
      }
    }
  }

  // ==========================================
  //  فحوصات الشبكة والمايك (Hardware Checks)
  // ==========================================

  static Future<bool> checkMicrophone() async {
    try {
      final mediaDevices = html.window.navigator.mediaDevices;
      if (mediaDevices == null) return false;

      final mediaStream = await mediaDevices.getUserMedia({'audio': true});

      List tracks = mediaStream.getTracks();
      for (var track in tracks) {
        track.stop();
      }
      return true;
    } catch (e) {
      debugPrint("Microphone access error: $e");
      return false;
    }
  }

  static Future<int> checkNetworkLatency() async {
    if (html.window.navigator.onLine == false) {
      return -1;
    }

    final Completer<int> completer = Completer<int>();
    final Stopwatch stopwatch = Stopwatch()..start();

    final html.ImageElement img = html.ImageElement();
    final String cacheBuster = DateTime.now().millisecondsSinceEpoch.toString();

    img.src = 'https://1.1.1.1/favicon.ico?v=$cacheBuster';

    img.onLoad.listen((_) {
      stopwatch.stop();
      if (!completer.isCompleted) {
        completer.complete(stopwatch.elapsedMilliseconds);
      }
    });

    img.onError.listen((_) {
      stopwatch.stop();
      if (!completer.isCompleted) {
        completer.complete(stopwatch.elapsedMilliseconds > 0 ? stopwatch.elapsedMilliseconds : 120);
      }
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (!completer.isCompleted) {
        completer.complete(-1);
      }
    });

    return completer.future;
  }

  // ==========================================
  //  إدارة الجلسات والخصم الآمن
  // ==========================================

  static Future<String> createSessionRequest({
    required String studentId,
    required String studentName,
    required String subject,
    required String topic,
  }) async {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw Exception("يجب تسجيل الدخول أولاً لإنشاء طلب.");
    }

    // ✨ نستخدم UID الخاص بالمستخدم الحالي مباشرة لضمان الأمان ومنع خطأ التطابق
    final String uid = currentUser.uid;

    final userRef = _firestore.collection('users').doc(uid);
    final userSnap = await userRef.get();

    if (!userSnap.exists) {
      throw Exception("حساب الطالب غير موجود.");
    }

    final userData = userSnap.data() as Map<String, dynamic>;
    final dynamic rawCredits = userData['sessionCredits'];
    final int currentCredits = (rawCredits is int) ? rawCredits : 0;

    if (currentCredits <= 0) {
      throw Exception("رصيدك الحالي لا يكفي لإنشاء حصة جديدة. يرجى شحن المحفظة.");
    }

    await userRef.update({
      'sessionCredits': currentCredits - 1,
    });

    final sessionRef = _firestore.collection('sessions').doc();
    await sessionRef.set({
      'studentId': uid, // ✨ نحفظ الـ UID الحقيقي
      'studentName': studentName,
      'teacherId': null,
      'assignedTeacherId': null,
      'teacherName': null,
      'teacher': null,
      'instructorName': null,
      'subject': subject,
      'topic': topic,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'audioRecordingUrl': null,
      'boardPdfUrl': null,
    });

    return sessionRef.id;
  }

  static Future<void> cancelSessionRequest(String sessionId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final sessionRef = _firestore.collection('sessions').doc(sessionId);

    await _firestore.runTransaction((transaction) async {
      final sessionSnap = await transaction.get(sessionRef);
      if (!sessionSnap.exists) return;

      final sessionData = sessionSnap.data();
      if (sessionData?['status'] == 'pending' && sessionData?['studentId'] == currentUser.uid) {
        final userRef = _firestore.collection('users').doc(currentUser.uid);
        final userSnap = await transaction.get(userRef);

        if (userSnap.exists) {
          final userData = userSnap.data() as Map<String, dynamic>;
          final int currentCredits = userData['sessionCredits'] ?? 0;

          transaction.update(userRef, {
            'sessionCredits': currentCredits + 1,
          });
        }

        transaction.update(sessionRef, {
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }
  // ==========================================
  //  تمديد الحصة وخصم الرصيد الإضافي
  // ==========================================

  static Future<void> extendSessionDuration({
    required String sessionId,
    required String studentId,
  }) async {
    final currentUser = _auth.currentUser;

    if (currentUser == null || currentUser.uid != studentId) {
      throw Exception("إجراء غير مصرح به: لا يمكنك تمديد جلسة لمستخدم آخر.");
    }

    final userRef = _firestore.collection('users').doc(studentId);
    final userSnap = await userRef.get();

    if (!userSnap.exists) {
      throw Exception("حساب الطالب غير موجود.");
    }

    final userData = userSnap.data() as Map<String, dynamic>;
    final dynamic rawCredits = userData['sessionCredits'];
    final int currentCredits = (rawCredits is int) ? rawCredits : 0;

    if (currentCredits <= 0) {
      throw Exception("رصيدك الحالي لا يكفي لتمديد الحصة. يرجى شحن المحفظة أولاً.");
    }

    // خصم الرصيد
    await userRef.update({
      'sessionCredits': currentCredits - 1,
    });

    // تسجيل التمديد في وثيقة الجلسة (لمتابعة الأدمن ولضمان عدم تكرار الخصم)
    await _firestore.collection('sessions').doc(sessionId).update({
      'extensionsCount': FieldValue.increment(1),
      'lastExtendedAt': FieldValue.serverTimestamp(),
    });
  }
  static Future<bool> acceptSession({
    required String sessionId,
    required String teacherId,
    required String teacherName,
  }) async {
    final currentUser = _auth.currentUser;

    if (currentUser == null || currentUser.uid != teacherId) {
      throw Exception("إجراء غير مصرح به: بيانات المعلم غير متطابقة.");
    }

    final sessionRef = _firestore.collection('sessions').doc(sessionId);

    return await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(sessionRef);

      if (!snapshot.exists) return false;

      final data = snapshot.data();
      if (data != null && data['status'] == 'pending') {
        final updateData = <String, dynamic>{
          'teacherId': teacherId,
          'assignedTeacherId': teacherId,
          'status': 'accepted',
          'acceptedAt': FieldValue.serverTimestamp(),
          // ✨ نستخدم الاسم الممرر مباشرة لضمان عدم الخلط
          'teacherName': teacherName,
          'teacher': teacherName,
          'instructorName': teacherName,
        };
        transaction.update(sessionRef, updateData);
        return true;
      } else {
        return false;
      }
    });
  }

  static Stream<QuerySnapshot> listenToPendingSessions() {
    return _firestore
        .collection('sessions')
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  // ==========================================
  //  رفع الملفات إلى Cloudinary وإنهاء الجلسة
  // ==========================================

  static Future<String?> _uploadBytesToCloudinary({
    required Uint8List bytes,
    required String fileName,
    required String resourceType,
  }) async {
    try {
      final url = Uri.parse("https://api.cloudinary.com/v1_1/$_cloudinaryCloudName/$resourceType/upload");

      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = _cloudinaryUploadPreset
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: fileName,
          ),
        );

      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final jsonResponse = jsonDecode(responseData);
        return jsonResponse['secure_url'] as String?;
      } else {
        debugPrint("Cloudinary Error Code: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Cloudinary upload exception: $e");
    }
    return null;
  }

  static Future<String?> uploadAudioRecording({
    required String sessionId,
    required Uint8List audioBytes,
  }) async {
    return await _uploadBytesToCloudinary(
      bytes: audioBytes,
      fileName: 'session_${sessionId}_audio.mp3',
      resourceType: 'video',
    );
  }

  static Future<String?> uploadBoardPdf({
    required String sessionId,
    required Uint8List pdfBytes,
  }) async {
    return await _uploadBytesToCloudinary(
      bytes: pdfBytes,
      fileName: 'session_${sessionId}_board.pdf',
      resourceType: 'auto',
    );
  }

  static Future<void> completeSession({
    required String sessionId,
    Uint8List? audioBytes,
    Uint8List? pdfBytes,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception("يجب تسجيل الدخول لإنهاء الجلسة.");
    }

    final sessionRef = _firestore.collection('sessions').doc(sessionId);
    final sessionSnap = await sessionRef.get();

    if (!sessionSnap.exists) return;

    final sessionData = sessionSnap.data();
    if (sessionData?['studentId'] != currentUser.uid && sessionData?['teacherId'] != currentUser.uid) {
      throw Exception("غير مصرح لك بإنهاء هذه الجلسة.");
    }

    await leaveAndReleaseAudio();

    String? audioUrl;
    if (audioBytes != null && audioBytes.isNotEmpty) {
      audioUrl = await uploadAudioRecording(
        sessionId: sessionId,
        audioBytes: audioBytes,
      );
    }

    String? pdfUrl;
    if (pdfBytes != null && pdfBytes.isNotEmpty) {
      pdfUrl = await uploadBoardPdf(
        sessionId: sessionId,
        pdfBytes: pdfBytes,
      );
    }

    await sessionRef.update({
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
      if (audioUrl != null) 'audioRecordingUrl': audioUrl,
      if (pdfUrl != null) 'boardPdfUrl': pdfUrl,
    });
  }
}