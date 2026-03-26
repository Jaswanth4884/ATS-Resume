import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'resume_model.dart';
import 'loginscreen.dart';
import 'services/auth_service.dart';

void main() => runApp(const ProResumeApp());

class ProResumeApp extends StatelessWidget {
  const ProResumeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Resume Builder',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        primaryColor: const Color(0xFF6B8E7F),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      locale: const Locale('en'),
      localizationsDelegates: const [
        CountryLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: const LoginScreen(),
    );
  }
}

class ResumeHome extends StatefulWidget {
  const ResumeHome({super.key});

  @override
  State<ResumeHome> createState() => _ResumeHomeState();
}

class _ResumeHomeState extends State<ResumeHome> {
  ResumeData data = ResumeData();
  final Map<String, TextEditingController> _fieldControllers = {};
  static const String _resumeDraftKeyPrefix = 'resume_draft_v1_';
  Timer? _draftAutoSaveTimer;

  // Section ordering
  List<String> sectionOrder = [
    'Skills',
    'Experience',
    'Projects',
    'Education',
    'Achievements',
    'Strengths',
  ];

  // Formatting options
  double nameTextSize = 20.0;
  double sectionHeaderSize = 14.0;
  double bodyTextSize = 11.0;
  Color nameTextColor = const Color(0xFF2D3748);
  Color sectionHeaderColor = const Color(0xFF2D3748);
  Color bodyTextColor = const Color(0xFF2D3748);
  Color contactLinkColor = Colors.blue;

  // Custom section names
  String skillsSectionName = "SKILLS";
  String experienceSectionName = "Experience";
  String projectsSectionName = "PERSONAL PROJECTS";
  String educationSectionName = "EDUCATION";
  String achievementsSectionName = "Achievements";
  String strengthsSectionName = "Strengths";

  // Skill subcategory headings (users can rename these)
  String skillsLanguagesLabel = "Languages:";
  String skillsFrameworksLabel = "Frameworks and Database:";
  String skillsToolsLabel = "Tools and Technologies:";
  String skillsOthersLabel = "Others:";
  List<Map<String, String>> extraSkillRows = [];
  String _selectedPhoneCountryIso = 'IN';
  String _selectedPhoneCountryName = 'India';
  String _selectedPhoneCountryCode = '+91';

  // Custom sections (user-added)
  List<Map<String, String>> customSections = [];

  // Add section form state
  bool _showAddSectionForm = false;
  String? _sectionToAddFromOrder;
  final TextEditingController _newSectionNameController =
      TextEditingController();
  final TextEditingController _newSectionContentController =
      TextEditingController();

  // Collapsible state for all sections
  bool isPersonalExpanded = true;
  bool isSkillsExpanded = true;
  bool isExperienceExpanded = true;
  bool isProjectsExpanded = true;
  bool isEducationExpanded = true;
  bool isAchievementsExpanded = true;
  bool isStrengthsExpanded = true;

  // ATS Score tracking
  int _atsScore = 0;
  List<String> _atsRecommendations = [];
  String _atsScoreText = "Not analyzed";

  // Mobile view state
  bool _showPreviewOnMobile = false;

  @override
  void initState() {
    super.initState();
    _syncPhoneCountryFromPhone();
    _validateSession();
    _loadDraft();
    _startDraftAutoSave();
  }

  Future<void> _validateSession() async {
    // Check if user has a valid session/token
    final isValid = await AuthService.validateSession();
    
    if (!isValid && mounted) {
      // Session invalid or token expired, redirect to login
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  void dispose() {
    _draftAutoSaveTimer?.cancel();
    _saveDraft();
    for (final controller in _fieldControllers.values) {
      controller.dispose();
    }
    _newSectionNameController.dispose();
    _newSectionContentController.dispose();
    super.dispose();
  }

  TextEditingController _getFieldController(String key, String value) {
    final existing = _fieldControllers[key];
    if (existing != null) {
      if (existing.text.isEmpty && value.isNotEmpty) {
        existing.text = value;
      }
      return existing;
    }

    final controller = TextEditingController(text: value);
    _fieldControllers[key] = controller;
    return controller;
  }

  void _clearFieldControllersByPrefix(String prefix) {
    final keysToRemove = _fieldControllers.keys
        .where((key) => key.startsWith(prefix))
        .toList();
    for (final key in keysToRemove) {
      _fieldControllers.remove(key)?.dispose();
    }
  }

  List<Map<String, String>> _getSkillRows() {
    return [
      {'heading': skillsLanguagesLabel, 'skills': data.languages},
      {'heading': skillsFrameworksLabel, 'skills': data.frameworks},
      {'heading': skillsToolsLabel, 'skills': data.tools},
      {'heading': skillsOthersLabel, 'skills': data.others},
      ...extraSkillRows,
    ];
  }

  void _addExtraSkillRow() {
    setState(() {
      extraSkillRows.add({'heading': '', 'skills': ''});
    });
  }

  void _removeExtraSkillRow(int index) {
    setState(() {
      extraSkillRows.removeAt(index);
      _clearFieldControllersByPrefix('skills.extra.');
    });
  }

  void _setPhoneCountry(CountryCode country) {
    _selectedPhoneCountryIso = country.code ?? 'IN';
    _selectedPhoneCountryName = country.name ?? 'India';
    _selectedPhoneCountryCode = country.dialCode ?? '+91';
  }

  void _syncPhoneCountryFromPhone() {
    final phone = data.phone.trim();
    final dialCodeMatch = RegExp(r'^\+\d+').stringMatch(phone);
    if (dialCodeMatch != null) {
      final country = CountryCode.tryFromDialCode(dialCodeMatch);
      if (country != null) {
        _setPhoneCountry(country);
        data.phone = phone
            .substring(dialCodeMatch.length)
            .replaceFirst(RegExp(r'^[\s\-]+'), '');
        return;
      }
    }

    _setPhoneCountry(CountryCode.fromCountryCode(_selectedPhoneCountryIso));
  }

  String _formattedPhone() {
    final phone = data.phone.trim();
    if (phone.isEmpty) return '';
    return '$_selectedPhoneCountryCode $phone';
  }

  Future<void> _handleLogout() async {
    await _saveDraft();

    // Clear session and logout
    await AuthService.logout();
    
    if (mounted) {
      // Redirect to login
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  String _resumeDraftStorageKey() {
    final userId = AuthService.currentUserIdentifier;
    if (userId == null || userId.trim().isEmpty) {
      return '${_resumeDraftKeyPrefix}guest';
    }
    final normalized = userId.trim().toLowerCase();
    return '$_resumeDraftKeyPrefix$normalized';
  }

  void _startDraftAutoSave() {
    _draftAutoSaveTimer?.cancel();
    _draftAutoSaveTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _saveDraft();
    });
  }

  Future<void> _saveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftMap = _buildResumeStateMap();
      await prefs.setString(_resumeDraftStorageKey(), jsonEncode(draftMap));
    } catch (_) {
      // Ignore storage failures; app can still continue editing.
    }
  }

