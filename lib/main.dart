import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:convert';
import 'resume_model.dart';
import 'loginscreen.dart';

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
  
  // Custom sections (user-added)
  List<Map<String, String>> customSections = [];
  
  // Add section form state
  bool _showAddSectionForm = false;
  final TextEditingController _newSectionNameController = TextEditingController();
  final TextEditingController _newSectionContentController = TextEditingController();
  
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

  @override
  void dispose() {
    _newSectionNameController.dispose();
    _newSectionContentController.dispose();
    super.dispose();
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
          return Row(
            children: [
              // LEFT — RESUME FORM (50%)
              Expanded(
                flex: 1,
                child: _buildFormSection(),
              ),
              
              // DIVIDER
              Container(
                width: 1,
                color: const Color(0xFFE2E8F0),
              ),
              
              // RIGHT — PREVIEW SECTION (50%)
              Expanded(
                flex: 1,
                child: _buildPreviewSection(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFormSection() {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          // Header with Extra Features Button
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
              ),
            ),
            child: Row(
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              padding: const EdgeInsets.all(20),
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
                _modernTextField("Full Name", Icons.person, (v) => setState(() => data.name = v)),
                _modernTextField("Phone", Icons.phone, (v) => setState(() => data.phone = v)),
                _modernTextField("Email", Icons.email, (v) => setState(() => data.email = v)),
                _modernTextField("LinkedIn URL", Icons.link, (v) => setState(() => data.linkedin = v)),
                _modernTextField("LinkedIn Display Name", Icons.business, (v) => setState(() => data.linkedinName = v)),
                _modernTextField("GitHub URL", Icons.code, (v) => setState(() => data.github = v)),
                _modernTextField("GitHub Display Name", Icons.code_outlined, (v) => setState(() => data.githubName = v)),
              ],
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
                _modernTextField("Languages", Icons.language, (v) => setState(() => data.languages = v)),
                _modernTextField("Frameworks and Databases", Icons.storage, (v) => setState(() => data.frameworks = v)),
                _modernTextField("Tools and Technologies", Icons.build, (v) => setState(() => data.tools = v)),
                _modernTextField("Others", Icons.more_horiz, (v) => setState(() => data.others = v)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _modernTextField(String label, IconData icon, Function(String) onChanged, {int lines = 1}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextField(
        maxLines: lines,
        onChanged: onChanged,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF2D3748),
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(
            icon,
            color: const Color(0xFF6B8E7F),
            size: 20,
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
          fillColor: const Color(0xFFF7FAFC),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
              color: Colors.redAccent,
              width: 1.5,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
              color: Colors.red,
              width: 2,
            ),
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
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                tooltip: 'Remove Experience',
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _modernTextField("Company Name", Icons.business, (v) => setState(() => experience.companyName = v)),
                        _modernTextField("Job Title", Icons.work, (v) => setState(() => experience.jobTitle = v)),
                        _modernTextField("Location", Icons.location_on, (v) => setState(() => experience.location = v)),
                        _modernTextField("Duration", Icons.schedule, (v) => setState(() => experience.duration = v)),
                        _modernTextField("Description", Icons.description, (v) => setState(() => experience.description = v), lines: 3),
                      ],
                    ),
                  );
                }).toList(),
                _modernAddButton("Add Experience", Icons.add_business, _addExperience),
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
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                tooltip: 'Remove Project',
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _modernTextField("Project Title", Icons.title, (v) => setState(() => project.title = v)),
                        _modernTextField("Project Description", Icons.description, (v) => setState(() => project.description = v), lines: 3),
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
                      _modernTextField("University Name", Icons.account_balance, (v) => setState(() => data.university = v)),
                      _modernTextField("University GPA", Icons.grade, (v) => setState(() => data.universityGPA = v)),
                      _modernTextField("University Location", Icons.location_on, (v) => setState(() => data.universityLocation = v)),
                      _modernTextField("University Duration", Icons.schedule, (v) => setState(() => data.universityDuration = v)),
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
                      _modernTextField("College Name", Icons.school, (v) => setState(() => data.college = v)),
                      _modernTextField("College GPA", Icons.grade, (v) => setState(() => data.collegeGPA = v)),
                      _modernTextField("College Location", Icons.location_on, (v) => setState(() => data.collegeLocation = v)),
                      _modernTextField("College Duration", Icons.schedule, (v) => setState(() => data.collegeDuration = v)),
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
                      _modernTextField("High School Name", Icons.school, (v) => setState(() => data.highSchool = v)),
                      _modernTextField("High School GPA", Icons.grade, (v) => setState(() => data.highSchoolGPA = v)),
                      _modernTextField("High School Location", Icons.location_on, (v) => setState(() => data.highSchoolLocation = v)),
                      _modernTextField("High School Duration", Icons.schedule, (v) => setState(() => data.highSchoolDuration = v)),
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
                          child: _modernTextField("Achievement ${index + 1}", Icons.star_outline, (v) => setState(() => data.achievements[index] = v)),
                        ),
                        if (data.achievements.length > 1)
                          IconButton(
                            onPressed: () => _removeAchievement(index),
                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                            tooltip: 'Remove Achievement',
                          ),
                      ],
                    ),
                  );
                }).toList(),
                _modernAddButton("Add Achievement", Icons.add_circle_outline, _addAchievement),
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
                          child: _modernTextField("Strength ${index + 1}", Icons.psychology, (v) => setState(() => data.strengths[index] = v)),
                        ),
                        if (data.strengths.length > 1)
                          IconButton(
                            onPressed: () => _removeStrength(index),
                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                            tooltip: 'Remove Strength',
                          ),
                      ],
                    ),
                  );
                }).toList(),
                _modernAddButton("Add Strength", Icons.add_circle_outline, _addStrength),
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
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF6B8E7F),
          side: const BorderSide(
            color: Color(0xFF6B8E7F),
            width: 1.5,
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          backgroundColor: const Color(0xFF6B8E7F).withOpacity(0.05),
        ),
      ),
    );
  }

  Widget _buildExperienceCard2() {
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
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                tooltip: 'Remove Experience',
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _modernTextField("Company Name", Icons.business, (v) => setState(() => experience.companyName = v)),
                        _modernTextField("Job Title", Icons.work, (v) => setState(() => experience.jobTitle = v)),
                        _modernTextField("Location", Icons.location_on, (v) => setState(() => experience.location = v)),
                        _modernTextField("Duration", Icons.schedule, (v) => setState(() => experience.duration = v)),
                        _modernTextField("Description", Icons.description, (v) => setState(() => experience.description = v), lines: 3),
                      ],
                    ),
                  );
                }).toList(),
                _modernAddButton("Add Experience", Icons.add_business, _addExperience),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _oldBuildEditorSection() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Personal Information (collapsible)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => setState(() => isPersonalExpanded = !isPersonalExpanded),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Personal Information",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
                Icon(
                  isPersonalExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                  color: const Color(0xFF2D3748),
                ),
              ],
            ),
          ),
        ),
        if (isPersonalExpanded) ...[
          _customTextField("Full Name", (v) => setState(() => data.name = v)),
          _customTextField("Phone", (v) => setState(() => data.phone = v)),
          _customTextField("Email", (v) => setState(() => data.email = v)),
          _customTextField("LinkedIn URL", (v) => setState(() => data.linkedin = v)),
          _customTextField("LinkedIn Display Name", (v) => setState(() => data.linkedinName = v)),
          _customTextField("GitHub URL", (v) => setState(() => data.github = v)),
          _customTextField("GitHub Display Name", (v) => setState(() => data.githubName = v)),
        ],
        const SizedBox(height: 20),
        
        // Skills (collapsible)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => setState(() => isSkillsExpanded = !isSkillsExpanded),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Skills",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
                Icon(
                  isSkillsExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                  color: const Color(0xFF2D3748),
                ),
              ],
            ),
          ),
        ),
        if (isSkillsExpanded) ...[  
          _customTextField("Languages", (v) => setState(() => data.languages = v)),
          _customTextField("Frameworks and Databases", (v) => setState(() => data.frameworks = v)),
          _customTextField("Tools and Technologies", (v) => setState(() => data.tools = v)),
          _customTextField("Others", (v) => setState(() => data.others = v)),
        ],
        
        const SizedBox(height: 20),
        
        // Experience (collapsible)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => setState(() => isExperienceExpanded = !isExperienceExpanded),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Experience",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
                Icon(
                  isExperienceExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                  color: const Color(0xFF2D3748),
                ),
              ],
            ),
          ),
        ),
        if (isExperienceExpanded) ...[
          ...data.experiences.asMap().entries.map((entry) {
            int index = entry.key;
            ExperienceItem experience = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FFF4),
                borderRadius: BorderRadius.circular(8),
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
                          ),
                        ),
                      ),
                      if (data.experiences.length > 1)
                        IconButton(
                          onPressed: () => _removeExperience(index),
                          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _customTextField("Company Name", (v) => setState(() => experience.companyName = v)),
                  _customTextField("Job Title", (v) => setState(() => experience.jobTitle = v)),
                  _customTextField("Location", (v) => setState(() => experience.location = v)),
                  _customTextField("Duration", (v) => setState(() => experience.duration = v)),
                  _customTextField("Description", (v) => setState(() => experience.description = v), lines: 3),
                ],
              ),
            );
          }).toList(),
          _addButton("Add Experience", _addExperience),
        ],
        
        const SizedBox(height: 20),
        
        // Projects (collapsible)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => setState(() => isProjectsExpanded = !isProjectsExpanded),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Projects",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
                Icon(
                  isProjectsExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                  color: const Color(0xFF2D3748),
                ),
              ],
            ),
          ),
        ),
        if (isProjectsExpanded) ...[
          ...data.projects.asMap().entries.map((entry) {
            int index = entry.key;
            ProjectItem project = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FFF4),
                borderRadius: BorderRadius.circular(8),
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
                          ),
                        ),
                      ),
                      if (data.projects.length > 1)
                        IconButton(
                          onPressed: () => _removeProject(index),
                          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _customTextField("Project Title", (v) => setState(() => project.title = v)),
                  _customTextField("Project Description", (v) => setState(() => project.description = v), lines: 3),
                ],
              ),
            );
          }).toList(),
          _addButton("Add Project", _addProject),
        ],
        const SizedBox(height: 20),

        // Education (collapsible)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => setState(() => isEducationExpanded = !isEducationExpanded),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Education",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
                Icon(
                  isEducationExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                  color: const Color(0xFF2D3748),
                ),
              ],
            ),
          ),
        ),
        if (isEducationExpanded) ...[
          // University block
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFBFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFE2E8F0),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: const [
                    Expanded(
                      child: Text(
                        "University",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3748),
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _customTextField("University Name", (v) => setState(() => data.university = v)),
                _customTextField("University GPA", (v) => setState(() => data.universityGPA = v)),
                _customTextField("University Location", (v) => setState(() => data.universityLocation = v)),
                _customTextField("University Duration", (v) => setState(() => data.universityDuration = v)),
              ],
            ),
          ),

          // College block
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFBFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFE2E8F0),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: const [
                    Expanded(
                      child: Text(
                        "College",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3748),
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _customTextField("College Name", (v) => setState(() => data.college = v)),
                _customTextField("College GPA", (v) => setState(() => data.collegeGPA = v)),
                _customTextField("College Location", (v) => setState(() => data.collegeLocation = v)),
                _customTextField("College Duration", (v) => setState(() => data.collegeDuration = v)),
              ],
            ),
          ),

          // High School block
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFBFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFE2E8F0),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: const [
                    Expanded(
                      child: Text(
                        "High School",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3748),
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _customTextField("High School Name", (v) => setState(() => data.highSchool = v)),
                _customTextField("High School GPA", (v) => setState(() => data.highSchoolGPA = v)),
                _customTextField("High School Location", (v) => setState(() => data.highSchoolLocation = v)),
                _customTextField("High School Duration", (v) => setState(() => data.highSchoolDuration = v)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        
        // Achievements (collapsible)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => setState(() => isAchievementsExpanded = !isAchievementsExpanded),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Achievements",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
                Icon(
                  isAchievementsExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                  color: const Color(0xFF2D3748),
                ),
              ],
            ),
          ),
        ),
        if (isAchievementsExpanded) ...[
          ...data.achievements.asMap().entries.map((entry) {
            int index = entry.key;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: _customTextField("Achievement ${index + 1}", (v) => setState(() => data.achievements[index] = v)),
                  ),
                  if (data.achievements.length > 1)
                    IconButton(
                      onPressed: () => _removeAchievement(index),
                      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            );
          }).toList(),
          _addButton("Add Achievement", _addAchievement),
        ],
        const SizedBox(height: 20),
        
        // Strengths (collapsible)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => setState(() => isStrengthsExpanded = !isStrengthsExpanded),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Strengths",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
                Icon(
                  isStrengthsExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                  color: const Color(0xFF2D3748),
                ),
              ],
            ),
          ),
        ),
        if (isStrengthsExpanded) ...[
          ...data.strengths.asMap().entries.map((entry) {
            int index = entry.key;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: _customTextField("Strength ${index + 1}", (v) => setState(() => data.strengths[index] = v)),
                  ),
                  if (data.strengths.length > 1)
                    IconButton(
                      onPressed: () => _removeStrength(index),
                      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            );
          }).toList(),
          _addButton("Add Strength", _addStrength),
        ],
      ],
    );
  }

  Widget _buildPreviewSection() {
    return Container(
      color: const Color(0xFFF1F5F9),
      child: Column(
        children: [
          // Header with Action Buttons
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
              ),
            ),
            child: Row(
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
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6B8E7F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                constraints: const BoxConstraints(
                  maxWidth: 600,
                ),
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
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [const Color(0xFF6B8E7F).withOpacity(0.1), const Color(0xFF557A6E).withOpacity(0.05)],
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
                                        var customSection = customSections.firstWhere(
                                          (cs) => cs['id'] == section,
                                          orElse: () => {},
                                        );
                                        if (customSection.isNotEmpty) {
                                          return Column(
                                            children: [
                                              _buildCustomSection(customSection),
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
  }

  // Add/Remove methods
  void _addExperience() {
    setState(() {
      data.experiences.add(ExperienceItem());
    });
  }

  void _removeExperience(int index) {
    setState(() {
      data.experiences.removeAt(index);
    });
  }

  void _addProject() {
    setState(() {
      data.projects.add(ProjectItem());
    });
  }

  void _removeProject(int index) {
    setState(() {
      data.projects.removeAt(index);
    });
  }

  void _addAchievement() {
    setState(() {
      data.achievements.add("");
    });
  }

  void _removeAchievement(int index) {
    setState(() {
      data.achievements.removeAt(index);
    });
  }

  void _addStrength() {
    setState(() {
      data.strengths.add("");
    });
  }

  void _removeStrength(int index) {
    setState(() {
      data.strengths.removeAt(index);
    });
  }

  // Calculate ATS Score based on resume content
  void _calculateATSScore() {
    int score = 0;
    List<String> recommendations = [];
    
    // Basic Contact Information (25 points)
    if (data.name.isNotEmpty && data.name != "YOUR NAME") score += 5;
    else recommendations.add("Add your full name");
    
    if (data.email.isNotEmpty && data.email.contains('@') && !data.email.contains("youremail")) score += 5;
    else recommendations.add("Add a valid email address");
    
    if (data.phone.isNotEmpty && !data.phone.contains("1234567890")) score += 5;
    else recommendations.add("Add your phone number");
    
    if ((data.street.isNotEmpty && !data.street.contains("Street")) || 
        (data.city.isNotEmpty && !data.city.contains("City"))) score += 5;
    else recommendations.add("Add your location details");
    
    if ((data.linkedin.isNotEmpty && !data.linkedin.contains("yourprofile")) || 
        (data.github.isNotEmpty && !data.github.contains("yourprofile"))) score += 5;
    else recommendations.add("Add LinkedIn or GitHub profile");
    
    // Skills Section (20 points)
    List<String> allSkills = [
      data.languages,
      data.frameworks, 
      data.tools,
      data.others
    ].where((skill) => skill.isNotEmpty).toList();
    
    if (allSkills.isNotEmpty) {
      score += 10;
      int skillCount = allSkills.join(',').split(',').length;
      if (skillCount >= 5) score += 5;
      else recommendations.add("Add more skills (at least 5)");
      
      // Check for technical keywords
      String skillsText = allSkills.join(' ').toLowerCase();
      List<String> techKeywords = ['python', 'java', 'javascript', 'react', 'node', 'sql', 'git', 'aws', 'docker', 'kubernetes', 'machine learning', 'data analysis', 'flutter', 'dart', 'c++', 'mongodb', 'mysql'];
      int techCount = techKeywords.where((keyword) => skillsText.contains(keyword)).length;
      if (techCount >= 3) score += 5;
      else recommendations.add("Add more technical skills with industry keywords");
    } else {
      recommendations.add("Add skills section with relevant keywords");
    }
    
    // Experience Section (25 points)
    if (data.experiences.isNotEmpty) {
      score += 10;
      
      // Check for job descriptions
      bool hasDescriptions = data.experiences.any((exp) => exp.description.isNotEmpty && !exp.description.contains("Briefly describe"));
      if (hasDescriptions) score += 8;
      else recommendations.add("Add detailed job descriptions");
      
      // Check for quantifiable achievements
      String expText = data.experiences.map((exp) => exp.description).join(' ');
      RegExp numbers = RegExp(r'\d+');
      if (numbers.hasMatch(expText)) score += 7;
      else recommendations.add("Include quantifiable achievements (numbers, percentages)");
    } else {
      recommendations.add("Add work experience section");
    }
    
    // Education Section (15 points)
    bool hasEducation = (data.university.isNotEmpty && !data.university.contains("Your University")) ||
                       (data.college.isNotEmpty && !data.college.contains("Your College")) ||
                       (data.highSchool.isNotEmpty && !data.highSchool.contains("Your High School"));
    
    if (hasEducation) {
      score += 10;
      bool hasGraduation = data.universityDuration.isNotEmpty || data.collegeDuration.isNotEmpty || data.highSchoolDuration.isNotEmpty;
      if (hasGraduation && !data.universityDuration.contains("Graduation Date")) score += 5;
      else recommendations.add("Add graduation years for education");
    } else {
      recommendations.add("Add education section");
    }
    
    // Projects Section (10 points)
    if (data.projects.isNotEmpty) {
      score += 5;
      bool hasProjectDesc = data.projects.any((proj) => proj.description.isNotEmpty && !proj.description.contains("Briefly describe"));
      if (hasProjectDesc) score += 5;
      else recommendations.add("Add detailed project descriptions");
    } else {
      recommendations.add("Consider adding relevant projects");
    }
    
    // Additional Sections (5 points)
    if (data.achievements.isNotEmpty || data.strengths.isNotEmpty) {
      score += 5;
    }
    
    // Format and Structure Bonuses
    if (data.name.length > 2 && !data.name.contains(RegExp(r'[^a-zA-Z\s]'))) score += 2;
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
        _atsScoreText = "Poor ATS compatibility - significant improvement needed";
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
                                        ? [const Color(0xFF10B981), const Color(0xFF059669)]  // Green for good scores
                                        : _atsScore >= 60 
                                          ? [const Color(0xFFF59E0B), const Color(0xFFD97706)]  // Orange for fair scores
                                          : [const Color(0xFFEF4444), const Color(0xFFDC2626)], // Red for poor scores
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (_atsScore >= 75 
                                          ? const Color(0xFF10B981)
                                          : _atsScore >= 60 
                                            ? const Color(0xFFF59E0B)
                                            : const Color(0xFFEF4444)).withOpacity(0.3),
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
                                    crossAxisAlignment: CrossAxisAlignment.start,
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
                                        Icon(Icons.check_circle, color: Color(0xFF10B981), size: 16),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            "Excellent! Your resume meets all ATS requirements.",
                                            style: TextStyle(fontSize: 13, color: Color(0xFF4A5568)),
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    ..._atsRecommendations.take(3).map(
                                      (recommendation) => Padding(
                                        padding: const EdgeInsets.only(bottom: 6),
                                        child: Row(
                                          children: [
                                            Icon(
                                              recommendation.contains('Add') || recommendation.contains('Include') 
                                                ? Icons.warning_rounded 
                                                : Icons.info_outline,
                                              color: recommendation.contains('Add') || recommendation.contains('Include')
                                                ? const Color(0xFFF59E0B)
                                                : const Color(0xFF3B82F6),
                                              size: 16,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                recommendation,
                                                style: const TextStyle(fontSize: 13, color: Color(0xFF4A5568)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ).toList(),
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
                                  Future.delayed(const Duration(milliseconds: 300), () {
                                    _showATSScoreDialog();
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text("Resume analyzed! Updated ATS score calculated."),
                                      backgroundColor: const Color(0xFF8B5CF6),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.refresh_rounded, size: 16),
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

  Widget _colorSelector(String label, Color currentColor, Function(Color) onColorChanged) {
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
                  boxShadow: isSelected ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ] : null,
                ),
                child: isSelected ? const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 20,
                ) : null,
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
              icon: Icon(_showAddSectionForm ? Icons.remove : Icons.add, size: 18),
              label: Text(_showAddSectionForm ? 'Cancel' : 'Add Custom Section'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _showAddSectionForm ? const Color(0xFF718096) : const Color(0xFF6B8E7F),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),

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
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                          if (_newSectionNameController.text.trim().isNotEmpty) {
                            setDialogState(() {
                              customSections.add({
                                'id': 'custom_${DateTime.now().millisecondsSinceEpoch}',
                                'name': _newSectionNameController.text.trim(),
                                'content': _newSectionContentController.text.trim().isEmpty 
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
          
          _sectionNameEditor("Experience Section", experienceSectionName, (value) {
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
          
          _sectionNameEditor("Education Section", educationSectionName, (value) {
            setDialogState(() {
              educationSectionName = value;
            });
          }),
          
          const SizedBox(height: 12),
          
          _sectionNameEditor("Achievements Section", achievementsSectionName, (value) {
            setDialogState(() {
              achievementsSectionName = value;
            });
          }),
          
          const SizedBox(height: 12),
          
          _sectionNameEditor("Strengths Section", strengthsSectionName, (value) {
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
                        icon: const Icon(Icons.delete, color: Colors.red, size: 20),
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
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

  Widget _sectionNameEditor(String label, String currentValue, Function(String) onChanged) {
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
            style: const TextStyle(
              color: Color(0xFF2D3748),
              fontSize: 14,
            ),
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: InputBorder.none,
              hintText: "Enter section name...",
              hintStyle: TextStyle(
                color: Color(0xFF718096),
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionOrderTab(StateSetter setDialogState) {
    List<String> tempOrder = List.from(sectionOrder);
    
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
                    trailing: Text(
                      "${index + 1}",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF718096),
                      ),
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
          TextStyle(
            fontSize: bodyTextSize,
            color: bodyTextColor,
            height: 1.4,
          ),
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
                    // Build contact info row with bullets
                    pw.Text(
                      [
                        data.email,
                        if (data.linkedinName.trim().isNotEmpty) data.linkedinName,
                        if (data.githubName.trim().isNotEmpty) data.githubName,
                        data.phone,
                      ].where((item) => item.trim().isNotEmpty).join(' • '),
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
    // Create a data object with all resume information
    Map<String, dynamic> resumeData = {
      'name': data.name,
      'role': data.role,
      'email': data.email,
      'phone': data.phone,
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
      'experiences': data.experiences.map((exp) => {
        'companyName': exp.companyName,
        'jobTitle': exp.jobTitle,
        'location': exp.location,
        'duration': exp.duration,
        'description': exp.description,
      }).toList(),
      'projects': data.projects.map((proj) => {
        'title': proj.title,
        'description': proj.description,
      }).toList(),
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
    
    // Convert to JSON and encode
    String jsonString = json.encode(resumeData);
    String encodedData = base64Url.encode(utf8.encode(jsonString));
    
    // Create shareable link (you can customize this URL)
    String baseUrl = 'https://resume-builder-share.com/view';
    String shareableLink = '$baseUrl?data=$encodedData';
    
    return shareableLink;
  }

  String _generateResumeText() {
    String text = '';
    
    // Header
    text += '${data.name.toUpperCase()}\n';
    text += '${data.email} • ${data.phone}\n';
    if (data.linkedinName.isNotEmpty && data.githubName.isNotEmpty) {
      text += '${data.linkedinName} • ${data.githubName}\n';
    }
    text += '${'=' * 50}\n\n';
    
    // Sections
    for (String section in sectionOrder) {
      switch (section) {
        case 'Skills':
          if (data.languages.isNotEmpty || data.frameworks.isNotEmpty || data.tools.isNotEmpty || data.others.isNotEmpty) {
            text += '$skillsSectionName\n';
            if (data.languages.isNotEmpty) text += 'Languages: ${data.languages}\n';
            if (data.frameworks.isNotEmpty) text += 'Frameworks and Database: ${data.frameworks}\n';
            if (data.tools.isNotEmpty) text += 'Tools and Technologies: ${data.tools}\n';
            if (data.others.isNotEmpty) text += 'Others: ${data.others}\n';
            text += '\n';
          }
          break;
        case 'Experience':
          if (data.experiences.any((exp) => exp.companyName.trim().isNotEmpty)) {
            text += '$experienceSectionName\n';
            for (var exp in data.experiences.where((e) => e.companyName.trim().isNotEmpty)) {
              text += '${exp.companyName} - ${exp.jobTitle}\n';
              text += '${exp.location} | ${exp.duration}\n';
              text += '${exp.description}\n\n';
            }
          }
          break;
        case 'Projects':
          if (data.projects.any((proj) => proj.title.trim().isNotEmpty)) {
            text += '$projectsSectionName\n';
            for (var proj in data.projects.where((p) => p.title.trim().isNotEmpty)) {
              text += 'Project Name: ${proj.title}\n';
              text += '${proj.description}\n\n';
            }
          }
          break;
        case 'Education':
          text += '$educationSectionName\n';
          if (data.university.trim().isNotEmpty) {
            text += '${data.university} | GPA: ${data.universityGPA}\n';
            text += '${data.universityLocation} | ${data.universityDuration}\n\n';
          }
          if (data.college.trim().isNotEmpty) {
            text += '${data.college} | GPA: ${data.collegeGPA}\n';
            text += '${data.collegeLocation} | ${data.collegeDuration}\n\n';
          }
          if (data.highSchool.trim().isNotEmpty) {
            text += '${data.highSchool} | GPA: ${data.highSchoolGPA}\n';
            text += '${data.highSchoolLocation} | ${data.highSchoolDuration}\n\n';
          }
          break;
        case 'Achievements':
          if (data.achievements.any((ach) => ach.trim().isNotEmpty)) {
            text += '$achievementsSectionName\n';
            for (var achievement in data.achievements.where((a) => a.trim().isNotEmpty)) {
              text += '• $achievement\n';
            }
            text += '\n';
          }
          break;
        case 'Strengths':
          if (data.strengths.any((str) => str.trim().isNotEmpty)) {
            text += '$strengthsSectionName\n';
            for (var strength in data.strengths.where((s) => s.trim().isNotEmpty)) {
              text += '• $strength\n';
            }
            text += '\n';
          }
          break;
        default:
          var customSection = customSections.firstWhere(
            (cs) => cs['id'] == section,
            orElse: () => {},
          );
          if (customSection.isNotEmpty && (customSection['content']?.trim().isNotEmpty ?? false)) {
            text += '${customSection['name']!}\n';
            text += '${customSection['content']!}\n\n';
          }
      }
    }
    
    return text;
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
    if (data.languages.isEmpty && data.frameworks.isEmpty && data.tools.isEmpty && data.others.isEmpty) {
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
        if (data.languages.isNotEmpty)
          pw.RichText(
            text: pw.TextSpan(
              style: pw.TextStyle(fontSize: bodyTextSize),
              children: [
                pw.TextSpan(
                  text: 'Languages:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.TextSpan(text: ' ${data.languages}'),
              ],
            ),
          ),
        if (data.frameworks.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.RichText(
              text: pw.TextSpan(
                style: pw.TextStyle(fontSize: bodyTextSize),
                children: [
                  pw.TextSpan(
                    text: 'Frameworks and Database:',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.TextSpan(text: ' ${data.frameworks}'),
                ],
              ),
            ),
          ),
        if (data.tools.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.RichText(
              text: pw.TextSpan(
                style: pw.TextStyle(fontSize: bodyTextSize),
                children: [
                  pw.TextSpan(
                    text: 'Tools and Technologies:',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.TextSpan(text: ' ${data.tools}'),
                ],
              ),
            ),
          ),
        if (data.others.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.RichText(
              text: pw.TextSpan(
                style: pw.TextStyle(fontSize: bodyTextSize),
                children: [
                  pw.TextSpan(
                    text: 'Others:',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.TextSpan(text: ' ${data.others}'),
                ],
              ),
            ),
          ),
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
        ...data.experiences.where((exp) => exp.companyName.trim().isNotEmpty).map((experience) {
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
        }).toList(),
        pw.SizedBox(height: 8),
      ],
    );
  }

  pw.Widget _buildPDFProjectsSection() {
    if (data.projects.every((proj) => proj.title.trim().isEmpty)) {
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
        ...data.projects.where((proj) => proj.title.trim().isNotEmpty).map((project) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Project Name: ${project.title}',
                style: pw.TextStyle(
                  fontSize: bodyTextSize + 1,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
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
          _buildPDFEducationItem(data.university, "GPA: ${data.universityGPA}", data.universityLocation, data.universityDuration),
        if (data.college.trim().isNotEmpty)
          _buildPDFEducationItem(data.college, "GPA: ${data.collegeGPA}", data.collegeLocation, data.collegeDuration),
        if (data.highSchool.trim().isNotEmpty)
          _buildPDFEducationItem(data.highSchool, "GPA: ${data.highSchoolGPA}", data.highSchoolLocation, data.highSchoolDuration),
        pw.SizedBox(height: 12),
      ],
    );
  }

  pw.Widget _buildPDFEducationItem(String institution, String gpa, String location, String duration) {
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
              pw.Text(
                location,
                style: pw.TextStyle(fontSize: bodyTextSize),
              ),
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
              pw.Text(
                duration,
                style: pw.TextStyle(fontSize: bodyTextSize),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPDFBulletList(String text) {
    if (text.trim().isEmpty) return pw.SizedBox();
    final lines = text.split(RegExp(r'[\r\n]+')).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.isEmpty) return pw.SizedBox();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: lines.map((line) {
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('• ', style: pw.TextStyle(fontSize: bodyTextSize)),
              pw.Expanded(
                child: pw.Text(line, style: pw.TextStyle(fontSize: bodyTextSize)),
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
        ...data.achievements.where((ach) => ach.trim().isNotEmpty).map((achievement) {
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
            _contactItem("", data.email, contactLinkColor, isClickable: true, url: "mailto:${data.email}"),
            if (data.linkedinName.trim().isNotEmpty && data.linkedin.trim().isNotEmpty)
              _contactItem("", data.linkedinName, contactLinkColor, isClickable: true, 
                url: data.linkedin.startsWith('http') ? data.linkedin : 'https://${data.linkedin}'),
            if (data.githubName.trim().isNotEmpty && data.github.trim().isNotEmpty)
              _contactItem("", data.githubName, contactLinkColor, isClickable: true, 
                url: data.github.startsWith('http') ? data.github : 'https://${data.github}'),
            _contactItem("", data.phone, bodyTextColor),
          ],
        ),
        
        // Line separator
        const SizedBox(height: 12),
        Container(
          height: 1,
          width: double.infinity,
          color: nameTextColor,
        ),
      ],
    );
  }

  Widget _contactItem(String icon, String text, Color color, {bool isClickable = false, String? url}) {
    if (text.trim().isEmpty) return const SizedBox();
    
    Widget textWidget = Text(
      text,
      style: TextStyle(
        fontSize: bodyTextSize,
        color: color,
        decoration: isClickable ? TextDecoration.underline : TextDecoration.none,
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
        _skillCategory("Languages:", data.languages),
        _skillCategory("Frameworks and Database:", data.frameworks),
        _skillCategory("Tools and Technologies:", data.tools),
        _skillCategory("Others:", data.others),
      ],
    );
  }

  Widget _skillCategory(String category, String skills) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            fontSize: bodyTextSize,
            color: bodyTextColor,
            height: 1.4,
          ),
          children: [
            TextSpan(
              text: category,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            _buildTextWithGrammarCheck(" $skills", TextStyle(
              fontSize: bodyTextSize,
              color: bodyTextColor,
              height: 1.4,
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildExperienceSection() {
    if (data.experiences.isEmpty || data.experiences.every((exp) => exp.companyName.trim().isEmpty)) {
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
        ...data.experiences.where((exp) => exp.companyName.trim().isNotEmpty).map((experience) => 
          Padding(
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
          )
        ).toList(),
      ],
    );
  }

  Widget _buildProjectsSection() {
    if (data.projects.isEmpty || data.projects.every((proj) => proj.title.trim().isEmpty)) {
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
        ...data.projects.where((proj) => proj.title.trim().isNotEmpty).map((project) => 
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Project Name: ${project.title}",
                  style: TextStyle(
                    fontSize: bodyTextSize + 1,
                    fontWeight: FontWeight.bold,
                    color: bodyTextColor,
                  ),
                ),
                const SizedBox(height: 4),
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
          )
        ).toList(),
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
          _educationItem(data.university, "GPA: ${data.universityGPA}", data.universityLocation, data.universityDuration),
        if (data.college.trim().isNotEmpty)
          _educationItem(data.college, "GPA: ${data.collegeGPA}", data.collegeLocation, data.collegeDuration),
        if (data.highSchool.trim().isNotEmpty)
          _educationItem(data.highSchool, "GPA: ${data.highSchoolGPA}", data.highSchoolLocation, data.highSchoolDuration),
      ],
    );
  }

  Widget _educationItem(String institution, String gpa, String location, String duration) {
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
    if (data.achievements.isEmpty || data.achievements.every((ach) => ach.trim().isEmpty)) {
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
        ...data.achievements.where((ach) => ach.trim().isNotEmpty).map((achievement) => 
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _buildSmartText(
              "• $achievement",
              TextStyle(
                fontSize: bodyTextSize,
                color: bodyTextColor,
                height: 1.4,
              ),
            ),
          )
        ).toList(),
      ],
    );
  }

  Widget _buildStrengthsSection() {
    if (data.strengths.isEmpty || data.strengths.every((str) => str.trim().isEmpty)) {
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
        ...data.strengths.where((str) => str.trim().isNotEmpty).map((strength) => 
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _buildSmartText(
              "• $strength",
              TextStyle(
                fontSize: bodyTextSize,
                color: bodyTextColor,
                height: 1.4,
              ),
            ),
          )
        ).toList(),
      ],
    );
  }

  Widget _addButton(String text, VoidCallback onPressed) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.add, size: 18),
        label: Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF6B8E7F),
          side: const BorderSide(
            color: Color(0xFF6B8E7F),
            width: 1.5,
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          surfaceTintColor: const Color(0xFF6B8E7F).withOpacity(0.05),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color(0xFF2D3748),
        ),
      ),
    );
  }

  Widget _customTextField(String label, Function(String) onChanged, {int lines = 1}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: TextField(
        maxLines: lines,
        onChanged: onChanged,
        style: const TextStyle(
          color: Color(0xFF2D3748),
          fontSize: 14,
          height: 1.5,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            color: Color(0xFF718096),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
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
          fillColor: const Color(0xFFFAFBFC),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
              color: Colors.redAccent,
              width: 1.5,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
              color: Colors.red,
              width: 2,
            ),
          ),
        ),
      ),
    );
  }

  // Inline Grammar Check functionality
  TextSpan _buildTextWithGrammarCheck(String text, TextStyle baseStyle) {
    if (text.trim().isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }
    
    List<Map<String, String>> errors = _checkTextForErrors(text);
    
    if (errors.isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }
    
    List<TextSpan> spans = [];
    String remainingText = text;
    int currentIndex = 0;
    
    for (var error in errors) {
      String errorWord = error['error']!;
      int errorIndex = remainingText.toLowerCase().indexOf(errorWord.toLowerCase(), currentIndex);
      
      if (errorIndex != -1) {
        // Add text before the error
        if (errorIndex > currentIndex) {
          spans.add(TextSpan(
            text: remainingText.substring(currentIndex, errorIndex),
            style: baseStyle,
          ));
        }
        
        // Add the error text with red underline
        spans.add(TextSpan(
          text: remainingText.substring(errorIndex, errorIndex + errorWord.length),
          style: baseStyle.copyWith(
            decoration: TextDecoration.underline,
            decorationColor: Colors.red,
            decorationThickness: 2.0,
          ),
        ));
        
        currentIndex = errorIndex + errorWord.length;
      }
    }
    
    // Add remaining text
    if (currentIndex < remainingText.length) {
      spans.add(TextSpan(
        text: remainingText.substring(currentIndex),
        style: baseStyle,
      ));
    }
    
    return TextSpan(children: spans);
  }
  
  Widget _buildSmartText(String text, TextStyle style, {TextAlign? textAlign, bool softWrap = true, TextOverflow? overflow}) {
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
    'knowlege': 'knowledge'
  }.entries.map((e) => '${e.key}:${e.value}').toList();

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
    List<Map<String, String>> errors = [];
    String lowerText = text.toLowerCase();
    
    // Check spelling
    for (String rule in _commonMisspellings) {
      List<String> parts = rule.split(':');
      String wrong = parts[0];
      String correct = parts[1];
      
      if (lowerText.contains(wrong)) {
        errors.add({
          'type': 'Spelling',
          'error': wrong,
          'suggestion': correct,
          'message': 'Misspelled word: "$wrong" should be "$correct"'
        });
      }
    }
    
    // Check basic grammar
    for (String rule in _grammarRules) {
      List<String> parts = rule.split(':');
      String pattern = parts[0];
      String suggestion = parts[1];
      
      if (lowerText.contains(pattern)) {
        errors.add({
          'type': 'Grammar',
          'error': pattern,
          'suggestion': suggestion,
          'message': 'Grammar suggestion: Consider using "$suggestion" instead of "$pattern"'
        });
      }
    }
    
    // Check for sentence structure
    if (!text.trim().isEmpty) {
      // Check if sentences start with capital letters
      List<String> sentences = text.split(RegExp(r'[.!?]+'));
      for (String sentence in sentences) {
        String trimmed = sentence.trim();
        if (trimmed.isNotEmpty && !trimmed[0].toUpperCase().contains(trimmed[0])) {
          errors.add({
            'type': 'Capitalization',
            'error': trimmed,
            'suggestion': trimmed[0].toUpperCase() + trimmed.substring(1),
            'message': 'Sentence should start with a capital letter'
          });
        }
      }
    }
    
    return errors;
  }

  Widget _buildGrammarCheckTab(StateSetter setDialogState) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Grammar & Spelling Check",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 16),
          
          Container(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _performGrammarCheck(setDialogState),
              icon: const Icon(Icons.spellcheck, size: 20),
              label: const Text("Check All Text"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B8E7F),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          const Text(
            "What this feature checks:",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 8),
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FFF4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFB8E6C1)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("• Common spelling mistakes", style: TextStyle(fontSize: 13)),
                Text("• Basic grammar issues", style: TextStyle(fontSize: 13)),
                Text("• Capitalization errors", style: TextStyle(fontSize: 13)),
                Text("• Word usage suggestions", style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _performGrammarCheck(StateSetter setDialogState) {
    List<Map<String, String>> allErrors = [];
    
    // Check all text fields
    allErrors.addAll(_checkTextForErrors(data.name));
    allErrors.addAll(_checkTextForErrors(data.email));
    allErrors.addAll(_checkTextForErrors(data.languages));
    allErrors.addAll(_checkTextForErrors(data.frameworks));
    allErrors.addAll(_checkTextForErrors(data.tools));
    allErrors.addAll(_checkTextForErrors(data.others));
    
    // Check experiences
    for (var experience in data.experiences) {
      allErrors.addAll(_checkTextForErrors(experience.companyName));
      allErrors.addAll(_checkTextForErrors(experience.jobTitle));
      allErrors.addAll(_checkTextForErrors(experience.description));
    }
    
    // Check projects
    for (var project in data.projects) {
      allErrors.addAll(_checkTextForErrors(project.title));
      allErrors.addAll(_checkTextForErrors(project.description));
    }
    
    // Check achievements and strengths
    for (String achievement in data.achievements) {
      allErrors.addAll(_checkTextForErrors(achievement));
    }
    
    for (String strength in data.strengths) {
      allErrors.addAll(_checkTextForErrors(strength));
    }
    
    // Show results
    _showGrammarCheckResults(allErrors);
  }

  void _showGrammarCheckResults(List<Map<String, String>> errors) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                errors.isEmpty ? Icons.check_circle : Icons.warning,
                color: errors.isEmpty ? Colors.green : Colors.orange,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                errors.isEmpty ? "No Issues Found!" : "Issues Detected",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
            ],
          ),
          content: Container(
            width: 400,
            height: 300,
            child: errors.isEmpty
                ? const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.sentiment_very_satisfied,
                        size: 48,
                        color: Colors.green,
                      ),
                      SizedBox(height: 16),
                      Text(
                        "Great! No spelling or grammar issues detected in your resume.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  )
                : ListView.builder(
                    itemCount: errors.length,
                    itemBuilder: (context, index) {
                      final error = errors[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: error['type'] == 'Spelling'
                                ? Colors.red.withOpacity(0.1)
                                : Colors.orange.withOpacity(0.1),
                            child: Icon(
                              error['type'] == 'Spelling'
                                  ? Icons.spellcheck
                                  : Icons.edit,
                              color: error['type'] == 'Spelling'
                                  ? Colors.red
                                  : Colors.orange,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            error['type']!,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(error['message']!),
                              const SizedBox(height: 4),
                              Text(
                                "Suggestion: ${error['suggestion']!}",
                                style: const TextStyle(
                                  color: Color(0xFF6B8E7F),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Close",
                style: TextStyle(color: Color(0xFF6B8E7F)),
              ),
            ),
          ],
        );
      },
    );
  }
}