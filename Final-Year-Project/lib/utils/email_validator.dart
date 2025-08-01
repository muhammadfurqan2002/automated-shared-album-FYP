// Define reusable regex patterns for email validation
class EmailValidators {
  // Basic email format validation
  static final RegExp basicEmailFormat = RegExp(r'^[^@]+@[^@]+\.[^@]+');

  // Specific domains validation
  static final RegExp allowedDomains = RegExp(
      r'^[^@]+@(gmail\.com|.*\.edu\.pk|.*\.com)$',
      caseSensitive: false
  );

  // Combined validation
  static bool isValidEmail(String email) {
    return basicEmailFormat.hasMatch(email);
  }

  static bool hasAllowedDomain(String email) {
    return allowedDomains.hasMatch(email);
  }
}