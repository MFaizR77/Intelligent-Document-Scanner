// lib/config/env.dart
class Env {
  static const bool isDevelopment = true;

  // MongoDB Atlas URI
  // Format: mongodb+srv://<user>:<pass>@<cluster-url>/<db>?retryWrites=true&w=majority
  static const String mongoUri = String.fromEnvironment(
    'MONGODB_URI',
    defaultValue: '',
  );

  static const String mongoCollection = String.fromEnvironment(
    'MONGO_COLLECTION',
    defaultValue: 'scan_results',
  );
}
