import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'core/theme.dart';
import 'screens/index.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => GetMaterialApp(
        title: 'AgoraX',
        theme: AppTheme.darkTheme,
        debugShowCheckedModeBanner: false,
        home: const SplashScreen(),
        getPages: [
          GetPage(
            name: '/',
            page: () => const SplashScreen(),
          ),
        ],
      );
}
