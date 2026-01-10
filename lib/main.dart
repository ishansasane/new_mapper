import 'package:flutter/material.dart';
import 'package:new_mapper/pages/HomePage.dart';
import 'package:new_mapper/pages/map_page.dart';
import 'package:new_mapper/providers/map_provider.dart';
import 'package:new_mapper/providers/navigation_provider.dart';
import 'package:new_mapper/services/notification_service.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();

  await Supabase.initialize(
    url: 'https://dgpafznditkzjaahseku.supabase.co',
    anonKey: 'sb_publishable_9uoyycckID_3Na73VD1yVQ_q6pSFoiN',
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MapProvider()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Homepage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
