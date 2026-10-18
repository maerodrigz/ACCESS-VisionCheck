/// Requestor sub-type for accounts whose system role is Organization (Requestor).
enum RequestorType {
  facultyStaff(
    label: 'Faculty or staff',
    description: 'I am faculty or staff requesting documentation from members.',
    iconName: 'faculty_staff',
  ),
  organization(
    label: 'Student organization',
    description: 'We are a student org requesting documentation services.',
    iconName: 'organization',
  );

  const RequestorType({
    required this.label,
    required this.description,
    required this.iconName,
  });

  final String label;
  final String description;
  final String iconName;

  /// Persisted on the user record via registration `student_id` (unused for requestors).
  String get storageValue {
    switch (this) {
      case RequestorType.facultyStaff:
        return 'Faculty / staff requestor';
      case RequestorType.organization:
        return 'Organization';
    }
  }
}
