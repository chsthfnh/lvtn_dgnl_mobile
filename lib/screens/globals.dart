// File: lib/globals.dart
import 'package:flutter/material.dart';

//Ho tro Ai tutor đi khắp nơi trong app

// Key để điều khiển Navigator từ bất kỳ đâu
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Biến điều khiển Bật/Tắt AI Tutor toàn cục
final ValueNotifier<bool> aiTutorNotifier = ValueNotifier(false);

// Biến lưu ngữ cảnh màn hình hiện tại cho AI
final ValueNotifier<String> currentScreenNotifier = ValueNotifier('Dashboard');
