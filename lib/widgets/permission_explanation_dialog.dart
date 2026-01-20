import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class PermissionExplanationDialog extends StatelessWidget {
  final String title;
  final String description;
  final String lottieAsset;
  final VoidCallback onAccepted;
  final VoidCallback onDenied;

  const PermissionExplanationDialog({
    super.key,
    required this.title,
    required this.description,
    required this.lottieAsset,
    required this.onAccepted,
    required this.onDenied,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E2837),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      contentPadding: const EdgeInsets.all(24),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Lottie Animation
          SizedBox(
            height: 150,
            child: Lottie.asset(
              lottieAsset,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.security, size: 80, color: Colors.blue);
              },
            ),
          ),
          const SizedBox(height: 20),
          // Title
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          // Description
          Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          // Buttons
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: onDenied,
                  child: const Text('Deny',
                      style: TextStyle(color: Colors.redAccent)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onAccepted,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Allow',
                      style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
