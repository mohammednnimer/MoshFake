import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../services/call_service.dart';
import 'active_call_screen.dart';
import '../../providers/contact_provider.dart';
import '../../models/contact_model.dart';
import '../../utils/permission_helper.dart';

class IncomingCallScreen extends StatelessWidget {
  final String callerName;
  final String callerId;

  const IncomingCallScreen({
    super.key,
    required this.callerName,
    required this.callerId,
  });

  @override
  Widget build(BuildContext context) {
    // Resolve contact info
    final contactProvider = Provider.of<ContactProvider>(context);
    ContactModel? contact;
    try {
      contact = contactProvider.contacts.firstWhere(
        (c) =>
            c.phoneNumber.replaceAll(' ', '') == callerId.replaceAll(' ', ''),
      );
    } catch (_) {}

    final displayName = contact?.name ?? callerName;
    final displayImage = contact?.imagePath;
    final displayAvatarUrl = contact?.avatarUrl;

    ImageProvider? imageProvider;
    if (displayImage != null) {
      imageProvider = FileImage(File(displayImage));
    } else if (displayAvatarUrl != null) {
      imageProvider = NetworkImage(displayAvatarUrl);
    }

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
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 60),
              const Text(
                'Incoming Call',
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.white70,
                ),
              ),
              const Spacer(),
              CircleAvatar(
                radius: 60,
                backgroundColor: Colors.white.withOpacity(0.3),
                backgroundImage: imageProvider,
                child: imageProvider == null
                    ? Text(
                        displayName.isNotEmpty
                            ? displayName.substring(0, 1).toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 24),
              Text(
                displayName,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                callerId,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 60),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Decline Button
                    Column(
                      children: [
                        GestureDetector(
                          onTap: () {
                            final callService = Provider.of<CallService>(
                              context,
                              listen: false,
                            );
                            callService.endCall();
                            Navigator.pop(context);
                          },
                          child: Container(
                            width: 70,
                            height: 70,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.call_end,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Decline',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    // Accept Button
                    Column(
                      children: [
                        GestureDetector(
                          onTap: () async {
                            bool hasPermission = await PermissionHelper
                                .checkAndRequestMicrophone(context);
                            if (!hasPermission) {
                              // User denied mic, maybe can't answer properly but user might want to proceed to just listen?
                              // Usually for calls we need mic.
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          "Microphone needed to answer call.")),
                                );
                              }
                              return;
                            }

                            if (!context.mounted) return;

                            final callService = Provider.of<CallService>(
                              context,
                              listen: false,
                            );
                            await callService.answerCall();

                            if (context.mounted) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ActiveCallScreen(
                                    userId: callerId,
                                    contactName: displayName,
                                  ),
                                ),
                              );
                            }
                          },
                          child: Container(
                            width: 70,
                            height: 70,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.call,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Accept',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }
}
