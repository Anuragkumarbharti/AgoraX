# Creania Development Guide

## 🏗️ Project Architecture

Creania follows a **Clean Architecture** pattern with clear separation of concerns:

```
Presentation Layer (UI)
        ↓
Business Logic Layer (Services)
        ↓
Data Layer (Repositories)
        ↓
Local & Remote Data Sources
```

## 📚 Folder Structure Explained

### `/lib/core`
Contains application-wide constants and configurations.
- `theme.dart`: Dark theme with glassmorphism styling
- `constants.dart`: API endpoints, ZEGOCLOUD config, routes, strings

### `/lib/models`
Data models representing the app's entities.
- `user_model.dart`: User entity
- `community_model.dart`: Community entity
- `post_model.dart`: Post entity
- `question_model.dart`: Question entity
- `room_model.dart`: VoiceRoom entity

### `/lib/widgets`
Reusable UI components used across screens.
- `post_card.dart`: Post display component
- `community_card.dart`: Community showcase component

### `/lib/screens`
Feature screens organized by domain.
- `auth/`: Authentication screens (login, signup)
- `home/`: Home screen and main navigation
- `explore/`: Search and discovery
- `rooms/`: Voice rooms listing
- `communities/`: Communities management
- `profile/`: User profile

### `/lib/repositories` (TODO)
API and data layer abstraction.
Should contain:
- API client setup
- Data fetching/caching logic
- Error handling

### `/lib/services` (TODO)
Business logic and use cases.
Should contain:
- Authentication service
- Community management service
- Room management service
- Payment service

## 🎨 Design System

### Color Palette
```dart
Primary:    #6366F1 (Indigo)     - Main actions
Secondary:  #8B5CF6 (Purple)     - Accents
Accent:     #10B981 (Emerald)    - Success/highlights
Background: #0F172A (Dark)       - Main background
Card:       #1E293B (Light Dark)  - Cards
Border:     #334155 (Slate)      - Borders
Text Primary:   #F1F5F9          - Main text
Text Secondary: #CBD5E1          - Secondary text
Text Tertiary:  #94A3B8          - Hint text
Error:      #EF4444 (Red)        - Errors
Success:    #22C55E (Green)      - Success
Warning:    #F59E0B (Amber)      - Warnings
```

### Typography
- **Font Family**: Poppins (from Google Fonts)
- **Display Large**: 32px, Bold (700)
- **Display Medium**: 28px, Bold (700)
- **Headline Large**: 24px, Semibold (600)
- **Headline Small**: 20px, Semibold (600)
- **Body Large**: 16px, Regular (400)
- **Body Medium**: 14px, Regular (400)
- **Body Small**: 12px, Regular (400)

### Spacing
- Standard units: 8px, 16px, 24px, 32px
- Card padding: 12px to 16px
- Border radius: 12px (cards), 16px (large surfaces)

## 🔄 State Management Plan

### Current: Stateful Widgets
For quick prototyping and simple state.

### Future: Provider Pattern
Recommended migration path:
```dart
// Example
class AuthProvider extends ChangeNotifier {
  bool isLoading = false;
  User? currentUser;

  Future<void> login(String email, String password) async {
    // Login logic
    notifyListeners();
  }
}

// Usage in widgets
Consumer<AuthProvider>(
  builder: (context, auth, child) {
    return Text(auth.currentUser?.displayName ?? 'Guest');
  },
)
```

## 🌐 Backend Integration

### API Endpoint Structure
```
BASE_URL: http://localhost:3000/api

Auth:
  POST /auth/login
  POST /auth/signup
  POST /auth/refresh-token

Communities:
  GET /communities
  GET /communities/:id
  POST /communities
  PUT /communities/:id
  DELETE /communities/:id

Posts:
  GET /posts
  POST /posts
  PUT /posts/:id
  DELETE /posts/:id

Questions:
  GET /questions
  POST /questions
  PUT /questions/:id
  DELETE /questions/:id

Rooms:
  GET /rooms
  POST /rooms
  PUT /rooms/:id
  DELETE /rooms/:id
```

## 🔐 Authentication Flow

```
1. User enters credentials
   ↓
2. POST /auth/login
   ↓
3. Backend validates & returns JWT token
   ↓
4. Store token locally (Hive)
   ↓
5. Add token to all API requests (Authorization header)
   ↓
6. Redirect to home screen
   ↓
7. On app restart: Auto-login using stored token
```

