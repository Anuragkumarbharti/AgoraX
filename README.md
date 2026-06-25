# AgoraX - Flutter Mobile App

**AgoraX** is a community platform that combines Discord, Quora, and Clubhouse with a strong creator economy focus.

## 🚀 Quick Start

### Prerequisites
- Flutter 3.0+
- Dart 3.0+
- Android SDK
- iOS SDK (optional)

### Installation

```bash
# Install dependencies
flutter pub get

# Generate code (if using build_runner)
flutter pub run build_runner build

# Run the app
flutter run
```

## 📱 Project Structure

```
lib/
├── core/                    # Constants, theme, configuration
│   ├── constants.dart      # App constants & ZEGOCLOUD config
│   ├── theme.dart          # Dark theme with glassmorphism
│   └── index.dart          # Exports
├── models/                 # Data models
│   ├── user_model.dart
│   ├── community_model.dart
│   ├── post_model.dart
│   ├── question_model.dart
│   ├── room_model.dart
│   └── index.dart
├── repositories/           # API layer (TODO)
├── services/              # Business logic (TODO)
├── widgets/               # Reusable UI components
│   ├── post_card.dart
│   ├── community_card.dart
│   └── ...
├── screens/               # Feature screens
│   ├── auth/
│   │   ├── login_screen.dart
│   │   └── signup_screen.dart
│   ├── home/
│   │   ├── main_screen.dart
│   │   └── home_screen.dart
│   ├── explore/
│   │   └── explore_screen.dart
│   ├── rooms/
│   │   └── rooms_screen.dart
│   ├── communities/
│   │   └── communities_screen.dart
│   └── profile/
│       └── profile_screen.dart
└── main.dart              # App entry point
```

## 🎨 Design

- **Theme**: Dark mode with glassmorphism effects
- **Colors**: 
  - Primary: #6366F1 (Indigo)
  - Secondary: #8B5CF6 (Purple)
  - Accent: #10B981 (Emerald)
- **Font**: Poppins (Google Fonts)
- **Rounded Corners**: 12-16px border radius

## 🔌 Integration Points

### ZEGOCLOUD Integration
- AppID: `1604838463`
- AppSign: `49d9be471e524acf50081fec3680d19df0fe4c1a532953d08a3cd6fac1a19fe3`
- Used for: Real-time voice communication

### Backend API
- Base URL: `http://localhost:3000/api` (configurable in `constants.dart`)
- WebSocket: `ws://localhost:3000` (for real-time features)

## 📋 Features Implemented (Phase 1)

✅ Authentication
- Login screen
- Sign up screen
- Password validation

✅ Main Navigation
- 5 bottom tabs (Home, Explore, Rooms, Communities, Profile)
- Clean tab switching

✅ Home Screen
- Trending communities carousel
- Popular questions
- Recent posts feed
- Floating action button

✅ Explore Screen
- Search functionality
- Filter options (Trending, New, Popular, Nearby)
- Search results display

✅ Rooms Screen
- Live rooms list
- Room status (live/scheduled)
- Participant count
- Join/Notify functionality

✅ Communities Screen
- User's communities list
- Member count
- Unread indicators
- Navigation to community details

✅ Profile Screen
- User profile information
- Stats (Following, Followers, Communities)
- Wallet display
- Settings menu
- Logout functionality

## 🔄 Next Steps

1. **Backend Integration**
   - Connect API endpoints
   - Implement repositories
   - Add error handling

2. **Authentication**
   - JWT token management
   - Secure storage
   - Session management

3. **Voice Rooms** (ZEGOCLOUD Integration)
   - Real-time voice communication
   - Room controls
   - Screen sharing

4. **Push Notifications**
   - Firebase Cloud Messaging setup
   - Local notification handling

5. **Payment Integration**
   - Razorpay integration
   - Wallet system
   - Subscription management

6. **Advanced Features**
   - AI recommendations
   - Analytics tracking
   - Admin dashboard

## 📦 Dependencies

### Core
- `flutter_svg`: SVG rendering
- `get`: State management & routing
- `google_fonts`: Custom fonts

### API & Networking
- `dio`: HTTP client
- `retrofit`: REST API generator

### Real-time
- `zego_uikit`: Voice/Video communication
- `web_socket_channel`: WebSocket support

### Storage
- `hive_flutter`: Local database
- `cached_network_image`: Image caching

### Notifications
- `firebase_core`: Firebase setup
- `firebase_messaging`: Push notifications

### Payments
- `razorpay_flutter`: Payment gateway

### Permissions
- `permission_handler`: Runtime permissions

## 🧪 Testing

Run tests with:
```bash
flutter test
```

## 📝 Configuration

Edit `lib/core/constants.dart` to configure:
- ZEGOCLOUD credentials
- API endpoints
- Firebase project ID
- Payment keys
- Feature flags

## 🤝 Contributing

See `.agent.md` for development guidelines.

## 📄 License

Proprietary - AgoraX Inc.

## 📞 Support

For issues and feature requests, contact the development team.
