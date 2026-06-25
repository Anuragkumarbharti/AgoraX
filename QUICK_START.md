# 🚀 Quick Start Guide - AgoraX

## ⚡ 5-Minute Setup

### 1. Prerequisites
```bash
flutter --version  # Should be 3.0+
dart --version     # Should be 3.0+
```

### 2. Install Dependencies
```bash
cd AgoraX
flutter pub get
```

### 3. Run the App
```bash
flutter run
```

## 📱 App Navigation

### Bottom Tabs (5 Total)
1. **Home** - Feed with trending communities, popular questions, recent posts
2. **Explore** - Search and discover new communities/questions/users
3. **Rooms** - Browse and join voice rooms
4. **Communities** - Manage your communities
5. **Profile** - View and edit your profile

### Authentication Flow
```
Launch App → Login Screen → Enter Credentials → Home Screen
        ↓
    No Account? → Sign Up Screen → Create Account → Login
```

## 🎨 Theme Colors (Remember These)

| Color | Hex | Use |
|-------|-----|-----|
| Primary | #6366F1 | Buttons, accents |
| Secondary | #8B5CF6 | Highlights |
| Accent | #10B981 | Success, badges |
| Error | #EF4444 | Errors, warnings |
| Background | #0F172A | Main bg |
| Card | #1E293B | Card bg |

## 📁 Common File Locations

```
Authentication:    lib/screens/auth/
Home Screen:       lib/screens/home/
Theme:            lib/core/theme.dart
Models:           lib/models/
Constants/Config: lib/core/constants.dart
Reusable Widgets: lib/widgets/
```

## 🔧 Adding a New Screen

### 1. Create Screen File
```dart
// lib/screens/yourfeature/your_screen.dart
import 'package:flutter/material.dart';
import '../../core/theme.dart';

class YourScreen extends StatefulWidget {
  const YourScreen({Key? key}) : super(key: key);

  @override
  State<YourScreen> createState() => _YourScreenState();
}

class _YourScreenState extends State<YourScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Your Screen', 
          style: Theme.of(context).textTheme.headlineLarge,
        ),
      ),
      body: Center(child: Text('Your Content')),
    );
  }
}
```

### 2. Add to Navigation
Edit `lib/screens/home/main_screen.dart`:
```dart
// Add import
import '../yourfeature/your_screen.dart';

// Add to _screens list
final List<Widget> _screens = [
  // ... existing screens
  const YourScreen(), // Add here
];

// Add to BottomNavigationBar items
BottomNavigationBarItem(
  icon: const Icon(Icons.your_icon_outlined),
  activeIcon: const Icon(Icons.your_icon_filled),
  label: 'Label',
),
```

## 🎨 Styling Conventions

### Use Theme Everywhere
```dart
// ✅ GOOD
Text(
  'Hello',
  style: Theme.of(context).textTheme.headlineLarge,
)

// ❌ BAD
Text(
  'Hello',
  style: TextStyle(fontSize: 24, color: Colors.white),
)
```

### Colors from AppTheme
```dart
// ✅ GOOD
Container(color: AppTheme.primaryColor)

// ❌ BAD
Container(color: Color(0xFF6366F1))
```

### Spacing Units
```dart
// ✅ GOOD
const SizedBox(height: 16)
const EdgeInsets.all(12)

// ❌ BAD
const SizedBox(height: 15.5)
const EdgeInsets.all(11)
```

## 🧩 Adding a Reusable Widget

### 1. Create Widget File
```dart
// lib/widgets/my_widget.dart
import 'package:flutter/material.dart';
import '../core/theme.dart';

class MyWidget extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;

  const MyWidget({
    Key? key,
    required this.title,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        // Your widget implementation
      ),
    );
  }
}
```

### 2. Export from Index
Edit `lib/widgets/index.dart`:
```dart
export 'my_widget.dart';
```

### 3. Use in Screens
```dart
import '../../widgets/index.dart';

// Use
MyWidget(title: 'Hello', onTap: () {})
```

## 🔌 API Integration (When Backend Ready)

### 1. Create Repository
```dart
// lib/repositories/community_repository.dart
class CommunityRepository {
  final Dio dio;
  
  CommunityRepository(this.dio);
  
  Future<List<Community>> getCommunities() async {
    try {
      final response = await dio.get('/communities');
      return (response.data as List)
        .map((e) => Community.fromJson(e))
        .toList();
    } catch (e) {
      // Handle error
      throw Exception('Failed to fetch communities');
    }
  }
}
```

### 2. Use in Screen
```dart
Future<void> _fetchCommunities() async {
  try {
    final repo = CommunityRepository(dio);
    final communities = await repo.getCommunities();
    setState(() => this.communities = communities);
  } catch (e) {
    // Show error
  }
}
```

## 🔒 Environment Configuration

Edit `lib/core/constants.dart`:
```dart
class ApiConfig {
  static const String baseUrl = 'YOUR_API_URL';
  static const String wsUrl = 'YOUR_WS_URL';
}
```

## 🐛 Common Issues & Solutions

### App Won't Run
```bash
# Clean build
flutter clean
flutter pub get
flutter run
```

### Dependency Issues
```bash
# Update dependencies
flutter pub upgrade

# Fix broken dependencies
flutter pub get --offline
```

### Build Errors
```bash
# Invalidate cache
rm -rf build/
flutter clean
flutter pub get
flutter run
```

## 📝 Useful Commands

```bash
# Check for issues
flutter analyze

# Format code
dart format lib/

# Run tests
flutter test

# Build for android
flutter build apk

# Build for iOS
flutter build ios

# Generate release build
flutter build appbundle --release
```

## 📚 Project Structure at a Glance

```
lib/
├── main.dart                 # Entry point
├── core/
│   ├── theme.dart           # Dark theme
│   ├── constants.dart       # Config & ZEGOCLOUD
│   └── index.dart
├── models/
│   ├── user_model.dart
│   ├── community_model.dart
│   ├── post_model.dart
│   ├── question_model.dart
│   ├── room_model.dart
│   └── index.dart
├── repositories/            # TODO: API layer
├── services/               # TODO: Business logic
├── widgets/
│   ├── post_card.dart
│   ├── community_card.dart
│   └── index.dart
└── screens/
    ├── auth/
    │   ├── login_screen.dart
    │   └── signup_screen.dart
    ├── home/
    │   ├── main_screen.dart     # Navigation
    │   └── home_screen.dart
    ├── explore/
    │   └── explore_screen.dart
    ├── rooms/
    │   └── rooms_screen.dart
    ├── communities/
    │   └── communities_screen.dart
    ├── profile/
    │   └── profile_screen.dart
    └── index.dart
```

## 🎯 Next Steps

1. **Backend Setup** - Start working on NestJS backend
2. **API Integration** - Connect screens to backend
3. **ZEGOCLOUD** - Integrate voice functionality
4. **Firebase** - Set up notifications
5. **Testing** - Add unit and widget tests
6. **Deployment** - Prepare for Play Store

## 💡 Pro Tips

- Use `const` for immutable widgets to improve performance
- Use `GetX` for easier navigation: `Get.to(() => NewScreen())`
- Use `Provider` for state management across screens
- Always add proper error handling
- Test on both Android and iOS devices
- Use `flutter format` before committing code

## 🆘 Need Help?

1. Check `DEVELOPMENT.md` for detailed guides
2. Check `README.md` for project overview
3. Review existing screen implementations
4. Check comments in code
5. Ask in team discussions

---

**Happy Coding! 🚀**

For more details, see:
- `README.md` - Project overview
- `DEVELOPMENT.md` - Detailed development guide
- `CHANGELOG.md` - Version history
