import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'models/app_state.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化窗口
  await windowManager.ensureInitialized();
  
  const windowOptions = WindowOptions(
    size: Size(1200, 800),
    minimumSize: Size(1200, 600),  // 设置最小宽度为1200px，适配大多数现代网站
    center: true,
    title: 'Deskify',
    titleBarStyle: TitleBarStyle.hidden,
    skipTaskbar: false,
  );
  
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
    await windowManager.setResizable(true);  // 确保窗口可调整大小
  });
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState()..loadSavedUrl(),
      child: MaterialApp(
        title: 'Deskify',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