## 🎙️ ZEGOCLOUD Integration

### Setup Steps
1. Import ZEGOCLOUD package
2. Initialize with AppID and AppSign
3. Create room with configuration
4. Handle permissions (microphone, camera)
5. Implement WebRTC connection
6. Handle disconnect/errors

### Example Usage
```dart
// Initialize ZEGOCLOUD
ZegoUIKit().init(
  appID: 1604838463,
  appSign: '49d9be471e524acf50081fec3680d19df0fe4c1a532953d08a3cd6fac1a19fe3',
);

// Join room
ZegoUIKit().joinRoom(roomID: 'room_1');

// Leave room
ZegoUIKit().leaveRoom();
```

## 💳 Payment Integration

### Razorpay Flow
```
1. User initiates payment
   ↓
2. Create order in backend
   ↓
3. Open Razorpay checkout
   ↓
4. User completes payment
   ↓
5. Webhook verification
   ↓
6. Update user subscription status
```

## 📲 Push Notifications

### Firebase Setup
1. Configure Firebase project
2. Add google-services.json to android/
3. Initialize Firebase in main.dart
4. Request user permission
5. Handle notification payloads

## 🧪 Testing Strategy

### Unit Tests
```dart
test('User creation with valid data', () {
  final user = User(
    id: '1',
    username: 'testuser',
    email: 'test@example.com',
    // ... other fields
  );
  
  expect(user.username, 'testuser');
});
```

### Widget Tests
```dart
testWidgets('Login button shows loading state', (WidgetTester tester) async {
  await tester.pumpWidget(const MyApp());
  await tester.tap(find.byType(ElevatedButton));
  await tester.pumpAndSettle();
  
  expect(find.byType(CircularProgressIndicator), findsOneWidget);
});
```

## 📊 Analytics

### Events to Track
- User signup
- Community joined
- Question asked
- Answer provided
- Room joined
- Payment processed
- Subscription renewed

### Implementation
```dart
FirebaseAnalytics.instance.logEvent(
  name: 'community_joined',
  parameters: {
    'community_id': communityId,
    'user_id': userId,
  },
);
```

## 🚀 Performance Optimization

### Image Optimization
- Use `cached_network_image` for caching
- Optimize image sizes before upload
- Use WebP format when possible

### List Optimization
- Implement pagination
- Use `ListView.builder` instead of `ListView`
- Implement virtual scrolling for large lists

### Network Optimization
- Implement request batching
- Use compression
- Implement retry logic
- Cache API responses

## 🐛 Error Handling

### Global Error Handler
```dart
Future<void> _handleError(dynamic error) async {
  if (error is DioError) {
    // Handle API errors
  } else if (error is TimeoutException) {
    // Handle timeout
  } else {
    // Handle generic errors
  }
}
```

## 📱 Responsive Design

### Breakpoints
- Mobile: < 600dp
- Tablet: 600dp - 840dp
- Desktop: > 840dp

### Adaptation Pattern
```dart
final isMobile = MediaQuery.of(context).size.width < 600;

return isMobile 
  ? MobileLayout() 
  : TabletLayout();
```

## 🔄 Git Workflow

```bash
# Create feature branch
git checkout -b feature/feature-name

# Make changes and commit
git add .
git commit -m "feat: add feature description"

# Push to remote
git push origin feature/feature-name

# Create pull request on GitHub
```

## 🚀 Deployment

### Android Release
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk

# For Play Store
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

### Environment Variables
Create `.env` file:
```
API_BASE_URL=https://api.creania.com
ZEGOCLOUD_APP_ID=1604838463
ZEGOCLOUD_APP_SIGN=49d9be471e524acf50081fec3680d19df0fe4c1a532953d08a3cd6fac1a19fe3
```

## 📖 Useful Resources

- Flutter Docs: https://flutter.dev/docs
- Dart Docs: https://dart.dev/guides
- Provider Package: https://pub.dev/packages/provider
- ZEGOCLOUD Docs: https://docs.zegocloud.com/
- Firebase Docs: https://firebase.google.com/docs
- Razorpay Integration: https://razorpay.com/integrations

## 🤝 Contributing

1. Follow the project structure
2. Write clean, commented code
3. Use meaningful variable names
4. Test your changes
5. Update documentation
6. Submit PR with description

## 📞 Questions?

For questions or issues:
1. Check existing documentation
2. Review similar implementations
3. Check GitHub issues
4. Ask in team discussions
