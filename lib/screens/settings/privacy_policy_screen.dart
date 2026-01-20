import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1929),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title:
            const Text('Privacy Policy', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              title: "Who We Are",
              content:
                  "SecureCall is an application designed to protect you from voice scams and deepfake audio. our mission is to ensure your calls are safe and authentic.",
            ),
            _buildSection(
              title: "Our Promise to You",
              content:
                  "We believe your conversations are private. We do not store your personal data, call recordings, or private conversations. We are here to analyze, protect, and then forget.",
            ),
            _buildSection(
              title: "What Information We Collect",
              content:
                  "To provide our security services, we process audio data from your calls in real-time. \n\n• Audio Data: Sent securely to our AI for analysis.\n• Account Info: Name and email for login purposes only.\n• Cookies: We do not use cookies or trackers.",
            ),
            _buildSection(
              title: "How We Use Your Information",
              content:
                  "Your audio is used strictly for detection. When a call starts, our AI listens for patterns of deepfakes or scams. Once the analysis is done, the audio data is immediately discarded. We do not use it for training or marketing.",
            ),
            _buildSection(
              title: "Data Sharing",
              content:
                  "We do not sell, trade, or rent your personal identification information to others. Your internal call data never leaves our secure processing loop.",
            ),
            _buildSection(
              title: "Data Retention",
              content:
                  "We have a zero-retention policy for call audio. It is processed in memory and wiped instantly. Your account information is kept only as long as you have an active account. If you delete your account, everything is gone.",
            ),
            _buildSection(
              title: "Your Choice (Opt-In/Opt-Out)",
              content:
                  "You are in control. You can choose to enable or disable the real-time analysis at any time via the app permissions. If you deny microphone access, no audio is processed.",
            ),
            _buildSection(
              title: "Security",
              content:
                  "We use industry-standard encryption to transmit your data to our analysis engine. While no method of transmission is 100% secure, we strive to use commercially acceptable means to protect your information.",
            ),
            _buildSection(
              title: "Children's Privacy",
              content:
                  "Our services are not intended for anyone under the age of 13. We do not knowingly collect personal information from children.",
            ),
            _buildSection(
              title: "Contact Us",
              content:
                  "If you have any questions about this Privacy Policy, please contact us at:\nsupport@securecall.com",
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
      {required String title, required String content, bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.white70,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
