/// User-facing copy for mobile sign-up flows (plain punctuation, no em dashes).
abstract final class MobileRegistrationCopy {
  static const choiceTitle = 'Welcome Back!';
  static const choiceSubtitle = 'Join ACCESS VisionCheck and start your journey!';
  static const choiceBody =
      'Members join as student media. Requestors are faculty, staff, or organizations '
      'that need documentation services.';

  static const memberTitle = 'Welcome Back!';
  static const memberSubtitle = 'Join ACCESS VisionCheck and start your journey!';

  static const requestorTypeTitle = 'Welcome Back!';
  static const requestorTypeSubtitle =
      'Choose the option that best describes you or your organization!';

  static const emailVerificationTitle = 'Email verification';
  static const emailVerificationBody =
      'Use the email address above. Tap Send code, then enter the 6-digit code from your inbox.';

  static const verifyEmailBeforeSubmit =
      'Confirm your email with the 6-digit code before you submit registration.';

  static const agreeLegalError =
      'Please agree to the Terms, Privacy Policy, and Content Standards.';

  static String memberSuccessMessage(String email) =>
      'Your member registration was submitted and is pending administrator approval. '
      'We will email $email when your account is approved or declined. '
      'You cannot sign in until approval is complete.';

  static String requestorSuccessMessage(String email) =>
      'Your requestor registration was submitted and is pending administrator approval. '
      'We will email $email when your account is approved or declined. '
      'You cannot sign in until approval is complete.';
}
