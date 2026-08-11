import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:labeeb_wep/auth_flow_screen.dart';
import 'package:labeeb_wep/core/theme.dart';

class MainGateScreen extends StatefulWidget {
  const MainGateScreen({super.key});

  @override
  State<MainGateScreen> createState() => _MainGateScreenState();
}

class _MainGateScreenState extends State<MainGateScreen> {
  late Timer _imageTimer;
  int _currentImageIndex = 0;

  // 📸 قائمة الصور المتغيرة
  final List<String> _showcaseImages = [
    'images/student_bag1.png',
    'images/student_bag2.png',
    'images/teacher_explaining.png',
    'images/teacher_1.png',
  ];

  @override
  void initState() {
    super.initState();
    // ⏳ تشغيل التايمر بشكل قياسي وصحيح لمنع أي تعليق في الواجهة
    _imageTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        setState(() {
          _currentImageIndex = (_currentImageIndex + 1) % _showcaseImages.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _imageTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 950;

    return Scaffold(
      body: SelectionArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: LabeebTheme.beigeBackground,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // 1. الجزء الرئيسي العلوي (الترحيب + معرض الصور المتغيرة)
                Container(
                  constraints: BoxConstraints(minHeight: size.height),
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
                  alignment: Alignment.center,
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 1250),
                      child: isDesktop
                          ? Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(flex: 5, child: _buildAuthSection()),
                          const SizedBox(width: 60),
                          Expanded(flex: 5, child: _buildVisualShowcaseSection(size.height * 0.65)),
                        ],
                      )
                          : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildAuthSection(),
                          const SizedBox(height: 50),
                          _buildVisualShowcaseSection(340),
                        ],
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1, color: Colors.black12),

                // 2. قسم التعريف والمزايا المناهج السعودية كاملاً
                _buildAboutSection(),

                // 3. قسم البطاقات التقنية
                _buildFeaturesSection(),

