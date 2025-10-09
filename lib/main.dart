import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_options.dart';

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('📨 Background message: ${message.messageId}');
}

// Initialize local notifications
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Set up background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  // Initialize local notifications
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/launcher_icon');
  
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      debugPrint('📬 Notification tapped: ${response.payload}');
    },
  );
  
  // Create notification channel for Android
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important notifications.',
    importance: Importance.high,
  );
  
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
  
  // Request notification permissions
  final messaging = FirebaseMessaging.instance;
  final settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );
  
  debugPrint('🔔 Notification permission: ${settings.authorizationStatus}');
  
  // Get FCM token
  final token = await messaging.getToken();
  debugPrint('🔑 FCM Token: $token');
  print('═══════════════════════════════════════════════════════════');
  print('📱 FCM TOKEN FOR THIS DEVICE:');
  print('$token');
  print('═══════════════════════════════════════════════════════════');
  
  // Subscribe to "all_devices" topic
  try {
    await messaging.subscribeToTopic('all_devices');
    debugPrint('✅ Subscribed to topic: all_devices');
    print('✅ Successfully subscribed to topic: all_devices');
  } catch (e) {
    debugPrint('❌ Failed to subscribe to topic: $e');
    print('❌ Failed to subscribe to topic: $e');
  }
  
  // Listen for token refresh
  messaging.onTokenRefresh.listen((newToken) {
    debugPrint('🔄 FCM Token refreshed: $newToken');
    print('═══════════════════════════════════════════════════════════');
    print('🔄 NEW FCM TOKEN:');
    print('$newToken');
    print('═══════════════════════════════════════════════════════════');
    // Re-subscribe to topic with new token
    messaging.subscribeToTopic('all_devices');
  });
  
  runApp(const ElEmamApp());
}

