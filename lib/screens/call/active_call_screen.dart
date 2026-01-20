import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../../services/call_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/contact_provider.dart';
import '../../providers/call_provider.dart';
import '../../models/contact_model.dart';
import '../../models/call_model.dart';
import '../../widgets/security_warning_dialog.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

class ActiveCallScreen extends StatefulWidget {
  final String userId;
  final String? contactName;

  const ActiveCallScreen({
    super.key,
    required this.userId,
    this.contactName,
  });

  @override
  State<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends State<ActiveCallScreen> {
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isAiDetected = false;
  bool _isScamWarning = false;
  Timer? _callTimer;
  int _seconds = 0;

  // Demo Simulation Variables
  bool _isSimulation = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  // Map phone numbers to asset filenames
  static const Map<String, String> _simulationFiles = {
    '122': 's122.wav',
    '123': 's123.wav',
    '124': 's124.wav',
    '125': 's125.wav',
    '126': 's126.wav',
    '127': 's127.wav',
    '128': 's128.wav',
  };

  StreamSubscription<DocumentSnapshot>? _alertSubscription;

  @override
  void dispose() {
    _audioPlayer.dispose();
    _callTimer?.cancel();
    _alertSubscription?.cancel();
    final callService = Provider.of<CallService>(context, listen: false);
    callService.removeListener(_onCallStateChanged);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    // Check if this is a simulation number
    if (_simulationFiles.containsKey(widget.userId)) {
      _isSimulation = true;
    }

    _startCallTimer();

    // Initialize the call service OR Simulation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isSimulation) {
        _startSimulation();
      } else {
        final callService = Provider.of<CallService>(context, listen: false);
        final authProvider = Provider.of<AuthProvider>(context, listen: false);

        // Listen to call state changes
        callService.addListener(_onCallStateChanged);

        // Start the call if not already connected
        if (callService.callState == CallState.idle) {
          // Send MY phone number (or name) so the receiver sees who is calling
          final myIdentity = authProvider.user?.phoneNumber.isNotEmpty == true
              ? authProvider.user!.phoneNumber
              : (authProvider.user?.name ?? 'Unknown');

          callService.makeCall(widget.userId, myIdentity);

          // Listen for security alerts from Server via Firestore
          _listenForServerAlerts(callService.currentCallId);
        }
      }

      _checkInitialSecurityStatus();
    });

    // Remove old fake timer logic
  }

  void _listenForServerAlerts(String? callId) {
    if (callId == null) return;

    // Safety check: if we already have a subscription for this call, don't recreate
    _alertSubscription?.cancel();

    _alertSubscription = FirebaseFirestore.instance
        .collection('calls')
        .doc(callId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data();
        if (data != null && data.containsKey('security_alert')) {
          final alert = data['security_alert'] as Map<String, dynamic>;
          final isAi = alert['is_ai'] == true;
          final isScam = alert['is_scam'] == true;

          // Only trigger if new threat detected and not already shown
          bool isNewThreat =
              (isAi && !_isAiDetected) || (isScam && !_isScamWarning);

          if (isNewThreat) {
            setState(() {
              if (isAi) _isAiDetected = true;
              if (isScam) _isScamWarning = true;
            });

            // Flag locally
            final callProvider =
                Provider.of<CallProvider>(context, listen: false);
            callProvider.flagNumber(widget.userId, isAi: isAi, isScam: isScam);

            _showSecurityWarning(
                isAi: isAi,
                isScam: isScam,
                title: 'Real-time Threat Detected',
                description:
                    "The analysis server has detected potential security threats in this call.");
          }
        }
      }
    });
  }

  Future<void> _startSimulation() async {
    final fileName = _simulationFiles[widget.userId];
    if (fileName == null) return;

    try {
      // Play audio loop or once? Phone calls usually continuous... but files are chunks.
      // User said "display the sound of that file".
      await _audioPlayer.play(AssetSource('audio/$fileName'));

      // Analyze
      await _analyzeSimulationAudio(fileName);
    } catch (e) {
      debugPrint('Simulation error: $e');
    }
  }

  Future<void> _analyzeSimulationAudio(String fileName) async {
    try {
      // Read asset file
      final byteData = await rootBundle.load('assets/audio/$fileName');
      final bytes = byteData.buffer.asUint8List();

      // Call API
      // Using localhost:8000. Ensure API is running.
      // Use 10.0.2.2 for Android Emulator to access host localhost
      final host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
      final uri = Uri.parse('http://$host:8000/call/analyze/');

      final request = http.MultipartRequest('POST', uri);
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // data['ai_detection'] from DeepFake/detect.py analyze()
        final aiData = data['ai_detection'];
        final isAi = aiData != null &&
            (aiData['decision'] == 'AI-GENERATED' ||
                aiData['decision'] == 'spoof' ||
                aiData['is_deepfake'] == true);

        // data['scam_detection'] from ScamDetection
        final scamData = data['scam_detection'];
        final isScam = scamData != null &&
            (scamData['is_scam'] == true || scamData['label'] == 'scam');

        if (mounted && (isAi || isScam)) {
          setState(() {
            _isAiDetected = isAi;
            _isScamWarning = isScam;
          });

          // Flag locally for simulation
          final callProvider =
              Provider.of<CallProvider>(context, listen: false);
          callProvider.flagNumber(widget.userId, isAi: isAi, isScam: isScam);

          // Construct detailed description
          String description = "";
          if (isAi) {
            final confidence = aiData != null && aiData['confidence'] != null
                ? "${(aiData['confidence'] * 100).toStringAsFixed(1)}%"
                : "High";
            description += "🤖 AI Voice Detected ($confidence confidence).\n";
          }

          if (isScam) {
            if (description.isNotEmpty) description += "\n";
            final risk = scamData['risk_level'] ?? "High";
            description += "⚠️ Scam Risk Level: $risk\n";

            final flags = scamData['flags'];
            if (flags is List && flags.isNotEmpty) {
              final formattedFlags = flags
                  .map((e) => e.toString().replaceAll('_', ' '))
                  .join(', ');
              description += "Reasons: $formattedFlags";
            }
          }

          _showSecurityWarning(
            isAi: isAi,
            isScam: isScam,
            title: isAi && isScam
                ? 'CRITICAL THREAT DETECTED'
                : (isScam ? 'POTENTIAL SCAM' : 'ARTIFICIAL INTELLIGENCE VOICE DETECTED'),
            description: description,
          );
        }
      } else {
        debugPrint('API Error: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('Analysis error: $e');
    }
  }

  void _checkInitialSecurityStatus() {
    // Check Contact Store first
    final contactProvider =
        Provider.of<ContactProvider>(context, listen: false);
    bool foundInContacts = false;

    try {
      final contact = contactProvider.contacts.firstWhere(
        (c) =>
            c.phoneNumber.replaceAll(' ', '') ==
            widget.userId.replaceAll(' ', ''),
      );

      if (contact.isAi || contact.isScam) {
        foundInContacts = true;
        setState(() {
          _isAiDetected = contact.isAi;
          _isScamWarning = contact.isScam;
        });

        String description = "This user called you before and was flagged as ";
        if (contact.isAi && contact.isScam) {
          description += "both an AI voice and a potential scammer.";
        } else if (contact.isAi) {
          description += "an AI voice.";
        } else {
          description += "a potential scammer.";
        }

        _showSecurityWarning(
          isAi: contact.isAi,
          isScam: contact.isScam,
          title: 'Previous Security Flag',
          description: description,
        );
      }
    } catch (_) {}

    // If not found in contacts (or contact clean), check Call History
    if (!foundInContacts) {
      final callProvider = Provider.of<CallProvider>(context, listen: false);
      final historyCalls = callProvider.recentCalls
          .where((c) =>
              c.contactNumber.replaceAll(' ', '') ==
              widget.userId.replaceAll(' ', ''))
          .toList();

      bool histAi = historyCalls.any((c) => c.isAiDetected);
      bool histScam = historyCalls.any((c) => c.isScamDetected);

      if (histAi || histScam) {
        setState(() {
          _isAiDetected = histAi;
          _isScamWarning = histScam;
        });

        String description = "This number was flagged in your call history as ";
        if (histAi && histScam) {
          description += "both an AI voice and a potential scammer.";
        } else if (histAi) {
          description += "an AI voice.";
        } else {
          description += "a potential scammer.";
        }

        _showSecurityWarning(
          isAi: histAi,
          isScam: histScam,
          title: 'Previous Security Flag',
          description: description,
        );
      }
    }
  }

  void _performEndCall() {
    if (_isSimulation) {
      _audioPlayer.stop();
      _callTimer?.cancel();
      // Simulation doesn't use CallService listeners to close
      if (mounted) Navigator.of(context).pop();
    } else {
      final callService = Provider.of<CallService>(context, listen: false);
      callService.endCall();
      // The listener _onCallStateChanged will handle the pop for real calls
    }
  }

  void _showSecurityWarning(
      {required bool isAi,
      required bool isScam,
      required String title,
      String? description}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => SecurityWarningDialog(
        isScam: isScam,
        isAi: isAi,
        title: title,
        overrideDescription: description,
        onHangUp: () {
          Navigator.pop(context); // Close dialog
          _performEndCall();
        },
        onContinue: () {
          Navigator.pop(context); // Close dialog
        },
      ),
    );
  }

  void _onCallStateChanged() {
    final callService = Provider.of<CallService>(context, listen: false);

    if (callService.callState == CallState.ended) {
      _saveCallRecord(callService);

      // FINAL SYNC: Ensure the new record AND all old records match the final flags
      if (_isAiDetected || _isScamWarning) {
        final callProvider = Provider.of<CallProvider>(context, listen: false);
        final contactProvider =
            Provider.of<ContactProvider>(context, listen: false);

        if (_isAiDetected) {
          callProvider.flagNumber(widget.userId, isAi: true);
          contactProvider.updateContactFlags(widget.userId, isAi: true);
        }

        if (_isScamWarning) {
          callProvider.flagNumber(widget.userId, isScam: true);
          contactProvider.updateContactFlags(widget.userId, isScam: true);
        }
      }

      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  void _saveCallRecord(CallService callService) {
    // Only save if duration > 0 or it was an incoming call (missed/rejected handled elsewhere usually, but here is active call)
    final callProvider = Provider.of<CallProvider>(context, listen: false);

    // Determine call type (defaulting to outgoing for now as this screen handles active calls)
    // If usage of ActiveCallScreen includes incoming calls that were answered, we need to know.
    // CallService has _isIncoming.

    final isIncoming = callService.isIncoming;

    final call = CallModel(
      id: const Uuid().v4(),
      contactName: widget.contactName ?? '',
      contactNumber: widget.userId,
      callType: isIncoming ? CallType.incoming : CallType.outgoing,
      duration: Duration(seconds: _seconds),
      timestamp: DateTime.now(),
      isScamDetected: _isScamWarning,
      isAiDetected: _isAiDetected,
    );

    callProvider.addCall(call);
  }

  void _startCallTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _seconds++;
      });
    });
  }

  String _formatDuration() {
    final minutes = _seconds ~/ 60;
    final secs = _seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // Resolve contact info from local storage
    final contactProvider = Provider.of<ContactProvider>(context);
    ContactModel? contact;
    try {
      contact = contactProvider.contacts.firstWhere(
        (c) =>
            c.phoneNumber.replaceAll(' ', '') ==
            widget.userId.replaceAll(' ', ''),
      );
    } catch (_) {}

    final displayName = contact?.name ?? widget.contactName ?? widget.userId;

    ImageProvider? imageProvider;
    if (contact?.imagePath != null) {
      imageProvider = FileImage(File(contact!.imagePath!));
    } else if (contact?.avatarUrl != null) {
      imageProvider = NetworkImage(contact!.avatarUrl!);
    }

    return Consumer<CallService>(
      builder: (context, callService, child) {
        String statusText;
        if (_isSimulation) {
          statusText = _formatDuration();
        } else {
          statusText = 'Connecting...';
          if (callService.callState == CallState.active) {
            statusText = _formatDuration();
          } else if (callService.callState == CallState.ringing) {
            statusText = 'Ringing...';
          }
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
                  const SizedBox(height: 40),

                  // Contact Info
                  Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white.withOpacity(0.3),
                        backgroundImage: imageProvider,
                        child: imageProvider == null
                            ? Text(
                                displayName.isNotEmpty
                                    ? displayName.substring(0, 1).toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // AI Detection Warning
                  if (_isAiDetected)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange, width: 2),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_rounded,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'AI Voice Detected',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  'This call may be using AI voice',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Scam Warning
                  if (_isScamWarning)
                    Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red, width: 2),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.dangerous_rounded,
                            color: Colors.red,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Potential Scam Detected',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  'Suspicious patterns detected',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  const Spacer(),

                  // Call Controls
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _CallControlButton(
                              icon: _isMuted ? Icons.mic_off : Icons.mic,
                              label: 'Mute',
                              isActive: _isMuted,
                              onTap: () {
                                setState(() => _isMuted = !_isMuted);
                                callService.toggleMute(_isMuted);
                              },
                            ),
                            _CallControlButton(
                              icon: _isSpeakerOn
                                  ? Icons.volume_up
                                  : Icons.volume_down,
                              label: 'Speaker',
                              isActive: _isSpeakerOn,
                              onTap: () {
                                setState(() => _isSpeakerOn = !_isSpeakerOn);
                                callService.toggleSpeaker(_isSpeakerOn);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 60),

                  // End Call Button
                  GestureDetector(
                    onTap: () {
                      _performEndCall();
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

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CallControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _CallControlButton({
    required this.icon,
    required this.label,
    this.isActive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.white.withOpacity(0.3)
                  : Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