  Future<void> _loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_resumeDraftStorageKey());
      if (raw == null || raw.isEmpty) {
        return;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _applyResumeStateMap(decoded);
      });
      _clearFieldControllersByPrefix('');
    } catch (_) {
      // Ignore invalid drafts and continue with defaults.
    }
  }

  Map<String, dynamic> _buildResumeStateMap() {
    return {
      'name': data.name,
      'role': data.role,
      'email': data.email,
      'phone': data.phone,
      'phoneCountry': {
        'name': _selectedPhoneCountryName,
        'dialCode': _selectedPhoneCountryCode,
      },
      'github': data.github,
      'linkedin': data.linkedin,
      'githubName': data.githubName,
      'linkedinName': data.linkedinName,
      'street': data.street,
      'city': data.city,
      'zipCode': data.zipCode,
      'languages': data.languages,
      'frameworks': data.frameworks,
      'tools': data.tools,
      'others': data.others,
      'experiences': data.experiences
          .map(
            (exp) => {
              'companyName': exp.companyName,
              'jobTitle': exp.jobTitle,
              'location': exp.location,
              'duration': exp.duration,
              'description': exp.description,
            },
          )
          .toList(),
      'projects': data.projects
          .map((proj) => {'title': proj.title, 'description': proj.description})
          .toList(),
      'university': data.university,
      'universityGPA': data.universityGPA,
      'universityLocation': data.universityLocation,
      'universityDuration': data.universityDuration,
      'college': data.college,
      'collegeGPA': data.collegeGPA,
      'collegeLocation': data.collegeLocation,
      'collegeDuration': data.collegeDuration,
      'highSchool': data.highSchool,
      'highSchoolGPA': data.highSchoolGPA,
      'highSchoolLocation': data.highSchoolLocation,
      'highSchoolDuration': data.highSchoolDuration,
      'achievements': data.achievements,
      'strengths': data.strengths,
      'customSections': customSections,
      'sectionOrder': sectionOrder,
      'sectionNames': {
        'skills': skillsSectionName,
        'experience': experienceSectionName,
        'projects': projectsSectionName,
        'education': educationSectionName,
        'achievements': achievementsSectionName,
        'strengths': strengthsSectionName,
      },
      'skillLabels': {
        'languages': skillsLanguagesLabel,
        'frameworks': skillsFrameworksLabel,
        'tools': skillsToolsLabel,
        'others': skillsOthersLabel,
      },
      'extraSkillRows': extraSkillRows,
      'formatting': {
        'nameTextSize': nameTextSize,
        'sectionHeaderSize': sectionHeaderSize,
        'bodyTextSize': bodyTextSize,
        'nameTextColor': nameTextColor.value,
        'sectionHeaderColor': sectionHeaderColor.value,
        'bodyTextColor': bodyTextColor.value,
        'contactLinkColor': contactLinkColor.value,
      },
    };
  }

  void _applyResumeStateMap(Map<String, dynamic> resumeData) {
    String stringValue(String key, String fallback) {
      final value = resumeData[key];
      return value is String ? value : fallback;
    }

    data.name = stringValue('name', data.name);
    data.role = stringValue('role', data.role);
    data.email = stringValue('email', data.email);
    data.phone = stringValue('phone', data.phone);
    data.github = stringValue('github', data.github);
    data.linkedin = stringValue('linkedin', data.linkedin);
    data.githubName = stringValue('githubName', data.githubName);
    data.linkedinName = stringValue('linkedinName', data.linkedinName);
    data.street = stringValue('street', data.street);
    data.city = stringValue('city', data.city);
    data.zipCode = stringValue('zipCode', data.zipCode);
    data.languages = stringValue('languages', data.languages);
    data.frameworks = stringValue('frameworks', data.frameworks);
    data.tools = stringValue('tools', data.tools);
    data.others = stringValue('others', data.others);

    data.university = stringValue('university', data.university);
    data.universityGPA = stringValue('universityGPA', data.universityGPA);
    data.universityLocation =
      stringValue('universityLocation', data.universityLocation);
    data.universityDuration =
      stringValue('universityDuration', data.universityDuration);
    data.college = stringValue('college', data.college);
    data.collegeGPA = stringValue('collegeGPA', data.collegeGPA);
    data.collegeLocation = stringValue('collegeLocation', data.collegeLocation);
    data.collegeDuration = stringValue('collegeDuration', data.collegeDuration);
    data.highSchool = stringValue('highSchool', data.highSchool);
    data.highSchoolGPA = stringValue('highSchoolGPA', data.highSchoolGPA);
    data.highSchoolLocation =
      stringValue('highSchoolLocation', data.highSchoolLocation);
    data.highSchoolDuration =
      stringValue('highSchoolDuration', data.highSchoolDuration);

    final phoneCountry = resumeData['phoneCountry'];
    if (phoneCountry is Map<String, dynamic>) {
      _selectedPhoneCountryName =
          (phoneCountry['name'] as String?) ?? _selectedPhoneCountryName;
      _selectedPhoneCountryCode =
          (phoneCountry['dialCode'] as String?) ?? _selectedPhoneCountryCode;
    }

    final experiences = resumeData['experiences'];
    if (experiences is List) {
      data.experiences = experiences
          .whereType<Map>()
          .map(
            (exp) => ExperienceItem(
              companyName: (exp['companyName'] ?? '').toString(),
              jobTitle: (exp['jobTitle'] ?? '').toString(),
              location: (exp['location'] ?? '').toString(),
              duration: (exp['duration'] ?? '').toString(),
              description: (exp['description'] ?? '').toString(),
            ),
          )
          .toList();
    }

    final projects = resumeData['projects'];
    if (projects is List) {
      data.projects = projects
          .whereType<Map>()
          .map(
            (project) => ProjectItem(
              title: (project['title'] ?? '').toString(),
              description: (project['description'] ?? '').toString(),
            ),
          )
          .toList();
    }

    final achievements = resumeData['achievements'];
    if (achievements is List) {
      data.achievements = achievements.map((item) => item.toString()).toList();
    }

    final strengths = resumeData['strengths'];
    if (strengths is List) {
      data.strengths = strengths.map((item) => item.toString()).toList();
    }

    final loadedCustomSections = resumeData['customSections'];
    if (loadedCustomSections is List) {
      customSections = loadedCustomSections
          .whereType<Map>()
          .map(
            (item) => item.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            ),
          )
          .toList();
    }

    final loadedSectionOrder = resumeData['sectionOrder'];
    if (loadedSectionOrder is List) {
      sectionOrder = loadedSectionOrder.map((item) => item.toString()).toList();
    }

    final sectionNames = resumeData['sectionNames'];
    if (sectionNames is Map<String, dynamic>) {
      skillsSectionName = sectionNames['skills'] as String? ?? skillsSectionName;
      experienceSectionName =
          sectionNames['experience'] as String? ?? experienceSectionName;
      projectsSectionName =
          sectionNames['projects'] as String? ?? projectsSectionName;
      educationSectionName =
          sectionNames['education'] as String? ?? educationSectionName;
      achievementsSectionName =
          sectionNames['achievements'] as String? ?? achievementsSectionName;
      strengthsSectionName =
          sectionNames['strengths'] as String? ?? strengthsSectionName;
    }

    final skillLabels = resumeData['skillLabels'];
    if (skillLabels is Map<String, dynamic>) {
      skillsLanguagesLabel =
          skillLabels['languages'] as String? ?? skillsLanguagesLabel;
      skillsFrameworksLabel =
          skillLabels['frameworks'] as String? ?? skillsFrameworksLabel;
      skillsToolsLabel = skillLabels['tools'] as String? ?? skillsToolsLabel;
      skillsOthersLabel = skillLabels['others'] as String? ?? skillsOthersLabel;
    }

    final loadedExtraSkillRows = resumeData['extraSkillRows'];
    if (loadedExtraSkillRows is List) {
      extraSkillRows = loadedExtraSkillRows
          .whereType<Map>()
          .map(
            (item) => {
              'heading': (item['heading'] ?? '').toString(),
              'skills': (item['skills'] ?? '').toString(),
            },
          )
          .toList();
    }

    final formatting = resumeData['formatting'];
    if (formatting is Map<String, dynamic>) {
      nameTextSize = (formatting['nameTextSize'] as num?)?.toDouble() ?? nameTextSize;
      sectionHeaderSize =
          (formatting['sectionHeaderSize'] as num?)?.toDouble() ?? sectionHeaderSize;
      bodyTextSize = (formatting['bodyTextSize'] as num?)?.toDouble() ?? bodyTextSize;
      nameTextColor = Color((formatting['nameTextColor'] as int?) ?? nameTextColor.value);
      sectionHeaderColor = Color(
        (formatting['sectionHeaderColor'] as int?) ?? sectionHeaderColor.value,
      );
      bodyTextColor =
          Color((formatting['bodyTextColor'] as int?) ?? bodyTextColor.value);
      contactLinkColor =
          Color((formatting['contactLinkColor'] as int?) ?? contactLinkColor.value);
    }

    _syncPhoneCountryFromPhone();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        title: const Text(
          "Professional Resume Builder",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 22,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                _handleLogout();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(
                Icons.more_vert,
                color: Colors.white,
              ),
            ),
          ),
        ],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF6B8E7F), const Color(0xFF557A6E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        backgroundColor: const Color(0xFF6B8E7F),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Determine if we're on mobile (< 900px width)
          final isMobileView = constraints.maxWidth < 900;
          
          // Debug: Print to console
          // print('Screen width: ${constraints.maxWidth}, isMobileView: $isMobileView');
          
          if (isMobileView) {
            // MOBILE LAYOUT: Tabs/Toggle for Form vs Preview
            return Column(
              children: [
                // Debug banner (remove in production)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                  color: Colors.amber[100],
                  child: Text(
                    'Mobile View (${constraints.maxWidth.toStringAsFixed(0)}px)',
                    style: const TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                ),
                // Tab/Toggle Header
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Material(
                            child: InkWell(
                              onTap: () {
                                setState(() => _showPreviewOnMobile = false);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: !_showPreviewOnMobile
                                          ? const Color(0xFF6B8E7F)
                                          : Colors.transparent,
                                      width: 3,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  "Edit Resume",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: !_showPreviewOnMobile
                                        ? const Color(0xFF6B8E7F)
                                        : Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Material(
                            child: InkWell(
                              onTap: () {
                                setState(() => _showPreviewOnMobile = true);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: _showPreviewOnMobile
                                          ? const Color(0xFF6B8E7F)
                                          : Colors.transparent,
                                      width: 3,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  "Preview",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: _showPreviewOnMobile
                                        ? const Color(0xFF6B8E7F)
                                        : Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Content
                Expanded(
                  child: _showPreviewOnMobile
                      ? _buildPreviewSection()
                      : _buildFormSection(),
                ),
              ],
            );
          } else {
            // DESKTOP LAYOUT: Side-by-side
            return Row(
              children: [
                // LEFT — RESUME FORM (50%)
                Expanded(flex: 1, child: _buildFormSection()),

                // DIVIDER
                Container(width: 1, color: const Color(0xFFE2E8F0)),

                // RIGHT — PREVIEW SECTION (50%)
                Expanded(flex: 1, child: _buildPreviewSection()),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildFormSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 500;
        
        return Container(
          color: const Color(0xFFF8FAFC),
          child: Column(
            children: [
              // Header with Extra Features Button
              Container(
                padding: EdgeInsets.all(isCompact ? 12 : 20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                  ),
                ),
                child: isCompact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Resume Information",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A202C),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _showATSScoreDialog,
                                  icon: const Icon(Icons.analytics_outlined, size: 16),
                                  label: const Text(
                                    "ATS Score",
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF8B5CF6),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    elevation: 2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _showExtraEditingDialog,
                                  icon: const Icon(Icons.palette, size: 16),
                                  label: const Text(
                                    "Customize",
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF6B8E7F),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    elevation: 2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          const Expanded(
                            child: Text(
                              "Resume Information",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A202C),
                              ),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _showATSScoreDialog,
                            icon: const Icon(Icons.analytics_outlined, size: 18),
                            label: const Text("ATS Score"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8B5CF6),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 2,
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: _showExtraEditingDialog,
                            icon: const Icon(Icons.palette, size: 18),
                            label: const Text("Customize"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6B8E7F),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 2,
                            ),
                          ),
                        ],
                      ),
              ),

              // Scrollable Form Content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isCompact ? 12 : 20),
                  child: Column(
                    children: [
                      _buildPersonalInfoCard(),
                      const SizedBox(height: 16),
                      _buildSkillsCard(),
                      const SizedBox(height: 16),
                      _buildExperienceCard(),
                      const SizedBox(height: 16),
                      _buildProjectsCard(),
                      const SizedBox(height: 16),
                      _buildEducationCard(),
                      const SizedBox(height: 16),
                      _buildAchievementsCard(),
                      const SizedBox(height: 16),
                      _buildStrengthsCard(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPersonalInfoCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        initiallyExpanded: isPersonalExpanded,
        onExpansionChanged: (expanded) {
          setState(() {
            isPersonalExpanded = expanded;
          });
        },
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF6B8E7F).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.person_outline,
            color: Color(0xFF6B8E7F),
            size: 22,
          ),
        ),
        title: const Text(
          "Personal Information",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A202C),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              children: [
                _modernTextField(
                  "Full Name",
                  Icons.person,
                  (v) => setState(() => data.name = v),
                  fieldKey: 'personal.name',
                  initialValue: data.name,
                ),
                _buildPhoneField(),
                _modernTextField(
                  "Email",
                  Icons.email,
                  (v) => setState(() => data.email = v),
                  fieldKey: 'personal.email',
                  initialValue: data.email,
                ),
                _modernTextField(
                  "LinkedIn URL",
                  Icons.link,
                  (v) => setState(() => data.linkedin = v),
                  fieldKey: 'personal.linkedin',
                  initialValue: data.linkedin,
                ),
                _modernTextField(
                  "LinkedIn Display Name",
                  Icons.business,
                  (v) => setState(() => data.linkedinName = v),
                  fieldKey: 'personal.linkedinName',
                  initialValue: data.linkedinName,
                ),
                _modernTextField(
                  "GitHub URL",
                  Icons.code,
                  (v) => setState(() => data.github = v),
                  fieldKey: 'personal.github',
                  initialValue: data.github,
                ),
                _modernTextField(
                  "GitHub Display Name",
                  Icons.code_outlined,
                  (v) => setState(() => data.githubName = v),
                  fieldKey: 'personal.githubName',
                  initialValue: data.githubName,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillsTableHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: const [
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: 8),
              child: Text(
                'Sub Heading',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4A5568),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: EdgeInsets.only(left: 8),
              child: Text(
                'Skills',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4A5568),
                ),
              ),
            ),
          ),
          SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildSkillInputField({
    required String fieldKey,
    required String initialValue,
    required String hintText,
    required ValueChanged<String> onChanged,
    bool compact = false,
  }) {
    final controller = _getFieldController(fieldKey, initialValue);
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(
        color: Color(0xFF2D3748),
        fontSize: 14,
        height: 1.4,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          color: Color(0xFF718096),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: compact ? 12 : 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF6B8E7F), width: 2),
        ),
        filled: true,
        fillColor: compact ? const Color(0xFFFAFBFC) : const Color(0xFFF7FAFC),
      ),
    );
  }

  Widget _buildSkillEditorRow({
    required String headingFieldKey,
    required String headingValue,
    required String headingHint,
    required String skillsFieldKey,
    required String skillsValue,
    required String skillsHint,
    required ValueChanged<String> onHeadingChanged,
    required ValueChanged<String> onSkillsChanged,
    VoidCallback? onRemove,
    bool compact = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildSkillInputField(
                fieldKey: headingFieldKey,
                initialValue: headingValue,
                hintText: headingHint,
                onChanged: onHeadingChanged,
                compact: compact,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _buildSkillInputField(
                fieldKey: skillsFieldKey,
                initialValue: skillsValue,
                hintText: skillsHint,
                onChanged: onSkillsChanged,
                compact: compact,
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: onRemove == null
                ? const SizedBox()
                : IconButton(
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Remove skill row',
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneField({bool compact = false}) {
    final phoneController = _getFieldController('personal.phone', data.phone);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 56,
              child: Container(
                decoration: BoxDecoration(
                  color: compact
                      ? const Color(0xFFFAFBFC)
                      : const Color(0xFFF7FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                    width: 1.5,
                  ),
                ),
                child: Localizations.override(
                  context: context,
                  locale: const Locale('en'),
                  child: CountryCodePicker(
                    onChanged: (country) {
                      setState(() {
                        _setPhoneCountry(country);
                      });
                    },
                    onInit: (country) {
                      if (country == null) return;
                      _setPhoneCountry(country);
                    },
                    initialSelection: _selectedPhoneCountryIso,
                    favorite: const ['+91', 'US', 'GB', 'AE'],
                    showCountryOnly: false,
                    showOnlyCountryWhenClosed: false,
                    showDropDownButton: true,
                    showFlag: false,
                    showFlagDialog: true,
                    hideMainText: false,
                    alignLeft: true,
                    hideSearch: false,
                    searchDecoration: InputDecoration(
                      hintText: 'Search country',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF2D3748),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: SizedBox(
              height: 56,
              child: TextField(
                controller: phoneController,
                onChanged: (value) => setState(() => data.phone = value),
                keyboardType: TextInputType.phone,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF2D3748),
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(
                    Icons.phone,
                    color: const Color(0xFF6B8E7F),
                    size: compact ? 18 : 20,
                  ),
                  labelStyle: const TextStyle(
                    color: Color(0xFF718096),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: Color(0xFFE2E8F0),
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: Color(0xFF6B8E7F),
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: compact
                      ? const Color(0xFFFAFBFC)
                      : const Color(0xFFF7FAFC),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillsCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        initiallyExpanded: isSkillsExpanded,
        onExpansionChanged: (expanded) {
          setState(() {
            isSkillsExpanded = expanded;
          });
        },
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF6B8E7F).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.psychology_outlined,
            color: Color(0xFF6B8E7F),
            size: 22,
          ),
        ),
        title: const Text(
          "Skills",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A202C),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              children: [
                _buildSkillsTableHeader(),
                _buildSkillEditorRow(
                  headingFieldKey: 'skills.languages.heading',
                  headingValue: skillsLanguagesLabel,
                  headingHint: 'Languages',
                  skillsFieldKey: 'skills.languages.items',
                  skillsValue: data.languages,
                  skillsHint: 'Add languages',
                  onHeadingChanged: (v) =>
                      setState(() => skillsLanguagesLabel = v),
                  onSkillsChanged: (v) => setState(() => data.languages = v),
                ),
                _buildSkillEditorRow(
                  headingFieldKey: 'skills.frameworks.heading',
                  headingValue: skillsFrameworksLabel,
                  headingHint: 'Frameworks and databases',
                  skillsFieldKey: 'skills.frameworks.items',
                  skillsValue: data.frameworks,
                  skillsHint: 'Add frameworks and databases',
                  onHeadingChanged: (v) =>
                      setState(() => skillsFrameworksLabel = v),
                  onSkillsChanged: (v) => setState(() => data.frameworks = v),
                ),
                _buildSkillEditorRow(
                  headingFieldKey: 'skills.tools.heading',
                  headingValue: skillsToolsLabel,
                  headingHint: 'Tools and technologies',
                  skillsFieldKey: 'skills.tools.items',
                  skillsValue: data.tools,
                  skillsHint: 'Add tools and technologies',
                  onHeadingChanged: (v) => setState(() => skillsToolsLabel = v),
                  onSkillsChanged: (v) => setState(() => data.tools = v),
                ),
                _buildSkillEditorRow(
                  headingFieldKey: 'skills.others.heading',
                  headingValue: skillsOthersLabel,
                  headingHint: 'Others',
                  skillsFieldKey: 'skills.others.items',
                  skillsValue: data.others,
                  skillsHint: 'Add other skills',
                  onHeadingChanged: (v) =>
                      setState(() => skillsOthersLabel = v),
                  onSkillsChanged: (v) => setState(() => data.others = v),
                ),
                ...extraSkillRows.asMap().entries.map((entry) {
                  final index = entry.key;
                  final row = entry.value;
                  return _buildSkillEditorRow(
                    headingFieldKey: 'skills.extra.$index.heading',
                    headingValue: row['heading'] ?? '',
                    headingHint: 'Custom sub heading',
                    skillsFieldKey: 'skills.extra.$index.items',
                    skillsValue: row['skills'] ?? '',
                    skillsHint: 'Add skills for this sub heading',
                    onHeadingChanged: (v) =>
                        setState(() => extraSkillRows[index]['heading'] = v),
                    onSkillsChanged: (v) =>
                        setState(() => extraSkillRows[index]['skills'] = v),
                    onRemove: () => _removeExtraSkillRow(index),
                  );
                }),
                _modernAddButton(
                  'Add Extra Skill / Subheading',
                  Icons.edit_note,
                  _addExtraSkillRow,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _modernTextField(
    String label,
    IconData icon,
    Function(String) onChanged, {
    int lines = 1,
    required String fieldKey,
    required String initialValue,
  }) {
    final controller = _getFieldController(fieldKey, initialValue);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        maxLines: lines,
        onChanged: onChanged,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF2D3748),
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF6B8E7F), size: 20),
          labelStyle: const TextStyle(
            color: Color(0xFF718096),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF6B8E7F), width: 2),
          ),
          filled: true,
          fillColor: const Color(0xFFF7FAFC),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
        ),
      ),
    );
  }

  ({int startYear, int? endYear, bool isPresent})? _tryParseYearRange(
    String value,
  ) {
    final match = RegExp(
      r'^(\d{4})\s*-\s*(\d{4}|present)$',
      caseSensitive: false,
    ).firstMatch(value.trim());
    if (match == null) return null;

    final startYear = int.tryParse(match.group(1)!);
    final endToken = match.group(2)!;
    if (startYear == null) {
      return null;
    }

    if (endToken.toLowerCase() == 'present') {
      return (startYear: startYear, endYear: null, isPresent: true);
    }

    final endYear = int.tryParse(endToken);
    if (endYear == null || endYear < startYear) {
      return null;
    }

    return (startYear: startYear, endYear: endYear, isPresent: false);
  }

  Future<int?> _pickYear({
    required String helpText,
    required int initialYear,
    required int firstYear,
    required int lastYear,
  }) async {
    final pickedDate = await showDatePicker(
      context: context,
      locale: const Locale('en'),
      helpText: helpText,
      initialDate: DateTime(initialYear, 1, 1),
      firstDate: DateTime(firstYear, 1, 1),
      lastDate: DateTime(lastYear, 12, 31),
      initialDatePickerMode: DatePickerMode.year,
    );

    return pickedDate?.year;
  }

  Widget _modernDurationField(
    String label,
    IconData icon,
    Function(String) onChanged, {
    required String fieldKey,
    required String initialValue,
    bool allowPresent = false,
  }) {
    final controller = _getFieldController(fieldKey, initialValue);

    Future<void> pickRange() async {
      final now = DateTime.now();
      final parsedRange = _tryParseYearRange(controller.text);
      final defaultStartYear = parsedRange?.startYear ?? (now.year - 1);
      final defaultEndYear = parsedRange?.endYear ?? now.year;

      final startYear = await _pickYear(
        helpText: 'Select Start Year',
        initialYear: defaultStartYear,
        firstYear: 1970,
        lastYear: now.year + 20,
      );
      if (startYear == null) return;

      if (allowPresent) {
        final usePresent = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('End Year'),
            content: const Text('Set end as Present or select a year?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Select Year'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Present'),
              ),
            ],
          ),
        );

        if (usePresent == null) return;

        if (usePresent) {
          final formatted = '$startYear - Present';
          controller.text = formatted;
          onChanged(formatted);
          return;
        }
      }

      final endYear = await _pickYear(
        helpText: 'Select End Year',
        initialYear: defaultEndYear < startYear ? startYear : defaultEndYear,
        firstYear: startYear,
        lastYear: now.year + 20,
      );
      if (endYear == null) return;

      final formatted = '$startYear - $endYear';
      controller.text = formatted;
      onChanged(formatted);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        readOnly: true,
        onTap: pickRange,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF2D3748),
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: 'YYYY - YYYY',
          prefixIcon: Icon(icon, color: const Color(0xFF6B8E7F), size: 20),
          suffixIcon: IconButton(
            onPressed: pickRange,
            icon: const Icon(
              Icons.calendar_month,
              color: Color(0xFF6B8E7F),
              size: 20,
            ),
          ),
          labelStyle: const TextStyle(
            color: Color(0xFF718096),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF6B8E7F), width: 2),
          ),
          filled: true,
          fillColor: const Color(0xFFF7FAFC),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildExperienceCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        initiallyExpanded: isExperienceExpanded,
        onExpansionChanged: (expanded) {
          setState(() {
            isExperienceExpanded = expanded;
          });
        },
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF6B8E7F).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.work_outline,
            color: Color(0xFF6B8E7F),
            size: 22,
          ),
        ),
        title: const Text(
          "Experience",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A202C),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              children: [
                ...data.experiences.asMap().entries.map((entry) {
                  int index = entry.key;
                  ExperienceItem experience = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FFF4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFB8E6C1)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                "Experience ${index + 1}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2D3748),
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (data.experiences.length > 1)
                              IconButton(
                                onPressed: () => _removeExperience(index),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                tooltip: 'Remove Experience',
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _modernTextField(
                          "Company Name",
                          Icons.business,
                          (v) => setState(() => experience.companyName = v),
                          fieldKey: 'experience.$index.companyName',
                          initialValue: experience.companyName,
                        ),
                        _modernTextField(
                          "Job Title",
                          Icons.work,
                          (v) => setState(() => experience.jobTitle = v),
                          fieldKey: 'experience.$index.jobTitle',
                          initialValue: experience.jobTitle,
                        ),
                        _modernTextField(
                          "Location",
                          Icons.location_on,
                          (v) => setState(() => experience.location = v),
                          fieldKey: 'experience.$index.location',
                          initialValue: experience.location,
                        ),
                        _modernDurationField(
                          "Duration",
                          Icons.schedule,
                          (v) => setState(() => experience.duration = v),
                          fieldKey: 'experience.$index.duration',
                          initialValue: experience.duration,
                          allowPresent: true,
                        ),
                        _modernTextField(
                          "Description",
                          Icons.description,
                          (v) => setState(() => experience.description = v),
                          lines: 3,
                          fieldKey: 'experience.$index.description',
                          initialValue: experience.description,
                        ),
                      ],
                    ),
                  );
                }).toList(),
                _modernAddButton(
                  "Add Experience",
                  Icons.add_business,
                  _addExperience,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectsCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        initiallyExpanded: isProjectsExpanded,
        onExpansionChanged: (expanded) {
          setState(() {
            isProjectsExpanded = expanded;
          });
        },
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF6B8E7F).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.folder_outlined,
            color: Color(0xFF6B8E7F),
            size: 22,
          ),
        ),
        title: const Text(
          "Projects",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A202C),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              children: [
                ...data.projects.asMap().entries.map((entry) {
                  int index = entry.key;
                  ProjectItem project = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FFF4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFB8E6C1)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                "Project ${index + 1}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2D3748),
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (data.projects.length > 1)
                              IconButton(
                                onPressed: () => _removeProject(index),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                tooltip: 'Remove Project',
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _modernTextField(
                          "Project Title",
                          Icons.title,
                          (v) => setState(() => project.title = v),
                          fieldKey: 'project.$index.title',
                          initialValue: project.title,
                        ),
                        _modernTextField(
                          "Project Description",
                          Icons.description,
                          (v) => setState(() => project.description = v),
                          lines: 3,
                          fieldKey: 'project.$index.description',
                          initialValue: project.description,
                        ),
                      ],
                    ),
                  );
                }).toList(),
                _modernAddButton("Add Project", Icons.add_box, _addProject),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEducationCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        initiallyExpanded: isEducationExpanded,
        onExpansionChanged: (expanded) {
          setState(() {
            isEducationExpanded = expanded;
          });
        },
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF6B8E7F).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.school_outlined,
            color: Color(0xFF6B8E7F),
            size: 22,
          ),
        ),
        title: const Text(
          "Education",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A202C),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              children: [
                // University block
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "University",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3748),
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _modernTextField(
                        "University Name",
                        Icons.account_balance,
                        (v) => setState(() => data.university = v),
                        fieldKey: 'education.university.name',
                        initialValue: data.university,
                      ),
                      _modernTextField(
                        "University GPA",
                        Icons.grade,
                        (v) => setState(() => data.universityGPA = v),
                        fieldKey: 'education.university.gpa',
                        initialValue: data.universityGPA,
                      ),
                      _modernTextField(
                        "University Location",
                        Icons.location_on,
                        (v) => setState(() => data.universityLocation = v),
                        fieldKey: 'education.university.location',
                        initialValue: data.universityLocation,
                      ),
                      _modernDurationField(
                        "University Duration",
                        Icons.schedule,
                        (v) => setState(() => data.universityDuration = v),
                        fieldKey: 'education.university.duration',
                        initialValue: data.universityDuration,
                      ),
                    ],
                  ),
                ),
                // College block
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "College",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3748),
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _modernTextField(
                        "College Name",
                        Icons.school,
                        (v) => setState(() => data.college = v),
                        fieldKey: 'education.college.name',
                        initialValue: data.college,
                      ),
                      _modernTextField(
                        "College GPA",
                        Icons.grade,
                        (v) => setState(() => data.collegeGPA = v),
                        fieldKey: 'education.college.gpa',
                        initialValue: data.collegeGPA,
                      ),
                      _modernTextField(
                        "College Location",
                        Icons.location_on,
                        (v) => setState(() => data.collegeLocation = v),
                        fieldKey: 'education.college.location',
                        initialValue: data.collegeLocation,
                      ),
                      _modernDurationField(
                        "College Duration",
                        Icons.schedule,
                        (v) => setState(() => data.collegeDuration = v),
                        fieldKey: 'education.college.duration',
                        initialValue: data.collegeDuration,
                      ),
                    ],
                  ),
                ),
                // High School block
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "High School",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3748),
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _modernTextField(
                        "High School Name",
                        Icons.school,
                        (v) => setState(() => data.highSchool = v),
                        fieldKey: 'education.highSchool.name',
                        initialValue: data.highSchool,
                      ),
                      _modernTextField(
                        "High School GPA",
                        Icons.grade,
                        (v) => setState(() => data.highSchoolGPA = v),
                        fieldKey: 'education.highSchool.gpa',
                        initialValue: data.highSchoolGPA,
                      ),
                      _modernTextField(
                        "High School Location",
                        Icons.location_on,
                        (v) => setState(() => data.highSchoolLocation = v),
                        fieldKey: 'education.highSchool.location',
                        initialValue: data.highSchoolLocation,
                      ),
                      _modernDurationField(
                        "High School Duration",
                        Icons.schedule,
                        (v) => setState(() => data.highSchoolDuration = v),
                        fieldKey: 'education.highSchool.duration',
                        initialValue: data.highSchoolDuration,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        initiallyExpanded: isAchievementsExpanded,
        onExpansionChanged: (expanded) {
          setState(() {
            isAchievementsExpanded = expanded;
          });
        },
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF6B8E7F).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.emoji_events_outlined,
            color: Color(0xFF6B8E7F),
            size: 22,
          ),
        ),
        title: const Text(
          "Achievements",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A202C),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              children: [
                ...data.achievements.asMap().entries.map((entry) {
                  int index = entry.key;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: _modernTextField(
                            "Achievement ${index + 1}",
                            Icons.star_outline,
                            (v) => setState(() => data.achievements[index] = v),
                            fieldKey: 'achievement.$index',
                            initialValue: data.achievements[index],
                          ),
                        ),
                        if (data.achievements.length > 1)
                          IconButton(
                            onPressed: () => _removeAchievement(index),
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                              size: 20,
                            ),
                            tooltip: 'Remove Achievement',
                          ),
                      ],
                    ),
                  );
                }).toList(),
                _modernAddButton(
                  "Add Achievement",
                  Icons.add_circle_outline,
                  _addAchievement,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrengthsCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        initiallyExpanded: isStrengthsExpanded,
        onExpansionChanged: (expanded) {
          setState(() {
            isStrengthsExpanded = expanded;
          });
        },
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF6B8E7F).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.fitness_center_outlined,
            color: Color(0xFF6B8E7F),
            size: 22,
          ),
        ),
        title: const Text(
          "Strengths",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A202C),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              children: [
                ...data.strengths.asMap().entries.map((entry) {
                  int index = entry.key;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: _modernTextField(
                            "Strength ${index + 1}",
                            Icons.psychology,
                            (v) => setState(() => data.strengths[index] = v),
                            fieldKey: 'strength.$index',
                            initialValue: data.strengths[index],
                          ),
                        ),
                        if (data.strengths.length > 1)
                          IconButton(
                            onPressed: () => _removeStrength(index),
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                              size: 20,
                            ),
                            tooltip: 'Remove Strength',
                          ),
                      ],
                    ),
                  );
                }).toList(),
                _modernAddButton(
                  "Add Strength",
                  Icons.add_circle_outline,
                  _addStrength,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _modernAddButton(String text, IconData icon, VoidCallback onPressed) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(
          text,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF6B8E7F),
          side: const BorderSide(color: Color(0xFF6B8E7F), width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          backgroundColor: const Color(0xFF6B8E7F).withOpacity(0.05),
        ),
      ),
    );
  }

  Widget _buildPreviewSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 500;
        
        return Container(
          color: const Color(0xFFF1F5F9),
          child: Column(
            children: [
              // Header with Action Buttons
              Container(
                padding: EdgeInsets.all(isCompact ? 12 : 20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                  ),
                ),
                child: isCompact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Live Preview",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A202C),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _downloadAsPDF,
                                  icon: const Icon(Icons.download_rounded, size: 16),
                                  label: const Text(
                                    "PDF",
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF6B8E7F),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    elevation: 2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _copyAsLink,
                                  icon: const Icon(Icons.share_rounded, size: 16),
                                  label: const Text(
                                    "Share",
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF8E6B7F),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    elevation: 2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          const Expanded(
                            child: Text(
                              "Live Preview",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A202C),
                              ),
                            ),
                          ),
                          // Download PDF Button
                          Container(
                            margin: const EdgeInsets.only(right: 12),
                            child: ElevatedButton.icon(
                              onPressed: _downloadAsPDF,
                              icon: const Icon(Icons.download_rounded, size: 18),
                              label: const Text(
                                "Download PDF",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6B8E7F),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 2,
                                shadowColor: Colors.black.withOpacity(0.2),
                              ),
                            ),
                          ),
                          // Copy Link Button
                          ElevatedButton.icon(
                            onPressed: _copyAsLink,
                            icon: const Icon(Icons.share_rounded, size: 18),
                            label: const Text(
                              "Share Link",
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8E6B7F),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 2,
                              shadowColor: Colors.black.withOpacity(0.2),
                            ),
                          ),
                        ],
                      ),
              ),

              // A4 Preview Container
              Expanded(
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.all(20),
                    constraints: const BoxConstraints(maxWidth: 600),
                child: AspectRatio(
                  aspectRatio: 210 / 297, // A4 ratio
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                          spreadRadius: 0,
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Column(
                        children: [
                          // Preview Header
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF6B8E7F).withOpacity(0.1),
                                  const Color(0xFF557A6E).withOpacity(0.05),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.description_outlined,
                                  color: const Color(0xFF6B8E7F),
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  "A4 Format • Print Ready",
                                  style: TextStyle(
                                    color: Color(0xFF6B8E7F),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Resume Content
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header Section
                                  _buildResumeHeader(),

                                  const SizedBox(height: 20),

                                  // Sections in custom order
                                  ...sectionOrder.map((section) {
                                    switch (section) {
                                      case 'Skills':
                                        return Column(
                                          children: [
                                            _buildSkillsSection(),
                                            const SizedBox(height: 20),
                                          ],
                                        );
                                      case 'Experience':
                                        return Column(
                                          children: [
                                            _buildExperienceSection(),
                                            const SizedBox(height: 20),
                                          ],
                                        );
                                      case 'Projects':
                                        return Column(
                                          children: [
                                            _buildProjectsSection(),
                                            const SizedBox(height: 20),
                                          ],
                                        );
                                      case 'Education':
                                        return Column(
                                          children: [
                                            _buildEducationSection(),
                                            const SizedBox(height: 20),
                                          ],
                                        );
                                      case 'Achievements':
                                        return Column(
                                          children: [
                                            _buildAchievementsSection(),
                                            const SizedBox(height: 20),
                                          ],
                                        );
                                      case 'Strengths':
                                        return Column(
                                          children: [
                                            _buildStrengthsSection(),
                                            const SizedBox(height: 20),
                                          ],
                                        );
                                      default:
                                        // Check if it's a custom section
                                        var customSection = customSections
                                            .firstWhere(
                                              (cs) => cs['id'] == section,
                                              orElse: () => {},
                                            );
                                        if (customSection.isNotEmpty) {
                                          return Column(
                                            children: [
                                              _buildCustomSection(
                                                customSection,
                                              ),
                                              const SizedBox(height: 20),
                                            ],
                                          );
                                        }
                                        return const SizedBox();
                                    }
                                  }).toList(),
                                ],
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
        ],
      ),
        );
      },
    );
  }

  // Add/Remove methods
  void _addExperience() {
    setState(() {
      data.experiences.add(ExperienceItem());
      _clearFieldControllersByPrefix('experience.');
    });
  }

  void _removeExperience(int index) {
    setState(() {
      data.experiences.removeAt(index);
      _clearFieldControllersByPrefix('experience.');
    });
  }

  void _addProject() {
    setState(() {
      data.projects.add(ProjectItem());
      _clearFieldControllersByPrefix('project.');
    });
  }

  void _removeProject(int index) {
    setState(() {
      data.projects.removeAt(index);
      _clearFieldControllersByPrefix('project.');
    });
  }

  void _addAchievement() {
    setState(() {
      data.achievements.add("");
      _clearFieldControllersByPrefix('achievement.');
    });
  }

  void _removeAchievement(int index) {
    setState(() {
      data.achievements.removeAt(index);
      _clearFieldControllersByPrefix('achievement.');
    });
  }

  void _addStrength() {
    setState(() {
      data.strengths.add("");
      _clearFieldControllersByPrefix('strength.');
    });
  }

  void _removeStrength(int index) {
    setState(() {
      data.strengths.removeAt(index);
      _clearFieldControllersByPrefix('strength.');
    });
  }

  // Calculate ATS Score based on resume content
  void _calculateATSScore() {
    int score = 0;
    List<String> recommendations = [];

    // Basic Contact Information (25 points)
    if (data.name.isNotEmpty && data.name != "YOUR NAME")
      score += 5;
    else
      recommendations.add("Add your full name");

    if (data.email.isNotEmpty &&
        data.email.contains('@') &&
        !data.email.contains("youremail"))
      score += 5;
    else
      recommendations.add("Add a valid email address");

    if (data.phone.isNotEmpty && !data.phone.contains("1234567890"))
      score += 5;
    else
      recommendations.add("Add your phone number");

    if ((data.street.isNotEmpty && !data.street.contains("Street")) ||
        (data.city.isNotEmpty && !data.city.contains("City")))
      score += 5;
    else
      recommendations.add("Add your location details");

    if ((data.linkedin.isNotEmpty && !data.linkedin.contains("yourprofile")) ||
        (data.github.isNotEmpty && !data.github.contains("yourprofile")))
      score += 5;
    else
      recommendations.add("Add LinkedIn or GitHub profile");

    // Skills Section (20 points)
    List<String> allSkills = _getSkillRows()
        .map((row) => row['skills']!.trim())
        .where((skill) => skill.isNotEmpty)
        .toList();

    if (allSkills.isNotEmpty) {
      score += 10;
      int skillCount = allSkills.join(',').split(',').length;
      if (skillCount >= 5)
        score += 5;
      else
        recommendations.add("Add more skills (at least 5)");

      // Check for technical keywords
      String skillsText = allSkills.join(' ').toLowerCase();
      List<String> techKeywords = [
        'python',
        'java',
        'javascript',
        'react',
        'node',
        'sql',
        'git',
        'aws',
        'docker',
        'kubernetes',
        'machine learning',
        'data analysis',
        'flutter',
        'dart',
        'c++',
        'mongodb',
        'mysql',
      ];
      int techCount = techKeywords
          .where((keyword) => skillsText.contains(keyword))
          .length;
      if (techCount >= 3)
        score += 5;
      else
        recommendations.add("Add more technical skills with industry keywords");
    } else {
      recommendations.add("Add skills section with relevant keywords");
    }

    // Experience Section (25 points)
    if (data.experiences.isNotEmpty) {
      score += 10;

      // Check for job descriptions
      bool hasDescriptions = data.experiences.any(
        (exp) =>
            exp.description.isNotEmpty &&
            !exp.description.contains("Briefly describe"),
      );
      if (hasDescriptions)
        score += 8;
      else
        recommendations.add("Add detailed job descriptions");

      // Check for quantifiable achievements
      String expText = data.experiences.map((exp) => exp.description).join(' ');
      RegExp numbers = RegExp(r'\d+');
      if (numbers.hasMatch(expText))
        score += 7;
      else
        recommendations.add(
          "Include quantifiable achievements (numbers, percentages)",
        );
    } else {
      recommendations.add("Add work experience section");
    }

    // Education Section (15 points)
    bool hasEducation =
        (data.university.isNotEmpty &&
            !data.university.contains("Your University")) ||
        (data.college.isNotEmpty && !data.college.contains("Your College")) ||
        (data.highSchool.isNotEmpty &&
            !data.highSchool.contains("Your High School"));

    if (hasEducation) {
      score += 10;
      bool hasGraduation =
          data.universityDuration.isNotEmpty ||
          data.collegeDuration.isNotEmpty ||
          data.highSchoolDuration.isNotEmpty;
      if (hasGraduation && !data.universityDuration.contains("Graduation Date"))
        score += 5;
      else
        recommendations.add("Add graduation years for education");
    } else {
      recommendations.add("Add education section");
    }

    // Projects Section (10 points)
    if (data.projects.isNotEmpty) {
      score += 5;
      bool hasProjectDesc = data.projects.any(
        (proj) =>
            proj.description.isNotEmpty &&
            !proj.description.contains("Briefly describe"),
      );
      if (hasProjectDesc)
        score += 5;
      else
        recommendations.add("Add detailed project descriptions");
    } else {
      recommendations.add("Consider adding relevant projects");
    }

    // Additional Sections (5 points)
    if (data.achievements.isNotEmpty || data.strengths.isNotEmpty) {
      score += 5;
    }

    // Format and Structure Bonuses
    if (data.name.length > 2 && !data.name.contains(RegExp(r'[^a-zA-Z\s]')))
      score += 2;
    if (data.email.toLowerCase() == data.email) score += 1;
    int totalSkillCount = allSkills.join(',').split(',').length;
    if (totalSkillCount >= 8) score += 2;

    // Set the calculated values
    setState(() {
      _atsScore = score;
      _atsRecommendations = recommendations;

      if (score >= 90) {
        _atsScoreText = "Excellent ATS compatibility";
      } else if (score >= 75) {
        _atsScoreText = "Good ATS compatibility";
      } else if (score >= 60) {
        _atsScoreText = "Fair ATS compatibility - needs improvement";
      } else {
        _atsScoreText =
            "Poor ATS compatibility - significant improvement needed";
      }
    });
  }

  void _showATSScoreDialog() {
    // Calculate score first if not already calculated
    if (_atsScore == 0) {
      _calculateATSScore();
    }

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 500,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
              maxWidth: 500,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFE6F3FF),
                  Color(0xFFF0F8FF),
                  Color(0xFFE8F5E8),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Glassmorphism overlay
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withOpacity(0.2),
                        Colors.white.withOpacity(0.1),
                        Colors.transparent,
                        Colors.white.withOpacity(0.1),
                      ],
                    ),
                  ),
                ),
                // Main content - now scrollable
                SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header with icon and title
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF8B5CF6).withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.analytics_outlined,
                          size: 35,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'ATS Score Checker',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3748),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Analyze your resume\'s ATS compatibility',
                        style: TextStyle(
                          fontSize: 14,
                          color: const Color(0xFF4A5568).withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Score Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: _atsScore >= 75
                                          ? [
                                              const Color(0xFF10B981),
                                              const Color(0xFF059669),
                                            ] // Green for good scores
                                          : _atsScore >= 60
                                          ? [
                                              const Color(0xFFF59E0B),
                                              const Color(0xFFD97706),
                                            ] // Orange for fair scores
                                          : [
                                              const Color(0xFFEF4444),
                                              const Color(0xFFDC2626),
                                            ], // Red for poor scores
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            (_atsScore >= 75
                                                    ? const Color(0xFF10B981)
                                                    : _atsScore >= 60
                                                    ? const Color(0xFFF59E0B)
                                                    : const Color(0xFFEF4444))
                                                .withOpacity(0.3),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      "$_atsScore",
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        "ATS Score",
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF2D3748),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _atsScoreText,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF4A5568),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF7FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Recommendations:",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2D3748),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  if (_atsRecommendations.isEmpty)
                                    const Row(
                                      children: [
                                        Icon(
                                          Icons.check_circle,
                                          color: Color(0xFF10B981),
                                          size: 16,
                                        ),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            "Excellent! Your resume meets all ATS requirements.",
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF4A5568),
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    ..._atsRecommendations
                                        .take(3)
                                        .map(
                                          (recommendation) => Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 6,
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  recommendation.contains(
                                                            'Add',
                                                          ) ||
                                                          recommendation
                                                              .contains(
                                                                'Include',
                                                              )
                                                      ? Icons.warning_rounded
                                                      : Icons.info_outline,
                                                  color:
                                                      recommendation.contains(
                                                            'Add',
                                                          ) ||
                                                          recommendation
                                                              .contains(
                                                                'Include',
                                                              )
                                                      ? const Color(0xFFF59E0B)
                                                      : const Color(0xFF3B82F6),
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    recommendation,
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      color: Color(0xFF4A5568),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        )
                                        .toList(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 44,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  _calculateATSScore();
                                  // Show updated dialog
                                  Future.delayed(
                                    const Duration(milliseconds: 300),
                                    () {
                                      _showATSScoreDialog();
                                    },
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        "Resume analyzed! Updated ATS score calculated.",
                                      ),
                                      backgroundColor: const Color(0xFF8B5CF6),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.refresh_rounded,
                                  size: 16,
                                ),
                                label: const Text(
                                  "Re-analyze",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF8B5CF6),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 4,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SizedBox(
                              height: 44,
                              child: OutlinedButton.icon(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.close_rounded, size: 16),
                                label: const Text(
                                  "Close",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF6B8E7F),
                                  side: const BorderSide(
                                    color: Color(0xFF6B8E7F),
                                    width: 1.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showExtraEditingDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                "Extra Editing Features",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
              content: Container(
                width: 500,
                height: 600,
                child: DefaultTabController(
                  length: 4,
                  child: Column(
                    children: [
                      const TabBar(
                        labelColor: Color(0xFF6B8E7F),
                        unselectedLabelColor: Color(0xFF718096),
                        indicatorColor: Color(0xFF6B8E7F),
                        isScrollable: true,
                        tabs: [
                          Tab(text: "Text Size"),
                          Tab(text: "Colors"),
                          Tab(text: "Section Names"),
                          Tab(text: "Section Order"),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            // Text Size Tab
                            _buildTextSizeTab(setDialogState),
                            // Colors Tab
                            _buildColorsTab(setDialogState),
                            // Section Names Tab
                            _buildSectionNamesTab(setDialogState),
                            // Section Order Tab
                            _buildSectionOrderTab(setDialogState),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    "Close",
                    style: TextStyle(color: Color(0xFF718096)),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {}); // Apply changes
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B8E7F),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("Apply Changes"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTextSizeTab(StateSetter setDialogState) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Adjust Text Sizes",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 20),

          // Name Text Size
          Text("Name Text Size: ${nameTextSize.round()}px"),
          Slider(
            value: nameTextSize,
            min: 16.0,
            max: 32.0,
            divisions: 16,
            activeColor: const Color(0xFF6B8E7F),
            onChanged: (value) {
              setDialogState(() {
                nameTextSize = value;
              });
            },
          ),

          const SizedBox(height: 20),

          // Section Header Size
          Text("Section Header Size: ${sectionHeaderSize.round()}px"),
          Slider(
            value: sectionHeaderSize,
            min: 12.0,
            max: 20.0,
            divisions: 8,
            activeColor: const Color(0xFF6B8E7F),
            onChanged: (value) {
              setDialogState(() {
                sectionHeaderSize = value;
              });
            },
          ),

          const SizedBox(height: 20),

          // Body Text Size
          Text("Body Text Size: ${bodyTextSize.round()}px"),
          Slider(
            value: bodyTextSize,
            min: 9.0,
            max: 15.0,
            divisions: 6,
            activeColor: const Color(0xFF6B8E7F),
            onChanged: (value) {
              setDialogState(() {
                bodyTextSize = value;
              });
            },
          ),

          const SizedBox(height: 30),

          // Reset Button
          Center(
            child: OutlinedButton(
              onPressed: () {
                setDialogState(() {
                  nameTextSize = 20.0;
                  sectionHeaderSize = 14.0;
                  bodyTextSize = 11.0;
                });
              },
              child: const Text("Reset to Default"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorsTab(StateSetter setDialogState) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Customize Colors",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 16),

          // Name Color
          _colorSelector("Name Text Color", nameTextColor, (color) {
            setDialogState(() {
              nameTextColor = color;
            });
          }),

          const SizedBox(height: 12),

          // Section Header Color
          _colorSelector("Section Header Color", sectionHeaderColor, (color) {
            setDialogState(() {
              sectionHeaderColor = color;
            });
          }),

          const SizedBox(height: 12),

          // Body Text Color
          _colorSelector("Body Text Color", bodyTextColor, (color) {
            setDialogState(() {
              bodyTextColor = color;
            });
          }),

          const SizedBox(height: 12),

          // Contact Link Color
          _colorSelector("Contact Link Color", contactLinkColor, (color) {
            setDialogState(() {
              contactLinkColor = color;
            });
          }),

          const SizedBox(height: 20),

          // Reset Button
          Center(
            child: OutlinedButton(
              onPressed: () {
                setDialogState(() {
                  nameTextColor = const Color(0xFF2D3748);
                  sectionHeaderColor = const Color(0xFF2D3748);
                  bodyTextColor = const Color(0xFF2D3748);
                  contactLinkColor = Colors.blue;
                });
              },
              child: const Text("Reset to Default"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _colorSelector(
    String label,
    Color currentColor,
    Function(Color) onColorChanged,
  ) {
    List<Color> colors = [
      Colors.black,
      const Color(0xFF2D3748),
      const Color(0xFF4A5568),
      Colors.blue,
      Colors.green,
      Colors.red,
      Colors.purple,
      Colors.orange,
      Colors.teal,
      const Color(0xFF6B8E7F),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: Color(0xFF2D3748),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: colors.map((color) {
            bool isSelected = color.value == currentColor.value;
            return GestureDetector(
              onTap: () => onColorChanged(color),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.grey[300]!,
                    width: isSelected ? 3 : 1,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSectionNamesTab(StateSetter setDialogState) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Edit Section Names",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 16),

          // Add Custom Section button at top
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            child: ElevatedButton.icon(
              onPressed: () {
                setDialogState(() {
                  _showAddSectionForm = !_showAddSectionForm;
                  if (_showAddSectionForm) {
                    _newSectionNameController.clear();
                    _newSectionContentController.clear();
                  }
                });
              },
              icon: Icon(
                _showAddSectionForm ? Icons.remove : Icons.add,
                size: 18,
              ),
              label: Text(
                _showAddSectionForm ? 'Cancel' : 'Add Custom Section',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _showAddSectionForm
                    ? const Color(0xFF718096)
                    : const Color(0xFF6B8E7F),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),
          const Text(
            "Skill Subheadings",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 8),
          _sectionNameEditor("Languages Label", skillsLanguagesLabel, (v) {
            setDialogState(() => skillsLanguagesLabel = v);
          }),
          _sectionNameEditor("Frameworks Label", skillsFrameworksLabel, (v) {
            setDialogState(() => skillsFrameworksLabel = v);
          }),
          _sectionNameEditor("Tools Label", skillsToolsLabel, (v) {
            setDialogState(() => skillsToolsLabel = v);
          }),
          _sectionNameEditor("Others Label", skillsOthersLabel, (v) {
            setDialogState(() => skillsOthersLabel = v);
          }),

          // Add Section Form (shown below the button when active)
          if (_showAddSectionForm)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FFF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFB8E6C1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Create New Section",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Section Name Input
                  TextFormField(
                    controller: _newSectionNameController,
                    decoration: const InputDecoration(
                      labelText: 'Section Name',
                      hintText: 'e.g., Certifications, Languages, Hobbies',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Section Content Input
                  TextFormField(
                    controller: _newSectionContentController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Section Content',
                      hintText: 'Enter the content for this section...',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          setDialogState(() {
                            _showAddSectionForm = false;
                            _newSectionNameController.clear();
                            _newSectionContentController.clear();
                          });
                        },
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          if (_newSectionNameController.text
                              .trim()
                              .isNotEmpty) {
                            setDialogState(() {
                              customSections.add({
                                'id':
                                    'custom_${DateTime.now().millisecondsSinceEpoch}',
                                'name': _newSectionNameController.text.trim(),
                                'content':
                                    _newSectionContentController.text
                                        .trim()
                                        .isEmpty
                                    ? 'Add your content here...'
                                    : _newSectionContentController.text.trim(),
                              });
                              sectionOrder.add(customSections.last['id']!);
                              _showAddSectionForm = false;
                              _newSectionNameController.clear();
                              _newSectionContentController.clear();
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6B8E7F),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Create Section'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Built-in sections
          const Text(
            "Built-in Sections",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B8E7F),
            ),
          ),
          const SizedBox(height: 8),

          _sectionNameEditor("Skills Section", skillsSectionName, (value) {
            setDialogState(() {
              skillsSectionName = value;
            });
          }),

          const SizedBox(height: 12),

          _sectionNameEditor("Experience Section", experienceSectionName, (
            value,
          ) {
            setDialogState(() {
              experienceSectionName = value;
            });
          }),

          const SizedBox(height: 12),

          _sectionNameEditor("Projects Section", projectsSectionName, (value) {
            setDialogState(() {
              projectsSectionName = value;
            });
          }),

          const SizedBox(height: 12),

          _sectionNameEditor("Education Section", educationSectionName, (
            value,
          ) {
            setDialogState(() {
              educationSectionName = value;
            });
          }),

          const SizedBox(height: 12),

          _sectionNameEditor("Achievements Section", achievementsSectionName, (
            value,
          ) {
            setDialogState(() {
              achievementsSectionName = value;
            });
          }),

          const SizedBox(height: 12),

          _sectionNameEditor("Strengths Section", strengthsSectionName, (
            value,
          ) {
            setDialogState(() {
              strengthsSectionName = value;
            });
          }),

          const SizedBox(height: 20),

          // Custom sections header and list
          const Text(
            "Custom Sections",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B8E7F),
            ),
          ),
          const SizedBox(height: 12),

          // Custom sections list
          ...customSections.asMap().entries.map((entry) {
            int index = entry.key;
            Map<String, String> section = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FFF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFB8E6C1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Custom Section ${index + 1}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF2D3748),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setDialogState(() {
                            sectionOrder.remove(section['id']);
                            customSections.removeAt(index);
                          });
                        },
                        icon: const Icon(
                          Icons.delete,
                          color: Colors.red,
                          size: 20,
                        ),
                        tooltip: 'Delete Section',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: section['name'],
                    onChanged: (value) {
                      setDialogState(() {
                        customSections[index]['name'] = value;
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Section Name',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: section['content'],
                    onChanged: (value) {
                      setDialogState(() {
                        customSections[index]['content'] = value;
                      });
                    },
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Section Content',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),

          const SizedBox(height: 20),

          // Reset Button
          Center(
            child: OutlinedButton(
              onPressed: () {
                setDialogState(() {
                  skillsSectionName = "SKILLS";
                  experienceSectionName = "Experience";
                  projectsSectionName = "PERSONAL PROJECTS";
                  educationSectionName = "EDUCATION";
                  achievementsSectionName = "Achievements";
                  strengthsSectionName = "Strengths";
                  // reset skill subcategory labels as well
                  skillsLanguagesLabel = "Languages:";
                  skillsFrameworksLabel = "Frameworks and Database:";
                  skillsToolsLabel = "Tools and Technologies:";
                  skillsOthersLabel = "Others:";
                  extraSkillRows.clear();
                  _clearFieldControllersByPrefix('skills.');
                  customSections.clear();
                  sectionOrder = [
                    'Skills',
                    'Experience',
                    'Projects',
                    'Education',
                    'Achievements',
                    'Strengths',
                  ];
                });
              },
              child: const Text("Reset to Default"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionNameEditor(
    String label,
    String currentValue,
    Function(String) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: Color(0xFF2D3748),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF0FFF4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFB8E6C1)),
          ),
          child: TextFormField(
            initialValue: currentValue,
            onChanged: onChanged,
            style: const TextStyle(color: Color(0xFF2D3748), fontSize: 14),
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: InputBorder.none,
              hintText: "Enter section name...",
              hintStyle: TextStyle(color: Color(0xFF718096), fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionOrderTab(StateSetter setDialogState) {
    List<String> tempOrder = List.from(sectionOrder);
    final allAvailableSections = [
      'Skills',
      'Experience',
      'Projects',
      'Education',
      'Achievements',
      'Strengths',
      ...customSections
          .map((section) => section['id'])
          .whereType<String>()
          .toList(),
    ];
    final missingSections = allAvailableSections
        .where((id) => !tempOrder.contains(id))
        .toList();

    if (_sectionToAddFromOrder != null &&
        !missingSections.contains(_sectionToAddFromOrder)) {
      _sectionToAddFromOrder = null;
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Drag sections to reorder them:",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _sectionToAddFromOrder,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Add section to order',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: missingSections
                      .map(
                        (id) => DropdownMenuItem<String>(
                          value: id,
                          child: Text(_getSectionDisplayName(id)),
                        ),
                      )
                      .toList(),
                  onChanged: missingSections.isEmpty
                      ? null
                      : (value) {
                          setDialogState(() {
                            _sectionToAddFromOrder = value;
                          });
                        },
                  hint: const Text('No hidden sections'),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _sectionToAddFromOrder == null
                      ? null
                      : () {
                          setDialogState(() {
                            sectionOrder.add(_sectionToAddFromOrder!);
                            _sectionToAddFromOrder = null;
                          });
                        },
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B8E7F),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ReorderableListView.builder(
              itemCount: tempOrder.length,
              itemBuilder: (context, index) {
                return Container(
                  key: ValueKey(tempOrder[index]),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FFF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFB8E6C1)),
                  ),
                  child: ListTile(
                    leading: const Icon(
                      Icons.drag_handle,
                      color: Color(0xFF6B8E7F),
                    ),
                    title: Text(
                      _getSectionDisplayName(tempOrder[index]),
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "${index + 1}",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF718096),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Delete from order',
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                            size: 20,
                          ),
                          onPressed: tempOrder.length <= 1
                              ? null
                              : () {
                                  setDialogState(() {
                                    sectionOrder.remove(tempOrder[index]);
                                  });
                                },
                        ),
                      ],
                    ),
                  ),
                );
              },
              onReorder: (oldIndex, newIndex) {
                setDialogState(() {
                  if (newIndex > oldIndex) {
                    newIndex--;
                  }
                  final item = tempOrder.removeAt(oldIndex);
                  tempOrder.insert(newIndex, item);
                  sectionOrder = tempOrder; // Update the main order
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getSectionDisplayName(String sectionId) {
    switch (sectionId) {
      case 'Skills':
        return skillsSectionName;
      case 'Experience':
        return experienceSectionName;
      case 'Projects':
        return projectsSectionName;
      case 'Education':
        return educationSectionName;
      case 'Achievements':
        return achievementsSectionName;
      case 'Strengths':
        return strengthsSectionName;
      default:
        // Check if it's a custom section
        var customSection = customSections.firstWhere(
          (cs) => cs['id'] == sectionId,
          orElse: () => {},
        );
        return customSection.isNotEmpty ? customSection['name']! : sectionId;
    }
  }

  Widget _buildCustomSection(Map<String, String> section) {
    if (section['content']?.trim().isEmpty ?? true) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          section['name']!,
          style: TextStyle(
            fontSize: sectionHeaderSize,
            fontWeight: FontWeight.bold,
            color: sectionHeaderColor,
          ),
        ),
        const SizedBox(height: 8),
        _buildSmartText(
          section['content']!,
          TextStyle(fontSize: bodyTextSize, color: bodyTextColor, height: 1.4),
        ),
      ],
    );
  }

  // PDF Generation and Copy Functions
  Future<void> _downloadAsPDF() async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      data.name.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: nameTextSize,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    // Use ASCII separator to avoid unsupported Unicode glyphs in PDF fonts.
                    pw.Text(
                      [
                        data.email,
                        if (data.linkedinName.trim().isNotEmpty)
                          data.linkedinName,
                        if (data.githubName.trim().isNotEmpty) data.githubName,
                        _formattedPhone(),
                      ].where((item) => item.trim().isNotEmpty).join(' | '),
                      style: pw.TextStyle(fontSize: bodyTextSize),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 12),
                    pw.Container(
                      height: 1,
                      width: double.infinity,
                      color: PdfColors.black,
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),

                // Sections in order
                ...sectionOrder.map((section) {
                  switch (section) {
                    case 'Skills':
                      return _buildPDFSkillsSection();
                    case 'Experience':
                      return _buildPDFExperienceSection();
                    case 'Projects':
                      return _buildPDFProjectsSection();
                    case 'Education':
                      return _buildPDFEducationSection();
                    case 'Achievements':
                      return _buildPDFAchievementsSection();
                    case 'Strengths':
                      return _buildPDFStrengthsSection();
                    default:
                      var customSection = customSections.firstWhere(
                        (cs) => cs['id'] == section,
                        orElse: () => {},
                      );
                      if (customSection.isNotEmpty) {
                        return _buildPDFCustomSection(customSection);
                      }
                      return pw.SizedBox();
                  }
                }).toList(),
              ],
            );
          },
        ),
      );

      // Show save dialog
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: '${data.name.replaceAll(' ', '_')}_Resume.pdf',
      );

      _showSuccessMessage('PDF download initiated successfully!');
    } catch (e) {
      _showErrorMessage('Error generating PDF: $e');
    }
  }

  Future<void> _copyAsLink() async {
    try {
      String resumeLink = _generateResumeLink();
      await Clipboard.setData(ClipboardData(text: resumeLink));
      _showSuccessMessage('Resume link copied to clipboard!');
    } catch (e) {
      _showErrorMessage('Error generating resume link: $e');
    }
  }

  String _generateResumeLink() {
    final resumeData = _buildResumeStateMap();

    // Convert to JSON and encode
    String jsonString = json.encode(resumeData);
    String encodedData = base64Url.encode(utf8.encode(jsonString));

    // Create shareable link (you can customize this URL)
    String baseUrl = 'https://resume-builder-share.com/view';
    String shareableLink = '$baseUrl?data=$encodedData';

    return shareableLink;
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // PDF Section Builders
  pw.Widget _buildPDFSkillsSection() {
    final visibleSkillRows = _getSkillRows()
        .where((row) => row['skills']!.trim().isNotEmpty)
        .toList();

    if (visibleSkillRows.isEmpty) {
      return pw.SizedBox();
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          skillsSectionName,
          style: pw.TextStyle(
            fontSize: sectionHeaderSize,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        ...visibleSkillRows.asMap().entries.map((entry) {
          final index = entry.key;
          final row = entry.value;
          return pw.Padding(
            padding: pw.EdgeInsets.only(top: index == 0 ? 0 : 4),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 1,
                  child: pw.Text(
                    row['heading']!.trim(),
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: bodyTextSize,
                    ),
                  ),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(
                    row['skills']!.trim(),
                    style: pw.TextStyle(fontSize: bodyTextSize),
                  ),
                ),
              ],
            ),
          );
        }),
        pw.SizedBox(height: 20),
      ],
    );
  }

  pw.Widget _buildPDFExperienceSection() {
    if (data.experiences.every((exp) => exp.companyName.trim().isEmpty)) {
      return pw.SizedBox();
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          experienceSectionName,
          style: pw.TextStyle(
            fontSize: sectionHeaderSize,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        ...data.experiences
            .where((exp) => exp.companyName.trim().isNotEmpty)
            .map((experience) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Company name and location row
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        experience.companyName,
                        style: pw.TextStyle(
                          fontSize: bodyTextSize + 1,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        experience.location,
                        style: pw.TextStyle(fontSize: bodyTextSize),
                      ),
                    ],
                  ),
                  // Job title and duration row
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        experience.jobTitle,
                        style: pw.TextStyle(
                          fontSize: bodyTextSize,
                          fontStyle: pw.FontStyle.italic,
                        ),
                      ),
                      pw.Text(
                        experience.duration,
                        style: pw.TextStyle(fontSize: bodyTextSize),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  _buildPDFBulletList(experience.description),
                  pw.SizedBox(height: 12),
                ],
              );
            })
            .toList(),
        pw.SizedBox(height: 8),
      ],
    );
  }

  pw.Widget _buildPDFProjectsSection() {
    if (data.projects.every(
      (proj) => proj.title.trim().isEmpty && proj.description.trim().isEmpty,
    )) {
      return pw.SizedBox();
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          projectsSectionName,
          style: pw.TextStyle(
            fontSize: sectionHeaderSize,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        ...data.projects
            .where(
              (proj) =>
                  proj.title.trim().isNotEmpty ||
                  proj.description.trim().isNotEmpty,
            )
            .map((
          project,
        ) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (project.title.trim().isNotEmpty)
                pw.Text(
                  project.title,
                  style: pw.TextStyle(
                    fontSize: bodyTextSize + 1,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              if (project.title.trim().isNotEmpty &&
                  project.description.trim().isNotEmpty)
                pw.SizedBox(height: 4),
              if (project.description.trim().isNotEmpty)
                _buildPDFBulletList(project.description),
              pw.SizedBox(height: 12),
            ],
          );
        }).toList(),
        pw.SizedBox(height: 8),
      ],
    );
  }

  pw.Widget _buildPDFEducationSection() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          educationSectionName,
          style: pw.TextStyle(
            fontSize: sectionHeaderSize,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        if (data.university.trim().isNotEmpty)
          _buildPDFEducationItem(
            data.university,
            "GPA: ${data.universityGPA}",
            data.universityLocation,
            data.universityDuration,
          ),
        if (data.college.trim().isNotEmpty)
          _buildPDFEducationItem(
            data.college,
            "GPA: ${data.collegeGPA}",
            data.collegeLocation,
            data.collegeDuration,
          ),
        if (data.highSchool.trim().isNotEmpty)
          _buildPDFEducationItem(
            data.highSchool,
            "GPA: ${data.highSchoolGPA}",
            data.highSchoolLocation,
            data.highSchoolDuration,
          ),
        pw.SizedBox(height: 12),
      ],
    );
  }

  pw.Widget _buildPDFEducationItem(
    String institution,
    String gpa,
    String location,
    String duration,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Institution and location row
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Text(
                  institution,
                  style: pw.TextStyle(
                    fontSize: bodyTextSize + 1,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Text(location, style: pw.TextStyle(fontSize: bodyTextSize)),
            ],
          ),
          // GPA and duration row
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                gpa,
                style: pw.TextStyle(
                  fontSize: bodyTextSize,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
              pw.Text(duration, style: pw.TextStyle(fontSize: bodyTextSize)),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPDFBulletList(String text) {
    if (text.trim().isEmpty) return pw.SizedBox();

    String normalizeLine(String line) {
      // Strip common leading bullet symbols; row bullet is rendered as a shape.
      final withoutLeadingBullet = line.replaceFirst(
        RegExp(r'^[\s\-\u2022\u25CF\u25E6\*]+'),
        '',
      );
      // Replace inline bullet glyphs to avoid missing-glyph boxes in PDF fonts.
      return withoutLeadingBullet.replaceAll('\u2022', '-').trim();
    }

    final lines = text
        .split(RegExp(r'[\r\n]+'))
        .map(normalizeLine)
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return pw.SizedBox();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: lines.map((line) {
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Draw bullet as a shape so rendering does not depend on font glyph support.
              pw.Container(
                width: 8,
                height: bodyTextSize + 2,
                alignment: pw.Alignment.topCenter,
                child: pw.Container(
                  width: 4,
                  height: 4,
                  margin: const pw.EdgeInsets.only(top: 5),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.black,
                    shape: pw.BoxShape.circle,
                  ),
                ),
              ),
              pw.SizedBox(width: 4),
              pw.Expanded(
                child: pw.Text(
                  line,
                  style: pw.TextStyle(fontSize: bodyTextSize),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  pw.Widget _buildPDFAchievementsSection() {
    if (data.achievements.every((ach) => ach.trim().isEmpty)) {
      return pw.SizedBox();
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          achievementsSectionName,
          style: pw.TextStyle(
            fontSize: sectionHeaderSize,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        ...data.achievements.where((ach) => ach.trim().isNotEmpty).map((
          achievement,
        ) {
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 6,
                  height: 6,
                  margin: const pw.EdgeInsets.only(top: 6, right: 6),
                  decoration: const pw.BoxDecoration(
                    shape: pw.BoxShape.circle,
                    color: PdfColors.black,
                  ),
                ),
                pw.Expanded(
                  child: pw.Text(
                    achievement,
                    style: pw.TextStyle(fontSize: bodyTextSize),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        pw.SizedBox(height: 8),
      ],
    );
  }

  pw.Widget _buildPDFStrengthsSection() {
    if (data.strengths.every((str) => str.trim().isEmpty)) {
      return pw.SizedBox();
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          strengthsSectionName,
          style: pw.TextStyle(
            fontSize: sectionHeaderSize,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        ...data.strengths.where((str) => str.trim().isNotEmpty).map((strength) {
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 6,
                  height: 6,
                  margin: const pw.EdgeInsets.only(top: 6, right: 6),
                  decoration: const pw.BoxDecoration(
                    shape: pw.BoxShape.circle,
                    color: PdfColors.black,
                  ),
                ),
                pw.Expanded(
                  child: pw.Text(
                    strength,
                    style: pw.TextStyle(fontSize: bodyTextSize),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        pw.SizedBox(height: 8),
      ],
    );
  }

  pw.Widget _buildPDFCustomSection(Map<String, String> section) {
    if (section['content']?.trim().isEmpty ?? true) {
      return pw.SizedBox();
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          section['name']!,
          style: pw.TextStyle(
            fontSize: sectionHeaderSize,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          section['content']!,
          style: pw.TextStyle(fontSize: bodyTextSize),
        ),
        pw.SizedBox(height: 20),
      ],
    );
  }

  Widget _buildResumeHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Name
        _buildSmartText(
          data.name.toUpperCase(),
          TextStyle(
            fontSize: nameTextSize,
            fontWeight: FontWeight.bold,
            color: nameTextColor,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 8),

        // Contact Information Row
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          children: [
            _contactItem(
              "",
              data.email,
              contactLinkColor,
              isClickable: true,
              url: "mailto:${data.email}",
            ),
            if (data.linkedinName.trim().isNotEmpty &&
                data.linkedin.trim().isNotEmpty)
              _contactItem(
                "",
                data.linkedinName,
                contactLinkColor,
                isClickable: true,
                url: data.linkedin.startsWith('http')
                    ? data.linkedin
                    : 'https://${data.linkedin}',
              ),
            if (data.githubName.trim().isNotEmpty &&
                data.github.trim().isNotEmpty)
              _contactItem(
                "",
                data.githubName,
                contactLinkColor,
                isClickable: true,
                url: data.github.startsWith('http')
                    ? data.github
                    : 'https://${data.github}',
              ),
            _contactItem("", _formattedPhone(), bodyTextColor),
          ],
        ),

        // Line separator
        const SizedBox(height: 12),
        Container(height: 1, width: double.infinity, color: nameTextColor),
      ],
    );
  }

  Widget _contactItem(
    String icon,
    String text,
    Color color, {
    bool isClickable = false,
    String? url,
  }) {
    if (text.trim().isEmpty) return const SizedBox();

    Widget textWidget = Text(
      text,
      style: TextStyle(
        fontSize: bodyTextSize,
        color: color,
        decoration: isClickable
            ? TextDecoration.underline
            : TextDecoration.none,
      ),
      overflow: TextOverflow.ellipsis,
    );

    if (isClickable && url != null && url.isNotEmpty) {
      return GestureDetector(
        onTap: () async {
          try {
            final Uri uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri);
            } else {
              if (context.mounted) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Error'),
                    content: Text('Could not open: $url'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              }
            }
          } catch (e) {
            if (context.mounted) {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Error'),
                  content: Text('Invalid URL: $url'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            }
          }
        },
        child: textWidget,
      );
    }

    return textWidget;
  }

  Widget _buildSkillsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          skillsSectionName,
          style: TextStyle(
            fontSize: sectionHeaderSize,
            fontWeight: FontWeight.bold,
            color: sectionHeaderColor,
          ),
        ),
        const SizedBox(height: 8),
        ..._getSkillRows().map(
          (row) => _skillCategory(row['heading']!, row['skills']!),
        ),
      ],
    );
  }

  Widget _skillCategory(String category, String skills) {
    if (skills.trim().isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 1,
            child: Text(
              category,
              style: TextStyle(
                fontSize: bodyTextSize,
                color: bodyTextColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: _buildSmartText(
              skills,
              TextStyle(
                fontSize: bodyTextSize,
                color: bodyTextColor,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExperienceSection() {
    if (data.experiences.isEmpty ||
        data.experiences.every((exp) => exp.companyName.trim().isEmpty)) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          experienceSectionName,
          style: TextStyle(
            fontSize: sectionHeaderSize,
            fontWeight: FontWeight.bold,
            color: sectionHeaderColor,
          ),
        ),
        const SizedBox(height: 8),
        ...data.experiences
            .where((exp) => exp.companyName.trim().isNotEmpty)
            .map(
              (experience) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          experience.companyName,
                          style: TextStyle(
                            fontSize: bodyTextSize + 1,
                            fontWeight: FontWeight.bold,
                            color: bodyTextColor,
                          ),
                        ),
                        Text(
                          experience.location,
                          style: TextStyle(
                            fontSize: bodyTextSize,
                            color: bodyTextColor.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          experience.jobTitle,
                          style: TextStyle(
                            fontSize: bodyTextSize,
                            fontStyle: FontStyle.italic,
                            color: bodyTextColor.withOpacity(0.8),
                          ),
                        ),
                        Text(
                          experience.duration,
                          style: TextStyle(
                            fontSize: bodyTextSize,
                            color: bodyTextColor.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _buildSmartText(
                      experience.description,
                      TextStyle(
                        fontSize: bodyTextSize,
                        color: bodyTextColor,
                        height: 1.3,
                      ),
                      softWrap: true,
                      overflow: TextOverflow.visible,
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ],
    );
  }

  Widget _buildProjectsSection() {
    if (data.projects.isEmpty ||
        data.projects.every(
          (proj) =>
              proj.title.trim().isEmpty && proj.description.trim().isEmpty,
        )) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          projectsSectionName,
          style: TextStyle(
            fontSize: sectionHeaderSize,
            fontWeight: FontWeight.bold,
            color: sectionHeaderColor,
          ),
        ),
        const SizedBox(height: 8),
        ...data.projects
            .where(
              (proj) =>
                  proj.title.trim().isNotEmpty ||
                  proj.description.trim().isNotEmpty,
            )
            .map(
              (project) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (project.title.trim().isNotEmpty)
                      Text(
                        project.title,
                        style: TextStyle(
                          fontSize: bodyTextSize + 1,
                          fontWeight: FontWeight.bold,
                          color: bodyTextColor,
                        ),
                      ),
                    if (project.title.trim().isNotEmpty &&
                        project.description.trim().isNotEmpty)
                      const SizedBox(height: 4),
                    if (project.description.trim().isNotEmpty)
                      _buildSmartText(
                        project.description,
                        TextStyle(
                          fontSize: bodyTextSize,
                          color: bodyTextColor,
                          height: 1.4,
                        ),
                        softWrap: true,
                        overflow: TextOverflow.visible,
                      ),
                  ],
                ),
              ),
            )
            .toList(),
      ],
    );
  }

  Widget _buildEducationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          educationSectionName,
          style: TextStyle(
            fontSize: sectionHeaderSize,
            fontWeight: FontWeight.bold,
            color: sectionHeaderColor,
          ),
        ),
        const SizedBox(height: 8),
        if (data.university.trim().isNotEmpty)
          _educationItem(
            data.university,
            "GPA: ${data.universityGPA}",
            data.universityLocation,
            data.universityDuration,
          ),
        if (data.college.trim().isNotEmpty)
          _educationItem(
            data.college,
            "GPA: ${data.collegeGPA}",
            data.collegeLocation,
            data.collegeDuration,
          ),
        if (data.highSchool.trim().isNotEmpty)
          _educationItem(
            data.highSchool,
            "GPA: ${data.highSchoolGPA}",
            data.highSchoolLocation,
            data.highSchoolDuration,
          ),
      ],
    );
  }

  Widget _educationItem(
    String institution,
    String gpa,
    String location,
    String duration,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  institution,
                  style: TextStyle(
                    fontSize: bodyTextSize + 1,
                    fontWeight: FontWeight.bold,
                    color: bodyTextColor,
                  ),
                ),
              ),
              Text(
                location,
                style: TextStyle(
                  fontSize: bodyTextSize,
                  color: bodyTextColor.withOpacity(0.8),
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                gpa,
                style: TextStyle(
                  fontSize: bodyTextSize,
                  fontStyle: FontStyle.italic,
                  color: bodyTextColor.withOpacity(0.8),
                ),
              ),
              Text(
                duration,
                style: TextStyle(
                  fontSize: bodyTextSize,
                  color: bodyTextColor.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsSection() {
    if (data.achievements.isEmpty ||
        data.achievements.every((ach) => ach.trim().isEmpty)) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          achievementsSectionName,
          style: TextStyle(
            fontSize: sectionHeaderSize,
            fontWeight: FontWeight.bold,
            color: sectionHeaderColor,
          ),
        ),
        const SizedBox(height: 8),
        ...data.achievements
            .where((ach) => ach.trim().isNotEmpty)
            .map(
              (achievement) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _buildSmartText(
                  "• $achievement",
                  TextStyle(
                    fontSize: bodyTextSize,
                    color: bodyTextColor,
                    height: 1.4,
                  ),
                ),
              ),
            )
            .toList(),
      ],
    );
  }

  Widget _buildStrengthsSection() {
    if (data.strengths.isEmpty ||
        data.strengths.every((str) => str.trim().isEmpty)) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strengthsSectionName,
          style: TextStyle(
            fontSize: sectionHeaderSize,
            fontWeight: FontWeight.bold,
            color: sectionHeaderColor,
          ),
        ),
        const SizedBox(height: 8),
        ...data.strengths
            .where((str) => str.trim().isNotEmpty)
            .map(
              (strength) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _buildSmartText(
                  "• $strength",
                  TextStyle(
                    fontSize: bodyTextSize,
                    color: bodyTextColor,
                    height: 1.4,
                  ),
                ),
              ),
            )
            .toList(),
      ],
    );
  }

  // Inline Grammar Check functionality
  TextSpan _buildTextWithGrammarCheck(String text, TextStyle baseStyle) {
    if (text.trim().isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }

    final errors = _checkTextForErrors(text);
    if (errors.isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }

    final spans = <TextSpan>[];
    int currentIndex = 0;

    for (final error in errors) {
      final errorWord = error['error']!;
      final errorIndex = text.toLowerCase().indexOf(
        errorWord.toLowerCase(),
        currentIndex,
      );

      if (errorIndex == -1) continue;

      if (errorIndex > currentIndex) {
        spans.add(
          TextSpan(
            text: text.substring(currentIndex, errorIndex),
            style: baseStyle,
          ),
        );
      }

      spans.add(
        TextSpan(
          text: text.substring(errorIndex, errorIndex + errorWord.length),
          style: baseStyle.copyWith(
            decoration: TextDecoration.underline,
            decorationColor: Colors.red,
            decorationThickness: 2,
          ),
        ),
      );

      currentIndex = errorIndex + errorWord.length;
    }

    if (currentIndex < text.length) {
      spans.add(TextSpan(text: text.substring(currentIndex), style: baseStyle));
    }

    return TextSpan(children: spans);
  }

  Widget _buildSmartText(
    String text,
    TextStyle style, {
    TextAlign? textAlign,
    bool softWrap = true,
    TextOverflow? overflow,
  }) {
    return RichText(
      text: _buildTextWithGrammarCheck(text, style),
      textAlign: textAlign ?? TextAlign.start,
      softWrap: softWrap,
      overflow: overflow ?? TextOverflow.visible,
    );
  }

  final List<String> _commonMisspellings = {
    'teh': 'the',
    'recieve': 'receive',
    'seperate': 'separate',
    'definately': 'definitely',
    'occured': 'occurred',
    'managment': 'management',
    'developement': 'development',
    'programing': 'programming',
    'responsable': 'responsible',
    'acheivement': 'achievement',
    'experiance': 'experience',
    'sucessful': 'successful',
    'proffessional': 'professional',
    'skillz': 'skills',
    'analize': 'analyze',
    'writting': 'writing',
    'comunication': 'communication',
    'collaberation': 'collaboration',
    'intrested': 'interested',
    'knowlege': 'knowledge',
  }.entries.map((entry) => '${entry.key}:${entry.value}').toList();

  final List<String> _grammarRules = [
    'i am:I am',
    'i have:I have',
    'i can:I can',
    'i will:I will',
    'i was:I was',
    'its:it\'s (if meaning "it is")',
    'your:you\'re (if meaning "you are")',
    'there:their (for possession)',
    'affect:effect (noun vs verb)',
  ];

  List<Map<String, String>> _checkTextForErrors(String text) {
    final errors = <Map<String, String>>[];
    final lowerText = text.toLowerCase();

    for (final rule in _commonMisspellings) {
      final parts = rule.split(':');
      final wrong = parts[0];
      final correct = parts[1];

      if (lowerText.contains(wrong)) {
        errors.add({
          'type': 'Spelling',
          'error': wrong,
          'suggestion': correct,
          'message': 'Misspelled word: "$wrong" should be "$correct"',
        });
      }
    }

    for (final rule in _grammarRules) {
      final parts = rule.split(':');
      final pattern = parts[0];
      final suggestion = parts[1];

      if (lowerText.contains(pattern)) {
        errors.add({
          'type': 'Grammar',
          'error': pattern,
          'suggestion': suggestion,
          'message':
              'Grammar suggestion: Consider using "$suggestion" instead of "$pattern"',
        });
      }
    }

    if (text.trim().isNotEmpty) {
      final sentences = text.split(RegExp(r'[.!?]+'));
      for (final sentence in sentences) {
        final trimmed = sentence.trim();
        if (trimmed.isNotEmpty &&
            !trimmed[0].toUpperCase().contains(trimmed[0])) {
          errors.add({
            'type': 'Capitalization',
            'error': trimmed,
            'suggestion': trimmed[0].toUpperCase() + trimmed.substring(1),
            'message': 'Sentence should start with a capital letter',
          });
        }
      }
    }

    return errors;
  }
}
