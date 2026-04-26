import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;

import 'providers/bluetooth_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/checklist_screen.dart';
import 'screens/airway_bill_screen.dart';
import 'screens/transactions_screen.dart';
import 'screens/qr_code_screen.dart';
import 'screens/history_screen.dart';
import 'screens/ocr_screen.dart';
import 'screens/camera_print_screen.dart';
import 'screens/schedule_screen.dart';
import 'screens/log_viewer_screen.dart';
import 'screens/profile_screen.dart';
import 'services/print_service.dart';
import 'services/logging_service.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final logger = LoggingService();
  await logger.log("Application Started: PANTAS PRINT v8.5 Professional");
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BluetoothProvider()),
        Provider(create: (_) => PrintService()),
        Provider(create: (_) => StorageService()),
      ],
      child: const PantasPrintApp(),
    ),
  );
}

class PantasPrintApp extends StatefulWidget {
  const PantasPrintApp({super.key});

  @override
  State<PantasPrintApp> createState() => _PantasPrintAppState();
}

class _PantasPrintAppState extends State<PantasPrintApp> {
  late StreamSubscription _intentDataStreamSubscription;
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  final GlobalKey<ScaffoldMessengerState> _messengerKey = GlobalKey<ScaffoldMessengerState>();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final LoggingService _logger = LoggingService();

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
    _initShareIntent();
  }

  void _initDeepLinks() {
    _appLinks = AppLinks();
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _logger.log("Deep Link received: $uri");
      _handleDeepLink(uri);
    });
  }

  void _initShareIntent() {
    _intentDataStreamSubscription = ReceiveSharingIntent.instance.getMediaStream().listen((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        _logger.log("Share Intent received: ${value.length} files");
        _handleSharedFiles(value);
      }
    }, onError: (err) {
      _logger.log("Share Intent Error: $err");
    });

    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        _logger.log("Initial Share Intent received: ${value.length} files");
        _handleSharedFiles(value);
      }
    });
  }

  void _showPrintConfirmation({required String title, required String content, required Function onConfirm}) {
    final context = _navigatorKey.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E2A5E))),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () {
              _logger.log("Print cancelled by user: $title");
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _logger.log("Print confirmed by user: $title");
              Navigator.pop(context);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E2A5E), foregroundColor: Colors.white),
            child: const Text('Print Now'),
          ),
        ],
      ),
    );
  }

  void _handleDeepLink(Uri uri) async {
    if (uri.scheme == 'pantasprint' && uri.host == 'print') {
      final text = uri.queryParameters['text'];
      if (text != null && text.isNotEmpty) {
        _showPrintConfirmation(
          title: 'Direct Print Request',
          content: 'Web app is requesting to print a report. Do you want to proceed?',
          onConfirm: () async {
            final context = _navigatorKey.currentContext!;
            final btProvider = Provider.of<BluetoothProvider>(context, listen: false);
            final printService = Provider.of<PrintService>(context, listen: false);
            
            if (btProvider.isConnected) {
              _logger.log("Starting Deep Link print...");
              final bytes = await printService.generateTextTicket(text);
              btProvider.connection?.output.add(Uint8List.fromList(bytes));
              await btProvider.connection?.output.allSent;
              _logger.log("Deep Link print sent to printer.");
            } else {
              _logger.log("Deep Link print failed: No printer connected.");
              _messengerKey.currentState?.showSnackBar(
                const SnackBar(content: Text('No printer connected.')),
              );
            }
          }
        );
      }
    }
  }

  @override
  void dispose() {
    _intentDataStreamSubscription.cancel();
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _handleSharedFiles(List<SharedMediaFile> files) async {
    for (var file in files) {
      if (file.path.isNotEmpty) {
        final fileName = p.basename(file.path);
        _showPrintConfirmation(
          title: 'Print Shared File',
          content: 'Do you want to print: $fileName?',
          onConfirm: () async {
            final context = _navigatorKey.currentContext!;
            final btProvider = Provider.of<BluetoothProvider>(context, listen: false);
            final printService = Provider.of<PrintService>(context, listen: false);

            if (!btProvider.isConnected) {
              _logger.log("Shared file print failed: No printer connected.");
              _messengerKey.currentState?.showSnackBar(
                const SnackBar(content: Text('Please connect to a printer first.')),
              );
              return;
            }

            final fileExtension = p.extension(file.path).toLowerCase();
            try {
              _logger.log("Processing shared file: $fileName");
              List<int> ticket;
              if (fileExtension == '.jpg' || fileExtension == '.jpeg' || fileExtension == '.png') {
                final bytes = await File(file.path).readAsBytes();
                ticket = await printService.generateImageTicket(bytes);
              } else if (fileExtension == '.pdf') {
                ticket = await printService.generatePdfTicket(file.path);
              } else {
                _logger.log("Shared file type not supported: $fileExtension");
                _messengerKey.currentState?.showSnackBar(
                  SnackBar(content: Text('Unsupported file type: $fileExtension'))
                );
                return;
              }

              btProvider.connection?.output.add(Uint8List.fromList(ticket));
              await btProvider.connection?.output.allSent;
              _logger.log("Shared file sent to printer: $fileName");
            } catch (e) {
              _logger.log("Error printing shared file: $e");
              _messengerKey.currentState?.showSnackBar(
                SnackBar(content: Text('Error printing: $e')),
              );
            }
          }
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PANTAS PRINT',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _messengerKey,
      theme: ThemeData(
        primaryColor: const Color(0xFF1E2A5E),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E2A5E),
          primary: const Color(0xFF1E2A5E),
          secondary: const Color(0xFFD4AF37),
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Color(0xFF1E2A5E),
          foregroundColor: Colors.white,
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/home': (context) => const HomeScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/airway': (context) => const AirwayBillScreen(),
        '/transactions': (context) => const TransactionsScreen(),
        '/ocr': (context) => const OcrScreen(),
        '/qr': (context) => const QrCodeScreen(),
        '/checklist': (context) => const ChecklistScreen(),
        '/history': (context) => const HistoryScreen(),
        '/camera': (context) => const CameraPrintScreen(),
        '/schedule': (context) => const ScheduleScreen(),
        '/logs': (context) => const LogViewerScreen(),
      },
    );
  }
}
