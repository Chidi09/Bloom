/// Portfolio persona configuration, contact credentials, and metadata.
///
/// Contains developer profile details, project defaults, and EmailJS
/// placeholders for the contact section form.
library;

/// Fictional developer persona details for this showcase portfolio.
class PortfolioPersona {
  static const String name = 'Alex Rivera';
  static const String role = 'Senior Full-Stack & Distributed Systems Engineer';
  static const String tagline =
      'Architecting resilient distributed backends and crafting high-performance, reactive user interfaces.';
  static const String shortBio =
      'I specialize in building low-latency distributed systems, type-safe reactive web architectures, and high-craft user experiences. With over 8 years of engineering experience spanning cloud infrastructure, Dart/Flutter compilation toolchains, and real-time streaming pipelines, I bridge the gap between deep systems performance and delightful frontend craft.';
  static const String location = 'San Francisco, CA / Remote';
  static const String email = 'alex.rivera.engineering@example.com';
  static const String github = 'https://github.com/alexrivera-dev';
  static const String linkedin = 'https://linkedin.com/in/alexrivera-eng';
  static const String twitter = 'https://x.com/alexrivera_dev';

  /// Animated roles for the Typed.js hero sequence.
  static const List<String> typedRoles = [
    'Senior Full-Stack Engineer',
    'Distributed Systems Architect',
    'High-Performance UI Craftsman',
    'Open Source Contributor',
  ];

  /// The well-known GitHub account used to fetch sample contribution graph data.
  static const String githubActivityUser = 'torvalds';

  /// Portrait image URL (Unsplash with explicit optimization query parameters).
  static const String portraitUrl =
      'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=800&auto=format&fit=crop&q=80';

  /// Hero background video URL (decorative looping GIPHY mp4 with fallback poster).
  static const String heroVideoUrl =
      'https://media.giphy.com/media/xT9IgzoKnwFNmISR8I/giphy.mp4';
  static const String heroPosterUrl =
      'https://images.unsplash.com/photo-1550745165-9bc0b252726f?w=1600&auto=format&fit=crop&q=80';
}

/// EmailJS dispatch credentials.
///
/// To enable live email dispatch, sign up at https://www.emailjs.com/
/// and replace these placeholder values with your real service, template,
/// and public key IDs.
class EmailJsConfig {
  /// Your EmailJS Service ID (e.g. 'service_7x9ab2c').
  static const String serviceId = 'YOUR_EMAILJS_SERVICE_ID';

  /// Your EmailJS Template ID (e.g. 'template_q8w9e0r').
  static const String templateId = 'YOUR_EMAILJS_TEMPLATE_ID';

  /// Your EmailJS Public Key (e.g. 'pub_1234567890abcdef').
  static const String publicKey = 'YOUR_EMAILJS_PUBLIC_KEY';

  /// Returns `true` if valid non-placeholder credentials have been configured.
  static bool get isConfigured =>
      serviceId != 'YOUR_EMAILJS_SERVICE_ID' &&
      templateId != 'YOUR_EMAILJS_TEMPLATE_ID' &&
      publicKey != 'YOUR_EMAILJS_PUBLIC_KEY' &&
      serviceId.trim().isNotEmpty &&
      templateId.trim().isNotEmpty &&
      publicKey.trim().isNotEmpty;
}
