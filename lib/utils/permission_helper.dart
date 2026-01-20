import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/permission_explanation_dialog.dart';

class PermissionHelper {
  static Future<bool> checkAndRequestMicrophone(BuildContext context) async {
    final status = await Permission.microphone.status;

    if (status.isGranted) {
      return true;
    }

    // Need to ask
    // Show Dialog explanation await result
    bool? userAccepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PermissionExplanationDialog(
        title: "Microphone Access",
        description:
            "We need access to your microphone to enable voice calls and perform deepfake analysis for your security.",
        lottieAsset:
            "assets/animations/microphone.json", // Ensure this asset exists or add it
        onAccepted: () => Navigator.pop(context, true),
        onDenied: () => Navigator.pop(context, false),
      ),
    );

    if (userAccepted == true) {
      final newStatus = await Permission.microphone.request();
      if (newStatus.isGranted) {
        return true;
      } else if (newStatus.isPermanentlyDenied) {
        // Show Settings Dialog
        if (context.mounted) {
          _showSettingsDialog(context, "Microphone");
        }
        return false;
      }
    }

    // User denied
    return false;
  }

  static Future<void> checkAndRequestNotification(BuildContext context,
      {required Function onGranted}) async {
    final status = await Permission.notification.status;
    if (status.isGranted) {
      onGranted();
      return;
    }

    if (await Permission.notification.isPermanentlyDenied) {
      return; // Don't annoy
    }

    // Ask explanation
    if (!context.mounted) return;
    bool? userAccepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PermissionExplanationDialog(
        title: "Stay Updated",
        description:
            "Enable notifications to receive incoming calls.",
        lottieAsset:
            "assets/animations/notification.json", // Ensure this asset exists
        onAccepted: () => Navigator.pop(context, true),
        onDenied: () => Navigator.pop(context, false),
      ),
    );

    if (userAccepted == true) {
      debugPrint("PermissionDialog: User accepted. Dialog should be closed.");
      // Ensure onGranted is awaited if it returns a Future to prevent race conditions
      final result = onGranted();
      if (result is Future) {
        await result;
      }
    } else {
      debugPrint("PermissionDialog: User denied or dismissed.");
    }
  }

  static void _showSettingsDialog(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2837),
        title: const Text('Permission Required',
            style: TextStyle(color: Colors.white)),
        content: Text(
            '$feature access is permanently denied. Please enable it in settings to use this feature.',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              openAppSettings();
              Navigator.pop(context);
            },
            child: const Text('Settings'),
          ),
        ],
      ),
    );
  }
}
