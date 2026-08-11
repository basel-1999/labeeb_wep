import 'dart:async';
import 'dart:ui';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:go_router/go_router.dart'; // ✨ تمت الإضافة
import 'session_check_service.dart';
import 'dart:html' as html; // ✨ أضف هذا في أعلى الملف


class DrawingPoint {
  final Offset offset;
  final Paint paint;

  DrawingPoint({required this.offset, required this.paint});

  Map<String, dynamic> toMap() {
    return {
      'dx': offset.dx,
      'dy': offset.dy,
      'color': paint.color.value,
      'strokeWidth': paint.strokeWidth,
    };
  }

  factory DrawingPoint.fromMap(Map<String, dynamic> map) {
    return DrawingPoint(
      offset: Offset((map['dx'] as num).toDouble(), (map['dy'] as num).toDouble()),
      paint: Paint()
        ..color = Color(map['color'] as int)
        ..strokeWidth = (map['strokeWidth'] as num).toDouble()
        ..strokeCap = StrokeCap.round,
    );
  }
}

class LiveSessionScreen extends StatefulWidget {
  final String sessionId;
  final String studentName;
  final bool isTeacher;

  const LiveSessionScreen({
    super.key,
    required this.sessionId,
    required this.studentName,
    this.isTeacher = true,
  });

  @override
  State<LiveSessionScreen> createState() => _LiveSessionScreenState();
}

class _LiveSessionScreenState extends State<LiveSessionScreen> {
  final GlobalKey _boardKey = GlobalKey();

  List<DrawingPoint?> points = [];
  Color selectedColor = Colors.black;
  double strokeWidth = 4.0;
  bool isEraser = false;

  bool isChatOpen = false;
  final TextEditingController _chatController = TextEditingController();

  bool isMuted = false;
  bool isScreenSharing = false;
  int _screenShareUid = 0;

  Timer? _sessionTimer;
  int _remainingSeconds = 3600;
  bool _hasShown10MinWarning = false;
  bool _hasShown2MinWarning = false;
  int _extensionCount = 0;

  StreamSubscription<QuerySnapshot>? _strokesSubscription;
  StreamSubscription<DocumentSnapshot>? _sessionSubscription;
  List<DrawingPoint> _currentStroke = [];
  List<String> _strokeDocIds = [];

