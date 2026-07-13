// ZEGOCLOUD Configuration
class ZegoCloudConfig {
  static const String appID = '393055653';
}

// API Configuration
class ApiConfig {
  static const String baseUrl = 'http://localhost:3000/api';
  static const String wsUrl = 'ws://localhost:3000';
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
}

// Firebase Configuration
class FirebaseConfig {
  static const String projectId = 'creania-app';
  static const String appId = 'creania-mobile-app';
}

// App Configuration
class AppConfig {
  static const String appName = 'Creania';
  static const String version = '1.0.0';
  static const String buildNumber = '1';
  
  // Feature Flags
  static const bool enableAnalytics = true;
  static const bool enableCrashlytics = true;
  static const bool enableNotifications = true;
}

// Payment Configuration
class PaymentConfig {
  static const String razorpayKeyId = 'YOUR_RAZORPAY_KEY_ID';
  static const String stripePublishableKey = 'YOUR_STRIPE_KEY';
}

// Routes
class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String interests = '/interests';
  static const String home = '/home';
  static const String explore = '/explore';
  static const String communities = '/communities';
  static const String communityDetail = '/community/:id';
  static const String rooms = '/rooms';
  static const String roomDetail = '/room/:id';
  static const String profile = '/profile';
  static const String editProfile = '/edit-profile';
  static const String settings = '/settings';
  static const String notifications = '/notifications';
  static const String messages = '/messages';
  static const String createPost = '/create-post';
  static const String createQuestion = '/create-question';
  static const String createRoom = '/create-room';
}

// Assets
class AppAssets {
  static const String appLogo = 'assets/images/logo.png';
  static const String placeholder = 'assets/images/placeholder.png';
  
  // Icons
  static const String homeIcon = 'assets/icons/home.svg';
  static const String exploreIcon = 'assets/icons/explore.svg';
  static const String roomsIcon = 'assets/icons/rooms.svg';
  static const String communitiesIcon = 'assets/icons/communities.svg';
  static const String profileIcon = 'assets/icons/profile.svg';
}

// Strings
class AppStrings {
  // App
  static const String appName = 'Creania';
  static const String tagline = 'Learn, Discuss & Connect';

  // Auth
  static const String welcome = 'Welcome to Creania';
  static const String login = 'Login';
  static const String signup = 'Sign Up';
  static const String email = 'Email';
  static const String password = 'Password';
  static const String forgotPassword = 'Forgot Password?';
  static const String dontHaveAccount = "Don't have an account?";
  static const String alreadyHaveAccount = 'Already have an account?';

  // Navigation
  static const String home = 'Home';
  static const String explore = 'Explore';
  static const String rooms = 'Rooms';
  static const String communities = 'Communities';
  static const String profile = 'Profile';

  // Common
  static const String loading = 'Loading...';
  static const String error = 'Error';
  static const String noData = 'No data found';
  static const String tryAgain = 'Try Again';
  static const String cancel = 'Cancel';
  static const String confirm = 'Confirm';
  static const String save = 'Save';
  static const String delete = 'Delete';
  static const String edit = 'Edit';
  static const String search = 'Search';
  static const String filter = 'Filter';
}