class ElEmamApp extends StatelessWidget {
  const ElEmamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'El-Emam - Law Studies',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const WebViewScreen(),
    );
  }
}

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  InAppWebViewController? _webViewController;
  double _loadingProgress = 0.0;
  bool _isLoading = true;
  String? _errorMessage;
  bool _hasLoadedSuccessfully = false;
  final String _initialUrl = 'https://el-emam.anmka.com';

  @override
  void initState() {
    super.initState();
    _initializeScreenProtector();
    _setupFCMListeners();
  }
  
  /// Set up Firebase Cloud Messaging listeners
  void _setupFCMListeners() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📨 Foreground message: ${message.notification?.title}');
      
      if (message.notification != null) {
        _showNotification(message);
      }
    });
    
    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('📬 Notification opened: ${message.notification?.title}');
      // Handle navigation based on notification data
      if (message.data['url'] != null) {
        _webViewController?.loadUrl(
          urlRequest: URLRequest(url: WebUri(message.data['url'])),
        );
      }
    });
  }
  
  /// Show local notification for foreground messages
  Future<void> _showNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      channelDescription: 'This channel is used for important notifications.',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
    );
    
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );
    
    await flutterLocalNotificationsPlugin.show(
      message.hashCode,
      message.notification?.title ?? 'إشعار جديد',
      message.notification?.body ?? '',
      notificationDetails,
      payload: message.data['url'],
    );
  }

  /// Initialize screen protection on Android/iOS
  Future<void> _initializeScreenProtector() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        debugPrint('🛡️ Enabling Android screen protection...');
        await ScreenProtector.protectDataLeakageOn();
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        debugPrint('🛡️ Enabling iOS screenshot prevention...');
        await ScreenProtector.preventScreenshotOn();
      }
    } catch (e) {
      debugPrint('❌ ScreenProtector init error: $e');
    }
  }

  void _refreshWebView() {
    debugPrint('🔄 Refreshing WebView...');
    if (mounted) {
      setState(() {
        _loadingProgress = 0.0;
        _isLoading = true;
        _errorMessage = null;
        _hasLoadedSuccessfully = false;
      });
    }
    _webViewController?.reload();
  }

  @override
  void dispose() {
    // Disable screen protection when leaving
    if (defaultTargetPlatform == TargetPlatform.android) {
      ScreenProtector.protectDataLeakageOff();
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      ScreenProtector.preventScreenshotOff();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            _refreshWebView();
          },
          child: Stack(
            children: [
              InAppWebView(
                initialUrlRequest: URLRequest(
                  url: WebUri(_initialUrl),
                ),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  javaScriptCanOpenWindowsAutomatically: true,
                  mediaPlaybackRequiresUserGesture: false,
                  allowsInlineMediaPlayback: true,
                  mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                  useHybridComposition: true,
                  useShouldOverrideUrlLoading: true,
                  allowFileAccessFromFileURLs: true,
                  allowUniversalAccessFromFileURLs: true,
                  domStorageEnabled: true,
                  databaseEnabled: true,
                  cacheEnabled: true,
                  clearCache: false,
                  supportZoom: true,
                  builtInZoomControls: true,
                  displayZoomControls: false,
                  userAgent: 'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
                  // Prevent popups and dialogs
                  supportMultipleWindows: false,
                  disableContextMenu: true,
                ),
                onWebViewCreated: (controller) {
                  _webViewController = controller;
                  debugPrint('🔧 WebView created');
                },
                onLoadStart: (controller, url) {
                  debugPrint('🚀 Page started loading: $url');
                  if (mounted) {
                    setState(() {
                      _loadingProgress = 0.0;
                      _isLoading = true;
                      _errorMessage = null;
                    });
                  }
                },
                onLoadStop: (controller, url) async {
                  debugPrint('✅ Page finished loading: $url');
                  if (mounted) {
                    setState(() {
                      _loadingProgress = 1.0;
                      _isLoading = false;
                      _hasLoadedSuccessfully = true;
                      _errorMessage = null;
                    });
                  }
                },
                onProgressChanged: (controller, progress) {
                  debugPrint('📊 Loading progress: $progress%');
                  if (mounted) {
                    setState(() {
                      _loadingProgress = progress / 100;
                    });
                  }
                },
                onReceivedError: (controller, request, error) {
                  debugPrint('❌ WebView Error: ${error.description}');
                  if (!_hasLoadedSuccessfully) {
                    if (mounted) {
                      setState(() {
                        _errorMessage = 'خطأ في تحميل الصفحة: ${error.description}';
                        _isLoading = false;
                      });
                    }
                  }
                },
                onPermissionRequest: (controller, request) async {
                  debugPrint('🎥 Permission requested: ${request.resources}');
                  // Automatically grant all permissions without showing popup
                  return PermissionResponse(
                    resources: request.resources,
                    action: PermissionResponseAction.GRANT,
                  );
                },
                onJsAlert: (controller, jsAlertRequest) async {
                  // Block JavaScript alerts
                  return JsAlertResponse(
                    handledByClient: true,
                  );
                },
                onJsConfirm: (controller, jsConfirmRequest) async {
                  // Block JavaScript confirms
                  return JsConfirmResponse(
                    handledByClient: true,
                    action: JsConfirmResponseAction.CONFIRM,
                  );
                },
                onJsPrompt: (controller, jsPromptRequest) async {
                  // Block JavaScript prompts
                  return JsPromptResponse(
                    handledByClient: true,
                    action: JsPromptResponseAction.CONFIRM,
                  );
                },
                shouldOverrideUrlLoading: (controller, navigationAction) async {
                  final url = navigationAction.request.url;
                  debugPrint('🧭 Navigation request: $url');
                  
                  if (url != null) {
                    final urlString = url.toString();
                    
                    // Handle Android Intent URLs specially
                    if (urlString.startsWith('intent://')) {
                      try {
                        // Parse the intent URL to extract the actual scheme and package
                        // Format: intent://...#Intent;scheme=SCHEME;package=PACKAGE;end
                        final intentMatch = RegExp(r'intent://(.+)#Intent;scheme=([^;]+);package=([^;]+);end').firstMatch(urlString);
                        
                        if (intentMatch != null) {
                          final scheme = intentMatch.group(2);
                          final packageName = intentMatch.group(3);
                          final path = intentMatch.group(1);
                          
                          // Try the app-specific scheme first (e.g., fb-messenger://)
                          final appUrl = '$scheme://$path';
                          debugPrint('🔄 Trying app URL: $appUrl');
                          
                          try {
                            final uri = Uri.parse(appUrl);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                              debugPrint('✅ Opened with app scheme: $appUrl');
                              return NavigationActionPolicy.CANCEL;
                            }
                          } catch (e) {
                            debugPrint('⚠️ App scheme failed, trying package: $e');
                          }
                          
                          // If app scheme fails, try opening the package directly
                          final marketUrl = 'market://details?id=$packageName';
                          try {
                            final uri = Uri.parse(marketUrl);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                              debugPrint('✅ Opened Play Store for: $packageName');
                            }
                          } catch (e) {
                            debugPrint('❌ Could not open app or Play Store: $e');
                          }
                        }
                      } catch (e) {
                        debugPrint('❌ Error parsing intent URL: $e');
                      }
                      return NavigationActionPolicy.CANCEL;
                    }
                    
                    // Check if it's an external URL scheme (WhatsApp, tel, mailto, etc.)
                    if (urlString.startsWith('whatsapp://') ||
                        urlString.startsWith('tel:') ||
                        urlString.startsWith('mailto:') ||
                        urlString.startsWith('sms:') ||
                        urlString.startsWith('fb://') ||
                        urlString.startsWith('fb-messenger://') ||
                        urlString.startsWith('instagram://') ||
                        urlString.startsWith('twitter://') ||
                        urlString.startsWith('tg://')) {
                      // Try to launch the external app
                      try {
                        final uri = Uri.parse(urlString);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                          debugPrint('✅ Opened external app: $urlString');
                        } else {
                          debugPrint('❌ Cannot launch: $urlString');
                        }
                      } catch (e) {
                        debugPrint('❌ Error launching URL: $e');
                      }
                      return NavigationActionPolicy.CANCEL;
                    }
                    
                    // Check if it's trying to open a new window/tab
                    if (!navigationAction.isForMainFrame) {
                      // Open external links in external browser
                      try {
                        final uri = Uri.parse(urlString);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                          debugPrint('✅ Opened in external browser: $urlString');
                        }
                      } catch (e) {
                        debugPrint('❌ Error opening external link: $e');
                      }
                      return NavigationActionPolicy.CANCEL;
                    }
                  }
                  
                  return NavigationActionPolicy.ALLOW;
                },
                onConsoleMessage: (controller, consoleMessage) {
                  debugPrint('📝 Console: ${consoleMessage.message}');
                },
              ),

              if (_isLoading && _loadingProgress < 1.0)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    value: _loadingProgress,
                    backgroundColor: Colors.grey[200],
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
                    minHeight: 3,
                  ),
                ),


            ],
          ),
        ),
      ),
    );
  }
}