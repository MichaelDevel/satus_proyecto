import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:satus_proyecto/services/notification_service.dart';
import 'screens/home_screen.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/welcome_screen.dart';
import 'package:workmanager/workmanager.dart';
import 'services/work_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // ← obligatorio antes de Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await NotificationService().init();
  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: false,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Satus Proyecto',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
        home: FirebaseAuth.instance.currentUser != null
            ? HomeScreen(user: FirebaseAuth.instance.currentUser!)
            : const WelcomeScreen(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: const Center(
        child: Text('Bienvenido'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        },
        tooltip: 'login',
        child: const Text("Login"),
      ),
    );
  }
}