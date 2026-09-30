import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/chat_provider.dart';
import 'providers/coin_provider.dart';
import 'providers/mood_provider.dart';
import 'providers/user_provider.dart';
import 'providers/voice_provider.dart';
import 'screens/splash/splash_screen.dart';
import 'services/gemini_ai_service.dart';
import 'services/storage_service.dart';
import 'services/voice_service.dart';
import 'services/firebase_notification_service.dart';
import 'services/notification_campaign_service.dart';
import 'services/revenue_cat_service.dart';
import 'services/analytics_service.dart';
import 'theme/app_theme.dart';
import 'widgets/responsive_frame.dart';

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Maximize in-memory image cache for instantaneous image rendering across all screens
  PaintingBinding.instance.imageCache.maximumSize = 1000;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 250 << 20; // 250 MB

  // Enforce strictly vertical orientation across the entire app
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final storageService = StorageService();
  await storageService.init();

  // Initialize Firebase Cloud Messaging and 3x Daily Retention Campaign Services
  await FirebaseNotificationService().init();
  await NotificationCampaignService().init();

  // Initialize Firebase Analytics (Google Analytics 4)
  await AnalyticsService().init();
  AnalyticsService().setUserId(storageService.getOrCreateDeviceId());

  // Initialize RevenueCat In-App Purchases & Subscriptions
  await RevenueCatService().init(storageService: storageService);

  // Pre-warm Gemini HTTP/TLS socket in background for sub-second first response
  GeminiAiService().warmUp(storageService);

  final voiceService = VoiceService();
  voiceService.setStorageService(storageService);
  await voiceService.init();

  runApp(
    LoviaApp(
      storageService: storageService,
      voiceService: voiceService,
    ),
  );
}

class LoviaApp extends StatefulWidget {
  final StorageService storageService;
  final VoiceService voiceService;

  const LoviaApp({
    super.key,
    required this.storageService,
    required this.voiceService,
  });

  @override
  State<LoviaApp> createState() => _LoviaAppState();
}

class _LoviaAppState extends State<LoviaApp> with WidgetsBindingObserver {
  CoinProvider? _coinProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      final storage = widget.storageService;
      final coins = storage.getCoins();
      final subExpiry = storage.getSubscriptionExpiry();
      final isSubscribed = subExpiry != null && DateTime.now().isBefore(subExpiry);

      NotificationCampaignService().onAppBackgrounded(
        storage: storage,
        isSubscribed: isSubscribed,
        coinBalance: coins,
      );
    } else if (state == AppLifecycleState.resumed) {
      // Re-verify subscription validity from store and sync any refund deductions
      RevenueCatService().checkAndSyncStatus();
      _coinProvider?.syncPendingAdjustments();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<CoinProvider>(
          create: (_) {
            final cp = CoinProvider(widget.storageService);
            _coinProvider = cp;
            RevenueCatService().attachCoinProvider(cp);
            return cp;
          },
        ),
        ChangeNotifierProvider<UserProvider>(
          create: (_) => UserProvider(widget.storageService),
        ),
        ChangeNotifierProxyProvider<UserProvider, MoodProvider>(
          create: (ctx) {
            final mp = MoodProvider(widget.storageService);
            mp.updateBlockedCharacters(ctx.read<UserProvider>().blockedCharacterIds);
            return mp;
          },
          update: (ctx, userProv, previous) {
            final mp = previous ?? MoodProvider(widget.storageService);
            mp.updateBlockedCharacters(userProv.blockedCharacterIds);
            return mp;
          },
        ),
        ChangeNotifierProxyProvider2<CoinProvider, UserProvider, ChatProvider>(
          create: (ctx) => ChatProvider(
            storage: widget.storageService,
            coinProvider: ctx.read<CoinProvider>(),
            userProvider: ctx.read<UserProvider>(),
          ),
          update: (ctx, coinProv, userProv, previous) =>
              previous ??
              ChatProvider(
                storage: widget.storageService,
                coinProvider: coinProv,
                userProvider: userProv,
              ),
        ),
        ChangeNotifierProxyProvider2<CoinProvider, ChatProvider, VoiceProvider>(
          create: (ctx) => VoiceProvider(
            voiceService: widget.voiceService,
            coinProvider: ctx.read<CoinProvider>(),
            storageService: widget.storageService,
            chatProvider: ctx.read<ChatProvider>(),
          ),
          update: (ctx, coinProv, chatProv, previous) {
            previous?.setChatProvider(chatProv);
            return previous ??
                VoiceProvider(
                  voiceService: widget.voiceService,
                  coinProvider: coinProv,
                  storageService: widget.storageService,
                  chatProvider: chatProv,
                );
          },
        ),
      ],
      child: MaterialApp(
        navigatorKey: null,
        scaffoldMessengerKey: rootScaffoldMessengerKey,
        navigatorObservers: [
          if (AnalyticsService().navigatorObserver != null)
            AnalyticsService().navigatorObserver!,
        ],
        title: 'Lovia - AI Roleplay',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        builder: (context, child) {
          return ResponsiveFrame(
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const SplashScreen(),
      ),
    );
  }
}