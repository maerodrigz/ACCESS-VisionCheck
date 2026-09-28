/// Requestor sub-type for accounts whose system role is Organization (Requestor).
enum RequestorType {
  faculty(
    label: 'Faculty',
    description: 'For faculty members requesting documentation services.',
    iconName: 'faculty',
  ),
  instructor(
    label: 'Instructor',
    description: 'For instructors requesting documentation services.',
    iconName: 'instructor',
  ),
  organization(
    label: 'Organization',
    description:
        'For student organizations and groups requesting documentation services.',
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
  String get storageValue => label;
}
