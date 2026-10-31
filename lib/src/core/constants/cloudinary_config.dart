/// Cloudinary config for avatar uploads on the Spark (free) plan, where
/// Firebase Storage is unavailable (D44).
///
/// Create an *unsigned* upload preset in the Cloudinary dashboard
/// (Settings → Upload → Upload presets → Add → Signing Mode: Unsigned) and
/// fill in the values below. Leave empty to disable uploads with a clear
/// error instead of a cryptic network failure.
///
/// On Blaze, revert to Firebase Storage (`avatars/{uid}/profile.jpg`) and
/// remove this file + the uploadAvatar Cloudinary path.
class CloudinaryConfig {
  const CloudinaryConfig._();

  /// Your Cloudinary cloud name (dashboard → top-left).
  static const String cloudName = 'dizy9vwqd';

  /// Name of the unsigned upload preset.
  static const String uploadPreset = 'ml_default';

  static bool get isConfigured =>
      cloudName.trim().isNotEmpty && uploadPreset.trim().isNotEmpty;
}
