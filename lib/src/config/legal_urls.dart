/// Legal / policy links shown in **About**.
///
/// **Termly:** use the hosted `https://app.termly.io/document/...` URLs from your
/// Termly dashboard (not embed HTML). Optional policies only appear as buttons when
/// non-empty. Privacy/terms fall back to GitHub `docs/` when the Termly fields
/// below are empty.
class LegalUrls {
  LegalUrls._();

  static const String _repoPrivacy =
      'https://github.com/uemsihtv/UEMSI-HTV-HD-Express-Camera-app/blob/main/docs/PRIVACY.md';
  static const String _repoTerms =
      'https://github.com/uemsihtv/UEMSI-HTV-HD-Express-Camera-app/blob/main/docs/TERMS.md';

  /// Termly policy UUID for **Privacy Notice** / app DSAR (UEMSI/HTV Express Camera).
  static const String _termlyPrivacyPolicyId =
      '2685a75d-96c1-4d72-bccf-f664ef376019';

  /// Termly policy UUID for **Cookie Policy** (www.uemsihtv.com) — from your Termly
  /// cookie embed / DSAR footer link (`aff4df74-…`).
  static const String _termlyCookiePolicyId =
      'aff4df74-0634-4003-9b96-0bd50e367711';

  /// Termly policy UUID for **EULA** (UEMSI/HTV Express Camera) — from your Termly
  /// EULA embed footer link (`ee845345-…`).
  static const String _termlyEulaPolicyId =
      'ee845345-7d7e-41a0-969e-0913ac88cdcb';

  /// Termly policy UUID for **Disclaimer** (Site + mobile app) — from your Termly
  /// disclaimer embed footer link (`db304331-…`).
  static const String _termlyDisclaimerPolicyId =
      'db304331-da22-4419-8e35-0ec122f04455';

  // --- Termly hosted documents (public URLs) ---

  /// Privacy policy (matches your Termly embed for UEMSI/HTV Express Camera).
  static const String termlyPrivacyPolicy =
      'https://app.termly.io/document/privacy-policy/$_termlyPrivacyPolicyId';

  /// Terms and conditions (Termly) — same policy set as privacy / app legal terms.
  static const String termlyTermsOfUse =
      'https://app.termly.io/document/terms-of-service/$_termlyPrivacyPolicyId';

  /// Cookie policy for your website (Termly hosted).
  static const String termlyCookiePolicy =
      'https://app.termly.io/document/cookie-policy/$_termlyCookiePolicyId';

  /// Website + app disclaimer (Termly hosted).
  static const String termlyDisclaimer =
      'https://app.termly.io/document/disclaimer/$_termlyDisclaimerPolicyId';

  /// End User License Agreement (App Store / Play standard EULA, Termly hosted).
  static const String termlyEula =
      'https://app.termly.io/document/eula/$_termlyEulaPolicyId';

  /// Termly **data subject access request** (from your Privacy Notice).
  static const String termlyDataSubjectRequest =
      'https://app.termly.io/dsar/$_termlyPrivacyPolicyId';

  /// **About → Source code.** Must be a URL that works in a normal browser without
  /// logging in. Private GitHub repos return **404** to the public — either make the
  /// repo **public** (GitHub → Settings → Danger zone → Change repository visibility)
  /// or set this to a public mirror / releases page.
  static const String sourceCodeRepositoryUrl =
      'https://github.com/uemsihtv/UEMSI-HTV-HD-Express-Camera-app';

  // --- Resolved URLs for the app ---

  static String get privacyPolicyUrl =>
      termlyPrivacyPolicy.isNotEmpty ? termlyPrivacyPolicy : _repoPrivacy;

  static String get termsOfUseUrl =>
      termlyTermsOfUse.isNotEmpty ? termlyTermsOfUse : _repoTerms;

  static String? get cookiePolicyUrl =>
      termlyCookiePolicy.isNotEmpty ? termlyCookiePolicy : null;

  static String? get disclaimerUrl =>
      termlyDisclaimer.isNotEmpty ? termlyDisclaimer : null;

  static String? get eulaUrl => termlyEula.isNotEmpty ? termlyEula : null;

  static String? get dataSubjectRequestUrl =>
      termlyDataSubjectRequest.isNotEmpty ? termlyDataSubjectRequest : null;
}
