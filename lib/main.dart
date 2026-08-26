import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:qrpeasy_flutter/firebase_options.dart';
import 'package:qrpeasy_flutter/widgets/platform_builder.dart';

//ALREADY MOVED THE STUFF AROUND, FOR CLEANIGN

late AndroidNotificationChannel channel;
late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
bool isFlutterLocalNotificationsInitialized = false;

Future<void> setupFlutterNotifications() async {
  if (isFlutterLocalNotificationsInitialized) return;

  channel = const AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important notifications.',
    importance: Importance.high,
  );

  flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  isFlutterLocalNotificationsInitialized = true;
}

Future<void> _showNotification(int id, String? title, String? body) async {
  var androidPlatformChannelSpecifics = AndroidNotificationDetails(
    channel.id,
    channel.name,
    channelDescription: channel.description,
    icon: 'launch_background',
  );

  await flutterLocalNotificationsPlugin.show(
    id,
    title,
    body,
    NotificationDetails(android: androidPlatformChannelSpecifics),
  );
}

Future<void> showFlutterNotification(RemoteMessage message) async {
  if (message.notification != null) {
    _showNotification(
      message.notification.hashCode,
      message.notification!.title,
      message.notification!.body,
    );
  } else if (message.data.isNotEmpty) {
    _showNotification(
      message.data.hashCode,
      message.data['title'],
      message.data['body'],
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final firebaseMessaging = FirebaseMessaging.instance;
  final settings = await firebaseMessaging.requestPermission(
    alert: true,
    announcement: true,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );

  if (kDebugMode) {
    print('Permission granted: ${settings.authorizationStatus}');
  }

  String? token = await firebaseMessaging.getToken();

  if (kDebugMode) {
    print('Registration Token=$token');
  }

  FirebaseMessaging.onBackgroundMessage(showFlutterNotification);
  FirebaseMessaging.onMessage.listen(showFlutterNotification);

  if (!kIsWeb) {
    await setupFlutterNotifications();
  }

  runApp(const QrPeasyApp());
}

class QrPeasyApp extends StatefulWidget {
  const QrPeasyApp({super.key});

  @override
  State<QrPeasyApp> createState() => _QrPeasyAppState();
}

class _QrPeasyAppState extends State<QrPeasyApp> {
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      locale: Locale('ar', 'SA'),
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate
      ],
      supportedLocales: [Locale('ar', 'SA'), Locale('en', 'US')],
      debugShowCheckedModeBanner: false,
      home: PlatformBuilder(),
    );
  }
}
