import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:location_sharing_app/firebase_options.dart';
import 'package:location_sharing_app/screens/home.dart';
import 'package:location_sharing_app/screens/login.dart';
import 'package:location_sharing_app/screens/register.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); 
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      home: RegistrationScreen(),
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
    );
  }
}
