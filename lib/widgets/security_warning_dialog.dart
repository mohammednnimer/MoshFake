import 'package:flutter/material.dart';

class SecurityWarningDialog extends StatelessWidget {
  final bool isScam;
  final bool isAi;
  final VoidCallback onHangUp;
  final VoidCallback onContinue;
  final String title;
  final String? overrideDescription;

  const SecurityWarningDialog({
    super.key,
    required this.isScam,
    required this.isAi,
    required this.onHangUp,
    required this.onContinue,
    required this.title,
    this.overrideDescription,
  });

  @override
  Widget build(BuildContext context) {
    // Scam takes precedence for severity color
    final isSevere = isScam;
    final primaryColor = isSevere ? Colors.red : Colors.orange;
    final icon = isSevere ? Icons.dangerous_rounded : Icons.warning_rounded;
    final backgroundColor = const Color(0xFF1A2942);

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: primaryColor, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 48,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              if (overrideDescription != null)
                Text(
                  overrideDescription!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    height: 1.5,
                  ),
                )
              else ...[
                if (isAi)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.graphic_eq, color: Colors.orange, size: 20),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            "This is not a real person. It is an artificial intelligence voice trying to speak to you.",
                            style: TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (isScam)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          "This person is flagged as a potential scammer trying to steal your data.",
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onHangUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                  child: const Text(
                    'Hang up call',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: onContinue,
                child: Text(
                  'Continue with the call',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
