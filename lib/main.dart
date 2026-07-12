import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'auth/auth_wrapper.dart';
import '/screens/globals.dart';
import 'screens/user_screens/ai_screens/ai_tutor_widget.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Hệ Thống ĐGNL',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      // CHỈ GIỮ LẠI DUY NHẤT 1 DÒNG HOME NÀY ĐỂ CHECK ĐĂNG NHẬP:
      home: const AuthWrapper(),
      builder: (context, child) {
        return ValueListenableBuilder<bool>(
          valueListenable: aiTutorNotifier,
          builder: (context, isEnabled, _) {
            return Stack(
              children: [
                if (child != null) child,

                if (isEnabled)
                  ValueListenableBuilder<String>(
                    valueListenable: currentScreenNotifier,
                    builder: (context, screenName, _) {
                      // TRẢ LẠI ĐÚNG CÁI BONG BÓNG CHAT Ở ĐÂY NÈ:
                      return DraggableAITutorWidget(
                        currentScreen: screenName,
                        onClose: () => aiTutorNotifier.value = false,
                      );
                      // TUYỆT ĐỐI KHÔNG DÙNG AITutorExplainButton Ở ĐÂY NHA!
                    },
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