  @override
  void initState() {
    super.initState();
    _initAudioEngineWithRetry();
    _startSessionTimer();
    _listenToWhiteboard();
    _listenToSessionState();

    // ✨ إضافة مستمع لإغلاق النافذة فجأة
    html.window.onBeforeUnload.listen((event) {
      // تحديث حالة الجلسة إلى مكتملة إذا أُغلقت الصفحة بالخطأ
      FirebaseFirestore.instance.collection('sessions').doc(widget.sessionId).update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });
      SessionCheckService.leaveAndReleaseAudio();
    });
  }

  @override
  void dispose() {
    _stopSessionTimer();
    _chatController.dispose();
    _releaseAudioResources();
    _strokesSubscription?.cancel();
    _sessionSubscription?.cancel();
    super.dispose();
  }

  void _listenToWhiteboard() {
    _strokesSubscription = FirebaseFirestore.instance
        .collection('sessions')
        .doc(widget.sessionId)
        .collection('strokes')
        .orderBy('createdAt')
        .snapshots()
        .listen((snapshot) {
      final List<DrawingPoint?> newPoints = [];
      _strokeDocIds.clear();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final List<dynamic> rawPoints = data['points'] ?? [];
        for (var p in rawPoints) {
          newPoints.add(DrawingPoint.fromMap(p as Map<String, dynamic>));
        }
        newPoints.add(null);
        _strokeDocIds.add(doc.id);
      }

      if (mounted) {
        setState(() {
          points = newPoints;
          points.addAll(_currentStroke);
        });
      }
    });
  }

  void _listenToSessionState() {
    _sessionSubscription = FirebaseFirestore.instance
        .collection('sessions')
        .doc(widget.sessionId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            bool remoteSharing = data['isScreenSharing'] ?? false;
            isScreenSharing = remoteSharing;
            _screenShareUid = data['screenShareUid'] ?? 0;
          });
        }
      }
    });
  }

  void _startSessionTimer() {
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _remainingSeconds--;
        });

        if (_remainingSeconds == 600 && !_hasShown10MinWarning) {
          _hasShown10MinWarning = true;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⏳ تنبيه: تبقى 10 دقائق على نهاية الحصة.', style: TextStyle(fontFamily: 'Cairo')),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        }

        if (_remainingSeconds == 120 && !_hasShown2MinWarning) {
          _hasShown2MinWarning = true;
          if (!widget.isTeacher) {
            _showExtendDialog();
          }
        }

        if (_remainingSeconds <= 0) {
          timer.cancel();

          FirebaseFirestore.instance.collection('sessions').doc(widget.sessionId).update({
            'status': 'completed',
            'completedAt': FieldValue.serverTimestamp(),
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⌛ انتهت مدة الحصة. سيتم إغلاق الجلسة الآن.', style: TextStyle(fontFamily: 'Cairo')),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) Navigator.pop(context);
          });
        }
      }
    });
  }

  void _stopSessionTimer() {
    _sessionTimer?.cancel();
  }

  String _formatRemainingTime() {
    int hours = _remainingSeconds ~/ 3600;
    int minutes = (_remainingSeconds % 3600) ~/ 60;
    int seconds = _remainingSeconds % 60;

    String twoDigits(int n) => n.toString().padLeft(2, '0');

    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    } else {
      return '${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
  }

  void _showExtendDialog() {
    if (_extensionCount >= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('لقد وصلت للحد الأقصى من تمديد الحصص (3 ساعات).', style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('تمديد الحصة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        content: Text(
          'تبقى دقيقتان على نهاية الحصة. هل ترغب في تمديد الحصة لساعة إضافية؟ (سيتم خصم حصة من رصيدك)',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('لا، أكمل الحصة', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await SessionCheckService.extendSessionDuration(
                  sessionId: widget.sessionId,
                  studentId: FirebaseAuth.instance.currentUser!.uid,
                );

                setState(() {
                  _remainingSeconds = 3600;
                  _hasShown10MinWarning = false;
                  _hasShown2MinWarning = false;
                  _extensionCount++;
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('🎉 تم تمديد الحصة بنجاح! استمتع بوقتك الإضافي.', style: TextStyle(fontFamily: 'Cairo')),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('❌ ${e.toString().replaceFirst('Exception: ', '')}', style: TextStyle(fontFamily: 'Cairo')),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 5),
                  ),
                );
              }
            },
            child: Text('نعم، امتد الحصة', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _initAudioEngineWithRetry() async {
    try {
      await SessionCheckService.joinAudioChannel(sessionId: widget.sessionId);
      await SessionCheckService.checkMicrophone();
      if (mounted) {
        setState(() {
          isMuted = SessionCheckService.isMuted;
        });
      }
    } catch (e) {
      debugPrint("Audio init retry error: $e");
      Future.delayed(const Duration(seconds: 1), () async {
        try {
          await SessionCheckService.joinAudioChannel(sessionId: widget.sessionId);
          if (mounted) {
            setState(() {
              isMuted = SessionCheckService.isMuted;
            });
          }
        } catch (innerError) {
          debugPrint("Audio init second retry failed: $innerError");
        }
      });
    }
  }

  void _releaseAudioResources() {
    SessionCheckService.leaveAndReleaseAudio();
  }

  Future<void> _toggleMute() async {
    final mutedState = await SessionCheckService.toggleMuteAudio();
    if (mounted) {
      setState(() {
        isMuted = mutedState;
      });
    }
  }

  Future<void> _toggleScreenShare() async {
    if (!widget.isTeacher) return;
    try {
      bool newState = !isScreenSharing;
      bool success = await SessionCheckService.toggleScreenShare(
        newState,
        sessionId: widget.sessionId,
      );

      if (success) {
        final uid = FirebaseAuth.instance.currentUser!.uid.hashCode.abs() % 100000;
        setState(() {
          isScreenSharing = newState;
          _screenShareUid = uid;
        });

        await FirebaseFirestore.instance.collection('sessions').doc(widget.sessionId).update({
          'isScreenSharing': newState,
          'screenShareUid': newState ? uid : 0,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isScreenSharing ? 'تم بدء مشاركة الشاشة بنجاح' : 'تم إيقاف مشاركة الشاشة',
                style: TextStyle(fontFamily: 'Cairo'),
              ),
              backgroundColor: isScreenSharing ? Colors.green : Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Screen Share Error: $e");
      setState(() {
        isScreenSharing = false;
      });
    }
  }

  Future<Uint8List?> _generateBoardPdf() async {
    try {
      final boundary = _boardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 1.5);
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      if (byteData == null) return null;

      final pngBytes = byteData.buffer.asUint8List();
      final pdf = pw.Document();
      final imageProvider = pw.MemoryImage(pngBytes);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Image(imageProvider, fit: pw.BoxFit.contain),
            );
          },
        ),
      );

      return await pdf.save();
    } catch (e) {
      debugPrint("PDF Generation Error: $e");
      return null;
    }
  }

  void _sendMessage() async {
    final text = _chatController.text.trim();
    if (text.isNotEmpty) {
      _chatController.clear();
      try {
        await FirebaseFirestore.instance
            .collection('sessions')
            .doc(widget.sessionId)
            .collection('messages')
            .add({
          'sender': widget.isTeacher ? 'teacher' : 'student',
          'text': text,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint("Error sending message: $e");
      }
    }
  }

  void _selectColor(Color color) {
    setState(() {
      selectedColor = color;
      strokeWidth = 4.0;
      isEraser = false;
    });
  }

  void _enableEraser() {
    setState(() {
      selectedColor = Colors.white;
      strokeWidth = 25.0;
      isEraser = true;
    });
  }

  void _undo() {
    if (!widget.isTeacher || _strokeDocIds.isEmpty) return;
    final lastDocId = _strokeDocIds.removeLast();
    FirebaseFirestore.instance
        .collection('sessions')
        .doc(widget.sessionId)
        .collection('strokes')
        .doc(lastDocId)
        .delete();
  }

  void _clearBoard() async {
    if (!widget.isTeacher) return;
    final snapshot = await FirebaseFirestore.instance
        .collection('sessions')
        .doc(widget.sessionId)
        .collection('strokes')
        .get();

    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  void _showFloatingAnimationEffect(String type) {
    if (!widget.isTeacher) return;
    OverlayEntry? overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => _FloatingAnimationWidget(
        type: type,
        onFinished: () {
          overlayEntry?.remove();
        },
      ),
    );
    Overlay.of(context).insert(overlayEntry);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFF1E1E1E),
          appBar: AppBar(
            backgroundColor: const Color(0xFF2C2C2C),
            elevation: 0,
            leadingWidth: 110,
            leading: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                margin: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer, color: Colors.amber, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      _formatRemainingTime(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            title: Row(
              children: [
                Icon(
                  isMuted ? Icons.mic_off : Icons.graphic_eq,
                  color: isMuted ? Colors.redAccent : Colors.greenAccent,
                  size: 20,
                ),
                const SizedBox(width: 8),
                // ✨ تم تغيير Text إلى SelectableText لنسخ اسم الطالب
                SelectableText(
                  widget.isTeacher
                      ? 'جلسة مع الطالب: ${widget.studentName}'
                      : 'جلسة مع المعلم',
                  style: const TextStyle(fontSize: 15, fontFamily: 'Cairo'),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(
                  isChatOpen ? Icons.chat : Icons.chat_outlined,
                  color: isChatOpen ? Colors.amber : Colors.white,
                ),
                tooltip: 'الدردشة الحية',
                onPressed: () => setState(() => isChatOpen = !isChatOpen),
              ),
              if (widget.isTeacher) ...[
                IconButton(
                  icon: const Icon(Icons.undo, color: Colors.white),
                  tooltip: 'تراجع',
                  onPressed: _undo,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
                  tooltip: 'مسح الكل',
                  onPressed: _clearBoard,
                ),
              ],
              const SizedBox(width: 8),
            ],
          ),
          body: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    if (widget.isTeacher)
                      Container(
                        color: const Color(0xFF2A2A2A),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              const Text('الألوان: ', style: TextStyle(color: Colors.white70, fontFamily: 'Cairo')),
                              _colorBtn(Colors.black),
                              _colorBtn(Colors.red),
                              _colorBtn(Colors.blue),
                              _colorBtn(Colors.green),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: _enableEraser,
                                icon: Icon(Icons.cleaning_services, size: 18, color: isEraser ? Colors.amber : Colors.white70),
                                label: Text(
                                  'ممحاة',
                                  style: TextStyle(
                                    color: isEraser ? Colors.amber : Colors.white70,
                                    fontFamily: 'Cairo',
                                    fontWeight: isEraser ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: isEraser ? Colors.amber : Colors.white24),
                                ),
                              ),
                              const VerticalDivider(color: Colors.white24, thickness: 1, width: 20),
                              IconButton(
                                icon: const Icon(Icons.emoji_events, color: Colors.amber),
                                tooltip: 'كأس التميز',
                                onPressed: () => _showFloatingAnimationEffect('trophy'),
                              ),
                              IconButton(
                                icon: const Icon(Icons.celebration, color: Colors.pinkAccent),
                                tooltip: 'بالونات احتفال',
                                onPressed: () => _showFloatingAnimationEffect('balloons'),
                              ),
                              IconButton(
                                icon: const Icon(Icons.help_outline, color: Colors.lightBlueAccent),
                                tooltip: 'إشارة استفهام',
                                onPressed: () => _showFloatingAnimationEffect('question'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Expanded(
                      child: MouseRegion(
                        cursor: widget.isTeacher ? (isEraser ? SystemMouseCursors.cell : SystemMouseCursors.precise) : SystemMouseCursors.basic,
                        child: RepaintBoundary(
                          key: _boardKey,
                          child: Container(
                            color: Colors.white,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onPanStart: widget.isTeacher ? (details) {
                                // ✨ الحصول على حجم السبورة الحالي
                                final RenderBox? renderBox = _boardKey.currentContext?.findRenderObject() as RenderBox?;
                                if (renderBox == null) return;
                                final size = renderBox.size;

                                final point = DrawingPoint(
                                  offset: Offset(
                                    details.localPosition.dx / size.width, // تحويل لنسبة مئوية
                                    details.localPosition.dy / size.height, // تحويل لنسبة مئوية
                                  ),
                                  paint: Paint()
                                    ..color = isEraser ? Colors.white : selectedColor
                                    ..strokeWidth = strokeWidth
                                    ..strokeCap = StrokeCap.round,
                                );
                                setState(() {
                                  points.add(point);
                                  _currentStroke.add(point);
                                });
                              } : null,
                              onPanUpdate: widget.isTeacher ? (details) {
                                final RenderBox? renderBox = _boardKey.currentContext?.findRenderObject() as RenderBox?;
                                if (renderBox == null) return;
                                final size = renderBox.size;

                                final point = DrawingPoint(
                                  offset: Offset(
                                    details.localPosition.dx / size.width,
                                    details.localPosition.dy / size.height,
                                  ),
                                  paint: Paint()
                                    ..color = isEraser ? Colors.white : selectedColor
                                    ..strokeWidth = strokeWidth
                                    ..strokeCap = StrokeCap.round,
                                );
                                setState(() {
                                  points.add(point);
                                  _currentStroke.add(point);
                                });
                              } : null,
                              onPanEnd: widget.isTeacher ? (details) {
                                setState(() {
                                  points.add(null);
                                });
                                if (_currentStroke.isNotEmpty) {
                                  final strokeToSave = List<DrawingPoint>.from(_currentStroke);
                                  FirebaseFirestore.instance
                                      .collection('sessions')
                                      .doc(widget.sessionId)
                                      .collection('strokes')
                                      .add({
                                    'points': strokeToSave.map((p) => p.toMap()).toList(),
                                    'createdAt': FieldValue.serverTimestamp(),
                                  }).then((_) {
                                    _currentStroke.clear();
                                  }).catchError((e) {
                                    debugPrint("Error saving stroke: $e");
                                  });
                                }
                              } : null,
                              child: CustomPaint(
                                painter: SimpleBoardPainter(points: points),
                                size: Size.infinite,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (isScreenSharing)
                Container(
                  width: MediaQuery.of(context).size.width * 0.35,
                  margin: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    border: Border.all(color: Colors.amber, width: 3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          color: Colors.amber,
                          width: double.infinity,
                          child: Text(
                            widget.isTeacher ? 'أنت تشارك شاشتك الآن' : 'شاشة المعلم',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                          ),
                        ),
                        Expanded(
                          child: SessionCheckService.agoraEngine != null && _screenShareUid != 0
                              ? AgoraVideoView(
                            controller: VideoViewController.remote(
                              rtcEngine: SessionCheckService.agoraEngine!,
                              canvas: VideoCanvas(uid: _screenShareUid),
                              connection: RtcConnection(channelId: widget.sessionId),
                            ),
                          )
                              : const Center(child: CircularProgressIndicator(color: Colors.amber)),
                        ),
                      ],
                    ),
                  ),
                ),

              if (isChatOpen)
                Container(
                  width: 300,
                  color: const Color(0xFF252525),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        color: const Color(0xFF2C2C2C),
                        child: Row(
                          children: [
                            const Icon(Icons.chat, color: Colors.amber, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'الدردشة الحية',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                              onPressed: () => setState(() => isChatOpen = false),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('sessions')
                              .doc(widget.sessionId)
                              .collection('messages')
                              .orderBy('createdAt', descending: false)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const Center(child: CircularProgressIndicator(color: Colors.amber));
                            }

                            final docs = snapshot.data!.docs;

                            if (docs.isEmpty) {
                              return Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white10,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'بدأت الجلسة بنجاح.',
                                    style: TextStyle(color: Colors.white54, fontSize: 11, fontFamily: 'Cairo'),
                                  ),
                                ),
                              );
                            }

                            return ListView.builder(
                              padding: const EdgeInsets.all(10),
                              itemCount: docs.length,
                              itemBuilder: (context, index) {
                                final data = docs[index].data() as Map<String, dynamic>;
                                final isTeacherMsg = data['sender'] == 'teacher';

                                bool isMine = (widget.isTeacher && isTeacherMsg) || (!widget.isTeacher && !isTeacherMsg);

                                return Align(
                                  alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isMine ? Colors.amber.shade800 : const Color(0xFF3A3A3A),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    // ✨ تم تغيير Text إلى SelectableText لنسخ رسائل الدردشة
                                    child: SelectableText(
                                      data['text'] ?? '',
                                      style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'Cairo'),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        color: const Color(0xFF1E1E1E),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _chatController,
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'Cairo'),
                                decoration: InputDecoration(
                                  hintText: 'اكتب رسالة...',
                                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 12, fontFamily: 'Cairo'),
                                  filled: true,
                                  fillColor: const Color(0xFF2C2C2C),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                onSubmitted: (_) => _sendMessage(),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.send, color: Colors.amber),
                              onPressed: _sendMessage,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          bottomNavigationBar: Container(
            height: 65,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            color: const Color(0xFF2C2C2C),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FloatingActionButton.small(
                  heroTag: 'mic_btn',
                  backgroundColor: isMuted ? Colors.redAccent : Colors.green,
                  onPressed: _toggleMute,
                  child: Icon(isMuted ? Icons.mic_off : Icons.mic, color: Colors.white),
                ),
                const SizedBox(width: 16),
                if (widget.isTeacher)
                  IconButton(
                    icon: Icon(
                      isScreenSharing ? Icons.stop_screen_share : Icons.screen_share,
                      color: isScreenSharing ? Colors.red : Colors.white,
                    ),
                    onPressed: _toggleScreenShare,
                    tooltip: isScreenSharing ? 'إيقاف مشاركة الشاشة' : 'مشاركة الشاشة',
                  ),
                if (widget.isTeacher) const SizedBox(width: 24),

                widget.isTeacher
                    ? ElevatedButton.icon(
                  onPressed: () {
                    _stopSessionTimer();
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (ctx) => _EndSessionDialog(
                        sessionId: widget.sessionId,
                        elapsedSeconds: 3600 - _remainingSeconds,
                        formattedDuration: _formatRemainingTime(),
                        generatePdfCallback: _generateBoardPdf,
                      ),
                    );
                  },
                  icon: const Icon(Icons.call_end, size: 18, color: Colors.white),
                  label: const Text('إنهاء الجلسة', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                )
                    : ElevatedButton.icon(
                  onPressed: () async {
                    _stopSessionTimer();

                    await FirebaseFirestore.instance.collection('sessions').doc(widget.sessionId).update({
                      'status': 'completed',
                      'completedAt': FieldValue.serverTimestamp(),
                    });

                    if (mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.logout, size: 18, color: Colors.white),
                  label: const Text('مغادرة الجلسة', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _colorBtn(Color color) {
    bool isSelected = !isEraser && selectedColor == color;
    return GestureDetector(
      onTap: () => _selectColor(color),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: isSelected ? Colors.amber : Colors.white24, width: isSelected ? 3 : 1),
        ),
      ),
    );
  }
}

class _FloatingAnimationWidget extends StatefulWidget {
  final String type;
  final VoidCallback onFinished;

  const _FloatingAnimationWidget({required this.type, required this.onFinished});

  @override
  State<_FloatingAnimationWidget> createState() => _FloatingAnimationWidgetState();
}

class _FloatingAnimationWidgetState extends State<_FloatingAnimationWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final math.Random _random = math.Random();
  late List<_ParticleConfig> particles;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..forward();

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onFinished();
      }
    });

    int count = (widget.type == 'balloons' || widget.type == 'fireworks') ? 20 : 1;
    particles = List.generate(count, (index) {
      double determinedSize;
      if (widget.type == 'trophy' || widget.type == 'heart' || widget.type == 'question') {
        determinedSize = 90.0;
      } else if (widget.type == 'balloons') {
        determinedSize = _random.nextDouble() * 40 + 30;
      } else {
        determinedSize = _random.nextDouble() * 6 + 4;
      }

      return _ParticleConfig(
        startX: _random.nextDouble(),
        size: determinedSize,
        color: _getRandomColor(),
        horizontalWiggle: _random.nextDouble() * 100 - 50,
        angle: _random.nextDouble() * math.pi * 2,
        speed: _random.nextDouble() * 80 + 40,
      );
    });
  }

  Color _getRandomColor() {
    List<Color> colors = [Colors.red, Colors.pink, Colors.amber, Colors.blue, Colors.green, Colors.purple, Colors.orange, Colors.cyan, Colors.yellow];
    return colors[_random.nextInt(colors.length)];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          double progress = _controller.value;
          double screenHeight = MediaQuery.of(context).size.height;
          double screenWidth = MediaQuery.of(context).size.width;

          if (widget.type == 'fireworks') {
            return CustomPaint(
              size: Size(screenWidth, screenHeight),
              painter: _FireworksPainter(particles: particles, progress: progress),
            );
          }

          return Stack(
            children: particles.map((particle) {
              bool isBalloons = widget.type == 'balloons';
              double currentY = isBalloons
                  ? screenHeight * (1.2 - progress * 1.4)
                  : screenHeight / 2 - 50;

              double currentX = (screenWidth * particle.startX) + (isBalloons ? math.sin(progress * math.pi * 4) * particle.horizontalWiggle : 0);

              IconData iconData;
              switch (widget.type) {
                case 'trophy':
                  iconData = Icons.emoji_events;
                  break;
                case 'balloons':
                  iconData = Icons.celebration;
                  break;
                case 'question':
                  iconData = Icons.help_outline;
                  break;
                case 'heart':
                  iconData = Icons.favorite;
                  break;
                default:
                  iconData = Icons.star;
              }

              return Positioned(
                left: currentX,
                top: currentY,
                child: Opacity(
                  opacity: isBalloons ? (1.0 - progress * 0.2) : (progress < 0.8 ? 1.0 : (1.0 - progress) * 5),
                  child: Transform.scale(
                    scale: isBalloons ? 1.0 : math.min(progress * 2, 1.2),
                    child: Icon(
                      iconData,
                      size: particle.size,
                      color: particle.color,
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _FireworksPainter extends CustomPainter {
  final List<_ParticleConfig> particles;
  final double progress;

  _FireworksPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (var p in particles) {
      double startX = size.width * p.startX;

      if (progress < 0.4) {
        double subProgress = progress / 0.4;
        double currentY = size.height * (1.1 - subProgress * 0.6);

        Paint rocketPaint = Paint()
          ..color = p.color
          ..strokeWidth = 3.0
          ..strokeCap = StrokeCap.round;

        canvas.drawLine(
          Offset(startX, currentY + 20),
          Offset(startX, currentY),
          rocketPaint,
        );
      } else {
        double explosionProgress = (progress - 0.4) / 0.6;
        double centerX = startX;
        double centerY = size.height * 0.5;

        double distance = explosionProgress * p.speed * 2.5;
        double sparkX = centerX + math.cos(p.angle) * distance;
        double sparkY = centerY + math.sin(p.angle) * distance + (explosionProgress * explosionProgress * 50);

        Paint sparkPaint = Paint()
          ..color = p.color.withOpacity((1.0 - explosionProgress).clamp(0.0, 1.0))
          ..strokeWidth = p.size
          ..strokeCap = StrokeCap.round;

        canvas.drawCircle(Offset(sparkX, sparkY), p.size, sparkPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FireworksPainter oldDelegate) => true;
}

class _ParticleConfig {
  final double startX;
  final double size;
  final Color color;
  final double horizontalWiggle;
  final double angle;
  final double speed;

  _ParticleConfig({
    required this.startX,
    required this.size,
    required this.color,
    required this.horizontalWiggle,
    this.angle = 0.0,
    this.speed = 0.0,
  });
}

class _EndSessionDialog extends StatefulWidget {
  final String sessionId;
  final int elapsedSeconds;
  final String formattedDuration;
  final Future<Uint8List?> Function() generatePdfCallback;

  const _EndSessionDialog({
    required this.sessionId,
    required this.elapsedSeconds,
    required this.formattedDuration,
    required this.generatePdfCallback,
  });

  @override
  State<_EndSessionDialog> createState() => _EndSessionDialogState();
}

class _EndSessionDialogState extends State<_EndSessionDialog> {
  bool isExporting = false;
  bool isCancelled = false;
  double progressValue = 0.0;
  String statusMessage = 'جاري التحضير...';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF2C2C2C),
      title: const Text('إنهاء الجلسة', style: TextStyle(color: Colors.white, fontFamily: 'Cairo')),
      content: isExporting
          ? Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(statusMessage, style: const TextStyle(color: Colors.white70, fontFamily: 'Cairo', fontSize: 13)),
          const SizedBox(height: 16),
          LinearProgressIndicator(value: progressValue, color: Colors.amber, backgroundColor: Colors.white24),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text('${(progressValue * 100).toInt()}%', style: const TextStyle(color: Colors.white54, fontSize: 11, fontFamily: 'Cairo')),
          ),
        ],
      )
          : Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('هل أنت متأكد من إغلاق الجلسة الحية وحفظ ملخص السبورة؟', style: TextStyle(color: Colors.white70, fontFamily: 'Cairo')),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time, color: Colors.amber, size: 16),
                const SizedBox(width: 6),
                Text(
                  'وقت الجلسة الإجمالي: ${widget.formattedDuration}',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'Cairo'),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: isExporting
          ? [
        TextButton.icon(
          onPressed: () {
            setState(() => isCancelled = true);
            Navigator.pop(context);
          },
          icon: const Icon(Icons.cancel, color: Colors.redAccent, size: 18),
          label: const Text('إلغاء العملية', style: TextStyle(color: Colors.redAccent, fontFamily: 'Cairo')),
        ),
      ]
          : [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء', style: TextStyle(color: Colors.white54, fontFamily: 'Cairo')),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () async {
            setState(() {
              isExporting = true;
              isCancelled = false;
              progressValue = 0.05;
              statusMessage = 'جاري بدء عملية الإغلاق...';
            });

            await Future.delayed(const Duration(milliseconds: 100));
            if (isCancelled || !mounted) return;

            setState(() {
              progressValue = 0.15;
              statusMessage = 'الاستعداد لالتقاط الشاشة...';
            });

            try {
              Uint8List? pdfBytes = await widget.generatePdfCallback();
              if (isCancelled || !mounted) return;

              setState(() {
                progressValue = 0.50;
                statusMessage = 'تم توليد ملف الـ PDF بنجاح...';
              });

              await SessionCheckService.completeSession(
                sessionId: widget.sessionId,
                pdfBytes: pdfBytes,
              );

              if (isCancelled || !mounted) return;

              setState(() {
                progressValue = 1.0;
                statusMessage = 'تم الانتهاء بنجاح!';
              });

              await Future.delayed(const Duration(milliseconds: 200));
              if (!mounted) return;

              Navigator.pop(context);
              Navigator.pop(context);
            } catch (e) {
              debugPrint("Error completing session: $e");
              if (mounted && !isCancelled) Navigator.pop(context);
            }
          },
          child: const Text('إنهاء وحفظ', style: TextStyle(color: Colors.white, fontFamily: 'Cairo')),
        ),
      ],
    );
  }
}

class SimpleBoardPainter extends CustomPainter {
  final List<DrawingPoint?> points;

  SimpleBoardPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        // ✨ ضرب النسبة المئوية بحجم الشاشة الحالي للمستخدم
        final Offset p1 = Offset(points[i]!.offset.dx * size.width, points[i]!.offset.dy * size.height);
        final Offset p2 = Offset(points[i + 1]!.offset.dx * size.width, points[i + 1]!.offset.dy * size.height);

        canvas.drawLine(p1, p2, points[i]!.paint);
      } else if (points[i] != null && points[i + 1] == null) {
        final Offset p1 = Offset(points[i]!.offset.dx * size.width, points[i]!.offset.dy * size.height);
        canvas.drawPoints(PointMode.points, [p1], points[i]!.paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}