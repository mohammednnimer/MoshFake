import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:secure_call_app/screens/call/incominig_call_screen.dart';
import '../../providers/auth_provider.dart';
import '../../providers/contact_provider.dart';
import '../../services/call_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/app_navigation_bar.dart';
import '../../utils/permission_helper.dart';
import 'main_page.dart';
import 'recent_calls_page.dart';
import 'contacts_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      MainPage(onNavigate: (index) => setState(() => _currentIndex = index)),
      const RecentCallsPage(),
      const ContactsPage(),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeServices();
    });
  }

  Future<void> _initializeServices() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final callService = Provider.of<CallService>(context, listen: false);
    final notificationService = NotificationService();

    // Initialize notification service and get FCM token
    // We defer initialization until we explain permissions if needed
    if (mounted) {
      await PermissionHelper.checkAndRequestNotification(context,
          onGranted: () async {
        await notificationService.initialize();
      });
    }

    // Update user's FCM token in Firestore
    if (authProvider.userId.isNotEmpty) {
      await notificationService.updateUserFCMToken(authProvider.userId);
    }

    // Initialize call service with signaling
    await callService.initialize(authProvider.userId);

    // Listen for incoming calls
    callService.addListener(_onCallStateChanged);
  }

  void _onCallStateChanged() {
    final callService = Provider.of<CallService>(context, listen: false);

    if (callService.callState == CallState.ringing && callService.isIncoming) {
      // Resolve caller info from contacts
      final contactProvider =
          Provider.of<ContactProvider>(context, listen: false);

      String displayId = callService.currentCallPhoneNumber ??
          callService.currentCallUserId ??
          'Unknown';
      String displayName = callService.currentCallUserName ?? 'Unknown';

      // If we have a phone number, check contacts
      if (callService.currentCallPhoneNumber != null) {
        try {
          final contact = contactProvider.contacts.firstWhere(
            (c) =>
                c.phoneNumber.replaceAll(' ', '') ==
                callService.currentCallPhoneNumber!.replaceAll(' ', ''),
          );
          displayName = contact.name;
          displayId = contact
              .phoneNumber; // Use normalized phone from contact or just the call phone number
        } catch (_) {
          // No contact found
        }
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => IncomingCallScreen(
            callerName: displayName,
            callerId: displayId,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    final callService = Provider.of<CallService>(context, listen: false);
    callService.removeListener(_onCallStateChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0D47A1),
              Color(0xFF1E88E5),
            ],
          ),
        ),
        child: _pages[_currentIndex],
      ),
      bottomNavigationBar: AppNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
      ),
    );
  }
}
