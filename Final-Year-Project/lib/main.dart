import 'package:face_camera/face_camera.dart';
import 'package:flutter/material.dart';
import 'package:fyp/providers/AuthProvider.dart';
import 'package:fyp/providers/flaggedImage_provider.dart';
import 'package:fyp/providers/session_manager.dart';
import 'package:fyp/providers/sharedAlbum_provider.dart';
import 'package:fyp/providers/suggestions_provider.dart';
import 'package:fyp/services/album_notification_service.dart';
import 'package:fyp/services/fcm_service.dart';
import 'package:fyp/services/flaggedImage_service.dart';
import 'package:fyp/services/sharedAlbum_service.dart';
import 'package:fyp/utils/ip.dart';
import 'package:provider/provider.dart';
import 'package:screen_protector/screen_protector.dart';
import 'providers/album_provider.dart';
import 'providers/images_provider.dart';
import 'providers/notification_provider.dart';
import 'services/album_service.dart';
import 'services/image_service.dart';
import 'screens/splash_screen.dart';
import 'screens/authentication/screens/login_screen.dart';
import 'screens/home/home_navigation.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  await FaceCamera.initialize();  // Add this line
  // Create FCM Service instance
  final fcmService = FCMService();

  final albumNotificationService = AlbumNotificationService();


  runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),

          ChangeNotifierProvider<AlbumProvider>(
            create: (_) => AlbumProvider(
              albumService: AlbumService(
                baseUrl: IP.ip,
              ),
            ),
          ),
          ChangeNotifierProvider(create: (_)=>FlaggedImageProvider(flaggedImageService:FlaggedImageService(baseUrl:IP.ip ))),

          ChangeNotifierProvider<ImagesProvider>(
            create: (_) => ImagesProvider(
              imageService: ImageService(
                baseUrl: IP.ip,
              ),
            ),
          ),

          ChangeNotifierProvider(create: (_) => NotificationProvider()),

          ChangeNotifierProxyProvider<AuthProvider, SharedAlbumProvider>(
            create: (_) => SharedAlbumProvider(
              service: SharedAlbumService(baseUrl: IP.ip),
              authProvider: AuthProvider(), // dummy placeholder
            ),
            update: (_, authProvider, __) => SharedAlbumProvider(
              service: SharedAlbumService(baseUrl: IP.ip),
              authProvider: authProvider,
            ),
          ),

          ChangeNotifierProvider<SuggestionProvider>(
            create: (_) => SuggestionProvider(
              albumService: AlbumService(baseUrl: IP.ip),
            ),
          ),
        ],
        child: Consumer<SharedAlbumProvider>(
          builder: (context, sharedAlbumProvider, _) {
            return MyApp(
              navigatorKey: navigatorKey,
              fcmService: fcmService,
              sharedAlbumProvider: sharedAlbumProvider,
            );
          },
        ),
      )
  );

  // Initialize FCM with the notification service instead of provider
  await fcmService.initialize(
    navKey: navigatorKey,
    albumNotificationService: albumNotificationService,
  );
}

class MyApp extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final FCMService fcmService;
  final SharedAlbumProvider sharedAlbumProvider;

  const MyApp({
    super.key,
    required this.navigatorKey,
    required this.fcmService,
    required this.sharedAlbumProvider,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // _blockCapture();
  }


  Future<void> _blockCapture() async {
    await ScreenProtector.preventScreenshotOn();
    await ScreenProtector.protectDataLeakageWithBlur();
  }

  /// Restore normal behaviour
  Future<void> _unblockCapture() async {
    await ScreenProtector.preventScreenshotOff();
    await ScreenProtector.protectDataLeakageWithBlurOff();
  }


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Album',
      theme: ThemeData(
        fontFamily: 'Poppins',
      ),
      navigatorKey: widget.navigatorKey,
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const NavigationHome(),
      },
    );
  }
}