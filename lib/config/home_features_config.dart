/// Configuration for optional Buyer Home page features
/// These can be enabled/disabled without impacting core functionality
class HomeFeaturesConfig {
  // Enable/disable recommendation features
  static const bool enableRecommendations = true;
  static const bool enableLocationBased = true;
  static const bool enableTimeBased = true;

  // Limits for each section
  static const int recommendationsLimit = 10;
  static const int locationBasedLimit = 10;
  static const int timeBasedLimit = 10;
}