                // 4. الجزء السفلي (Footer)
                _buildFooterSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // بناء قسم الترحيب العلوي
  Widget _buildAuthSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: LabeebTheme.oliveGreen.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.auto_stories_rounded, size: 60, color: LabeebTheme.accentOrange),
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'لَــبِــيــبْ',
                  style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w900,
                    color: LabeebTheme.accentOrange,
                    letterSpacing: 1.5,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'التفاعل الذكي الذي يختصر المسافات الأكاديمية',
                  style: TextStyle(
                    fontSize: 16,
                    color: LabeebTheme.textDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 48),
        const Text(
          'أهلاً بك في بيئتك التعليمية الفورية المبتكرة',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: LabeebTheme.textDark),
        ),
        const SizedBox(height: 14),
        const Text(
          'منصة "لبيب" صُممت خصيصاً لتوفر لك فصولاً دراسية حية ومباشرة تعتمد على الاتصال الفوري عالي الجودة والآمن تماماً. تفضل باختيار هويتك للدخول فوراً:',
          style: TextStyle(fontSize: 17, color: Colors.black87, height: 1.8),
        ),
        const SizedBox(height: 40),

        _buildRoleSelectionCard(
          icon: Icons.school_rounded,
          title: 'أنا طالب طموح',
          description: 'تواصل فوراً مع معلمين معتمدين ومستعدين لمساعدتك خطوة بخطوة وبأمان مالي كامل وحصص مسجلة بالكامل لمراجعتها لاحقاً.',
          buttonText: 'ابدأ فصولك فوراً كـ طالب',
          onTap: () {
            // ✨ تم التعديل لاستخدام go_router لدعم أزرار الرجوع والتحديث
            context.go('/auth?role=student');
          },
        ),
        const SizedBox(height: 20),

        _buildRoleSelectionCard(
          icon: Icons.co_present_rounded,
          title: 'أنا معلم لبيب',
          description: 'انضم لكتيبة الطواقم الأكاديمية المتخصصة في لبيب، وثّق أوراقك واعتماداتك، وابدأ بتقديم شروحاتك وتحقيق دخل مالي ممتاز وسلس.',
          buttonText: 'الدخول لبوابة المعلمين والتسجيل',
          onTap: () {
            // ✨ تم التعديل لاستخدام go_router لدعم أزرار الرجوع والتحديث
            context.go('/auth?role=teacher');
          },
        ),
      ],
    );
  }

  Widget _buildRoleSelectionCard({
    required IconData icon,
    required String title,
    required String description,
    required String buttonText,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28.0),
      decoration: BoxDecoration(
        color: LabeebTheme.beigeCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: LabeebTheme.oliveGreen.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 24,
            offset: const Offset(0, 12),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: LabeebTheme.oliveGreen.withOpacity(0.1),
            child: Icon(icon, size: 34, color: LabeebTheme.oliveGreen),
          ),
          const SizedBox(width: 22),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: LabeebTheme.accentOrange.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: LabeebTheme.accentOrange,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  description,
                  style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                      height: 1.7
                  ),
                ),
                const SizedBox(height: 22),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LabeebTheme.oliveGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: onTap,
                  child: Text(
                      buttonText,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 📸 قسم معرض الصور المتحرك
  Widget _buildVisualShowcaseSection(double height) {
    final double adjustedHeight = height * 1.15;
    final double adjustedWidth = height * 1.35;

    return Container(
      height: adjustedHeight,
      width: double.infinity,
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipPath(
            clipper: BlobClipper(),
            child: Container(
              width: adjustedWidth,
              height: adjustedHeight,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    LabeebTheme.oliveGreen.withOpacity(0.15),
                    LabeebTheme.beigeCard,
                  ],
                ),
              ),
            ),
          ),
          ClipPath(
            clipper: BlobClipper(),
            child: Container(
              width: adjustedWidth * 0.96,
              height: adjustedHeight * 0.96,
              color: LabeebTheme.beigeCard,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  key: ValueKey<int>(_currentImageIndex),
                  child: Image.asset(
                    _showcaseImages[_currentImageIndex],
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🎓 قسم المزايا والنصوص التسويقية المحدثة بمحاذاة أفقية مستقيمة تماماً بعد النقطتين
  Widget _buildAboutSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: const [
                    Icon(Icons.auto_awesome_rounded, size: 55, color: LabeebTheme.accentOrange),
                    SizedBox(height: 20),
                    Text(
                      '🎓 مستقبل أبنائك الدراسي يبدأ بخطوة..',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: LabeebTheme.textDark),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'مع أفضل المدرسين الخصوصيين في السعودية!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: LabeebTheme.accentOrange),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              const Text(
                'هل تبحث عن تعليم تفاعلي مخصص يناسب قدرات طفلك ويوفر وقتك ومجهودك؟ نحن هنا لنقدم لك الحل التعليمي المتكامل والآمن من منزلك.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 19, color: Colors.black87, height: 1.8, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 50),

              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: LabeebTheme.accentOrange,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    '✨ لماذا تختارنا لتعليم أبنائك？',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 45),

              // 🌟 1. نخبة من أفضل المدرسين
              _buildModernFeatureRow(
                icon: Icons.star_rounded,
                titleWidget: RichText(
                  text:  TextSpan(
                    style: TextStyle(fontFamily: 'Cairo', color: Colors.black87, height: 1.7),
                    children: [
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          margin: EdgeInsets.only(left: 6),
                          decoration: BoxDecoration(
                            color: Color(0xFFEBDDC3),
                            borderRadius: BorderRadius.all(Radius.circular(6)),
                          ),
                          child: Text('نخبة من أفضل المدرسين:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: LabeebTheme.oliveGreen, fontFamily: 'Cairo')),
                        ),
                      ),
                      TextSpan(text: 'معلمون متميزون ومتخصصون ومؤهلون بالكامل لشرح ', style: TextStyle(fontSize: 17)),
                      TextSpan(text: 'المناهج السعودية ', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: LabeebTheme.accentOrange)),
                      TextSpan(text: 'لضمان أعلى درجات التفوق الأكاديمي والاستيعاب الفوري لطفلك.', style: TextStyle(fontSize: 17)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // 🌟 2. التعليم بأسلوب التلعيب والمرح
              _buildModernFeatureRow(
                icon: Icons.emoji_events_rounded,
                titleWidget: RichText(
                  text:  TextSpan(
                    style: TextStyle(fontFamily: 'Cairo', color: Colors.black87, height: 1.7),
                    children: [
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          margin: EdgeInsets.only(left: 6),
                          decoration: BoxDecoration(
                            color: Color(0xFFEBDDC3),
                            borderRadius: BorderRadius.all(Radius.circular(6)),
                          ),
                          child: Text('التعليم بأسلوب التلعيب والمرح:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: LabeebTheme.oliveGreen, fontFamily: 'Cairo')),
                        ),
                      ),
                      TextSpan(text: 'نحول المواد الجامدة إلى ', style: TextStyle(fontSize: 17)),
                      TextSpan(text: 'أنشطة تفاعلية مشوقة وألعاب تعليمية ذكية ', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: LabeebTheme.accentOrange)),
                      TextSpan(text: 'تنمي مهارات التفكير لدى طفلك وتجعل الدراسة رحلة مليئة بالشغف والمرح اليومي.', style: TextStyle(fontSize: 17)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // 🌟 3. خطة تعليمية مخصصة
              _buildModernFeatureRow(
                icon: Icons.track_changes_rounded,
                titleWidget: RichText(
                  text:  TextSpan(
                    style: TextStyle(fontFamily: 'Cairo', color: Colors.black87, height: 1.7),
                    children: [
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          margin: EdgeInsets.only(left: 6),
                          decoration: BoxDecoration(
                            color: Color(0xFFEBDDC3),
                            borderRadius: BorderRadius.all(Radius.circular(6)),
                          ),
                          child: Text('خطة تعليمية مخصصة:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: LabeebTheme.oliveGreen, fontFamily: 'Cairo')),
                        ),
                      ),
                      TextSpan(text: 'نؤمن بوجود فروق فردية، لذا نقوم بتصميم ', style: TextStyle(fontSize: 17)),
                      TextSpan(text: 'مسار دراسي خاص ومستقل ', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: LabeebTheme.accentOrange)),
                      TextSpan(text: 'يتناسب تماماً مع سرعة فهم الطالب لتعزيز نقاط قوته ومعالجة الصعوبات الأكاديمية لديه.', style: TextStyle(fontSize: 17)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // 🌟 4. حصص فردية عن بعد (1-1)
              _buildModernFeatureRow(
                icon: Icons.screen_share_rounded,
                titleWidget: RichText(
                  text:  TextSpan(
                    style: TextStyle(fontFamily: 'Cairo', color: Colors.black87, height: 1.7),
                    children: [
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          margin: EdgeInsets.only(left: 6),
                          decoration: BoxDecoration(
                            color: Color(0xFFEBDDC3),
                            borderRadius: BorderRadius.all(Radius.circular(6)),
                          ),
                          child: Text('حصص فردية عن بعد (1-1):', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: LabeebTheme.oliveGreen, fontFamily: 'Cairo')),
                        ),
                      ),
                      TextSpan(text: 'انتباه كامل وتركيز مباشر بنسبة ', style: TextStyle(fontSize: 17)),
                      TextSpan(text: '100% ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: LabeebTheme.accentOrange)),
                      TextSpan(text: 'بين المعلم والطالب دون أي مشتتات لضمان بيئة دراسية تفاعلية مريحة وآمنة للغاية من المنزل.', style: TextStyle(fontSize: 17)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // 🌟 5. لجميع المراحل الدراسية
              _buildModernFeatureRow(
                icon: Icons.school_rounded,
                titleWidget: RichText(
                  text:  TextSpan(
                    style: TextStyle(fontFamily: 'Cairo', color: Colors.black87, height: 1.7),
                    children: [
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          margin: EdgeInsets.only(left: 6),
                          decoration: BoxDecoration(
                            color: Color(0xFFEBDDC3),
                            borderRadius: BorderRadius.all(Radius.circular(6)),
                          ),
                          child: Text('لجميع المراحل الدراسية:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: LabeebTheme.oliveGreen, fontFamily: 'Cairo')),
                        ),
                      ),
                      TextSpan(text: 'نواكب مسيرة ابنك الأكاديمية بدءاً من مراحل التأسيس المبكر و', style: TextStyle(fontSize: 17)),
                      TextSpan(text: 'روضة الأطفال', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: LabeebTheme.accentOrange)),
                      TextSpan(text: '، مروراً بالمراحل الابتدائية والمتوسطة، وحتى مرحلة الثانوية العامة والجامعة.', style: TextStyle(fontSize: 17)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // 🌟 6. باقات شهرية مرنة
              _buildModernFeatureRow(
                icon: Icons.payments_rounded,
                titleWidget: RichText(
                  text:  TextSpan(
                    style: TextStyle(fontFamily: 'Cairo', color: Colors.black87, height: 1.7),
                    children: [
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          margin: EdgeInsets.only(left: 6),
                          decoration: BoxDecoration(
                            color: Color(0xFFEBDDC3),
                            borderRadius: BorderRadius.all(Radius.circular(6)),
                          ),
                          child: Text('باقات شهرية مرنة:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: LabeebTheme.oliveGreen, fontFamily: 'Cairo')),
                        ),
                      ),
                      TextSpan(text: 'نوفر باقات وخطط أسعار متنوعة ومنافسة تناسب احتياجاتك الاقتصادية مع ', style: TextStyle(fontSize: 17)),
                      TextSpan(text: 'مرونة تحكم كاملة ', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: LabeebTheme.accentOrange)),
                      TextSpan(text: 'في تعديل، إلغاء، أو تجديد الاشتراك بأي وقت وسهولة مطلقة.', style: TextStyle(fontSize: 17)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // 🌟 7. منصة معتمدة ورسمية
              _buildModernFeatureRow(
                icon: Icons.gavel_rounded,
                titleWidget: RichText(
                  text:  TextSpan(
                    style: TextStyle(fontFamily: 'Cairo', color: Colors.black87, height: 1.7),
                    children: [
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          margin: EdgeInsets.only(left: 6),
                          decoration: BoxDecoration(
                            color: Color(0xFFEBDDC3),
                            borderRadius: BorderRadius.all(Radius.circular(6)),
                          ),
                          child: Text('منصة معتمدة ورسمية:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: LabeebTheme.oliveGreen, fontFamily: 'Cairo')),
                        ),
                      ),
                      TextSpan(text: 'منصة مرخصة ومصرحة بالكامل من قِبل ', style: TextStyle(fontSize: 17)),
                      TextSpan(text: 'المركز الوطني للتعليم الإلكتروني ', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: LabeebTheme.accentOrange)),
                      TextSpan(text: 'مما يضمن لك نظاماً تعليمياً آمناً وموثوقاً وخاضعاً لأعلى معايير الجودة الدولية.', style: TextStyle(fontSize: 17)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 48),

              // 🎁 كرت العرض الخاص
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32.0),
                decoration: BoxDecoration(
                  color: LabeebTheme.oliveGreen.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: LabeebTheme.oliveGreen.withOpacity(0.3), width: 1.5),
                ),
                child: Column(
                  children: const [
                    Text(
                      '🎁 عرض خاص ولفترة محدودة!',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: LabeebTheme.accentOrange),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'ابدأ اليوم واحصل على استشارة تعليمية مجانية لتحديد مستوى طالبك ووضع الخطة الأنسب له.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, color: LabeebTheme.textDark, fontWeight: FontWeight.bold, height: 1.7),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernFeatureRow({required IconData icon, required Widget titleWidget}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: LabeebTheme.oliveGreen.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: LabeebTheme.oliveGreen, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(child: titleWidget),
      ],
    );
  }

  // 🛠️ البطاقات التقنية
  Widget _buildFeaturesSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: LabeebTheme.accentOrange,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  '💡 لماذا تختار منصة لبيب للتعلم الذكي؟',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'باقة متكاملة من التقنيات الهندسية لضمان تجربة أكاديمية ممتازة للطلاب والمعلمين',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, fontSize: 17),
              ),
              const SizedBox(height: 50),
              Wrap(
                spacing: 24,
                runSpacing: 24,
                alignment: WrapAlignment.center,
                children: [
                  _buildFeatureCard(
                    icon: Icons.mic_external_on_rounded,
                    title: 'حصص صوتية فورية مسجلة',
                    description: 'اتصال فوري بصوت نقي ومباشر مع تسجيل الحصة تلقائياً على السيرفر ليعود الطالب لها في أي وقت.',
                  ),
                  _buildFeatureCard(
                    icon: Icons.shield_rounded,
                    title: 'محفظة مالية رقمية آمنة',
                    description: 'نظام دفع آمن للغاية؛ يُحفظ رصيد الطالب ولا يتم تحرير الأرباح للمعلم إلا بعد اكتمال الحصة بنجاح.',
                  ),
                  _buildFeatureCard(
                    icon: Icons.verified_user_rounded,
                    title: 'معلمون تحت الرقابة والمراجعة',
                    description: 'نظام تحقق صارم، حيث نقوم بفحص السيرة الذاتية والأوراق الثبوتية لكل معلم لضمان جودة الطرح التعليمي.',
                  ),
                  _buildFeatureCard(
                    icon: Icons.sports_esports_rounded,
                    title: 'تحديات ونقاط ومكافآت',
                    description: 'نظام ذكي يدمج الألعاب بالتعليم؛ يحصل الطالب على أوسمة ونقاط عند إنجاز المهام، مما يجعل الدراسة رحلة مشوقة مليئة بالإنجاز المتواصل.',
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard({required IconData icon, required String title, required String description}) {
    return Container(
      width: 270,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: LabeebTheme.beigeCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: LabeebTheme.oliveGreen.withOpacity(0.12), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: LabeebTheme.oliveGreen.withOpacity(0.1),
            child: Icon(icon, color: LabeebTheme.oliveGreen, size: 30),
          ),
          const SizedBox(height: 24),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: LabeebTheme.textDark)),
          const SizedBox(height: 12),
          Text(description, style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.7)),
        ],
      ),
    );
  }

  // 🛠️ الـ Footer
  Widget _buildFooterSection() {
    return Theme(
      data: ThemeData(
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: LabeebTheme.beigeBackground),
          bodyMedium: TextStyle(color: LabeebTheme.beigeBackground),
        ),
      ),
      child: Container(
        color: LabeebTheme.accentOrange,
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                              'لَــبِــيــبْ',
                              style: TextStyle(
                                color: LabeebTheme.beigeBackground,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                              )
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'نظام تفاعلي متقدم يهدف لتنظيم ورفع جودة التعليم الخاص الرقمي عبر دمج تقنيات الاتصال الصوتي والتحقق والتوثيق التام.',
                            style: TextStyle(color: LabeebTheme.beigeBackground, fontSize: 15, height: 1.7),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 40),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                              'هـدف المنصـة الأساسـي',
                              style: TextStyle(
                                color: LabeebTheme.beigeBackground,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              )
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'تمكين الطلاب من استيعاب وفهم المواد الصعبة في بيئة آمنة تضمن حقوق الطرفين وتوفر عناء الحصص التقليدية ومتاعب التنقل.',
                            style: TextStyle(color: LabeebTheme.beigeBackground, fontSize: 15, height: 1.7),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                Divider(color: LabeebTheme.beigeBackground.withOpacity(0.3), height: 1),
                const SizedBox(height: 30),
                Text(
                  '© ٢٠٢٦ جميع الحقوق محفوظة لمنصة لبيب التعليمية. تم التطوير برعاية وإشراف باسل أبو هدة.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: LabeebTheme.beigeBackground,
                    fontSize: 14,
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BlobClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.moveTo(size.width * 0.15, size.height * 0.10);
    path.cubicTo(
      size.width * 0.45, size.height * 0.02,
      size.width * 0.85, size.height * 0.05,
      size.width * 0.95, size.height * 0.25,
    );
    path.cubicTo(
      size.width * 1.02, size.height * 0.50,
      size.width * 0.92, size.height * 0.88,
      size.width * 0.65, size.height * 0.95,
    );
    path.cubicTo(
      size.width * 0.35, size.height * 0.98,
      size.width * 0.05, size.height * 0.85,
      size.width * 0.02, size.height * 0.50,
    );
    path.cubicTo(
      size.width * -0.02, size.height * 0.25,
      size.width * 0.05, size.height * 0.15,
      size.width * 0.15, size.height * 0.10,
    );
    path.close();
    return path;
  }
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}