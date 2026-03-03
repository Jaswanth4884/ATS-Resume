class ResumeData {
  String name;
  String role;
  String email;
  String phone;
  String github;
  String linkedin;
  String githubName;
  String linkedinName;
  String street;
  String city;
  String zipCode;
  
  // Skills categories
  String languages;
  String frameworks;
  String tools;
  String others;
  
  // Experience (multiple entries)
  List<ExperienceItem> experiences;
  
  // Projects (multiple entries)
  List<ProjectItem> projects;
  
  // Education
  String university;
  String universityGPA;
  String universityLocation;
  String universityDuration;
  String college;
  String collegeGPA;
  String collegeLocation;
  String collegeDuration;
  String highSchool;
  String highSchoolGPA;
  String highSchoolLocation;
  String highSchoolDuration;
  
  // Achievements & Strengths (multiple entries)
  List<String> achievements;
  List<String> strengths;

  ResumeData({
    this.name = "YOUR NAME",
    this.role = "Software Developer", 
    this.email = "youremail@gmail.com",
    this.phone = "+91-1234567890",
    this.github = "github.com/yourprofile",
    this.linkedin = "linkedin.com/in/yourprofile",
    this.githubName = "GitHub",
    this.linkedinName = "LinkedIn",
    this.street = "Street, Town, District",
    this.city = "City, State",
    this.zipCode = "500001",
    
    // Skills
    this.languages = "C, C++, Java, Python, JavaScript",
    this.frameworks = "MySQL, MongoDB, Express, ReactJS, NodeJS, Redux",
    this.tools = "OOPS, Data Structures, Git, Visual Studio Code, RESTful API, NPM, WebSockets",
    this.others = "Chrome extensions, GitHub Actions, Firebase, Webpack services, Debugging, Code reviews",
    
    // Experience
    List<ExperienceItem>? experiences,
    
    // Projects
    List<ProjectItem>? projects,
    
    // Education
    this.university = "Your University Name",
    this.universityGPA = "Your GPA",
    this.universityLocation = "City, State",
    this.universityDuration = "Graduation Date",
    
    this.college = "Your College Name", 
    this.collegeGPA = "Your GPA",
    this.collegeLocation = "City, State",
    this.collegeDuration = "Graduation Date",
    
    this.highSchool = "Your High School Name",
    this.highSchoolGPA = "Your GPA", 
    this.highSchoolLocation = "City, State",
    this.highSchoolDuration = "Graduation Date",
    
    // Achievements & Strengths
    List<String>? achievements,
    List<String>? strengths,
  }) : experiences = experiences ?? [
         ExperienceItem(
           companyName: "Company Name",
           jobTitle: "Software Developer",
           location: "Bangalore Karnataka",
           duration: "April 2023 - Present",
           description: "• Briefly describe the work you have done on your role\n• Briefly describe the work you have done on your role",
         ),
       ],
       projects = projects ?? [
         ProjectItem(
           title: "Your Project Title",
           description: "Briefly describe your project, focusing on the problem it solved and the technologies you used. Use action verbs to describe your contributions and responsibilities.",
         ),
       ],
       achievements = achievements ?? [
         "List any awards, contest rankings, or scholarships you have received.",
         "Describe any leadership roles or community contributions you made.",
       ],
       strengths = strengths ?? [
         "Proficient in problem solving, self-critical, and have loyalty software solutions.",
         "Quick to learn and adapt to new technologies and frameworks, always staying updated with industry trends.",
       ];
}

class ExperienceItem {
  String companyName;
  String jobTitle;
  String location;
  String duration;
  String description;

  ExperienceItem({
    this.companyName = "",
    this.jobTitle = "",
    this.location = "",
    this.duration = "",
    this.description = "",
  });
}

class ProjectItem {
  String title;
  String description;

  ProjectItem({
    this.title = "",
    this.description = "",
  });
}