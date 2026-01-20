import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../providers/call_provider.dart';
import '../../providers/contact_provider.dart';
import '../../models/call_model.dart';
import '../../models/contact_model.dart';
import '../../services/call_service.dart';
import '../call/active_call_screen.dart';
import '../../utils/permission_helper.dart';

class RecentCallsPage extends StatefulWidget {
  const RecentCallsPage({super.key});

  @override
  State<RecentCallsPage> createState() => _RecentCallsPageState();
}

class _RecentCallsPageState extends State<RecentCallsPage> {
  final ScrollController _scrollController = ScrollController();
  int _displayedCount = 10;
  final int _batchSize = 10;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final totalCalls =
          Provider.of<CallProvider>(context, listen: false).recentCalls.length;
      if (_displayedCount < totalCalls) {
        setState(() {
          _displayedCount += _batchSize;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Calls',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Provider.of<CallProvider>(context, listen: false)
                        .loadCalls();
                  },
                  icon: const Icon(
                    Icons.refresh,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0A1929),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: Consumer2<CallProvider, ContactProvider>(
                builder: (context, callProvider, contactProvider, child) {
                  final allCalls = callProvider.recentCalls;

                  if (allCalls.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history,
                            size: 64,
                            color: Colors.white38,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No recent calls',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final displayCalls = allCalls.take(_displayedCount).toList();
                  final hasMore = displayCalls.length < allCalls.length;

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: displayCalls.length + (hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == displayCalls.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(
                            child: CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white70),
                            ),
                          ),
                        );
                      }

                      final call = displayCalls[index];
                      // Try to find contact
                      ContactModel? linkContact;
                      try {
                        linkContact = contactProvider.contacts.firstWhere(
                          (c) =>
                              c.phoneNumber.replaceAll(' ', '') ==
                              call.contactNumber.replaceAll(' ', ''),
                        );
                      } catch (_) {}

                      return _RecentCallTile(
                        call: call,
                        contact: linkContact,
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentCallTile extends StatefulWidget {
  final CallModel call;
  final ContactModel? contact;

  const _RecentCallTile({required this.call, this.contact});

  @override
  State<_RecentCallTile> createState() => _RecentCallTileState();
}

class _RecentCallTileState extends State<_RecentCallTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final displayName = widget.contact?.name ??
        (widget.call.contactName.isNotEmpty
            ? widget.call.contactName
            : widget.call.contactNumber);
    final displayImage = widget.contact?.imagePath;
    final displayAvatarUrl = widget.contact?.avatarUrl;

    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2942),
              borderRadius: _isExpanded
                  ? const BorderRadius.vertical(top: Radius.circular(16))
                  : BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: widget.contact?.avatarColor != null
                      ? Color(widget.contact!.avatarColor)
                      : Colors.blueGrey,
                  backgroundImage: displayImage != null
                      ? FileImage(File(displayImage)) as ImageProvider
                      : (displayAvatarUrl != null
                          ? NetworkImage(displayAvatarUrl)
                          : null),
                  child: (displayImage == null && displayAvatarUrl == null)
                      ? Text(
                          displayName.isNotEmpty
                              ? displayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(color: Colors.white),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            widget.call.callType == CallType.incoming
                                ? Icons.call_received
                                : (widget.call.callType == CallType.outgoing
                                    ? Icons.call_made
                                    : Icons.call_missed),
                            size: 14,
                            color: widget.call.callType == CallType.missed
                                ? Colors.red
                                : Colors.green,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('MMM d, h:mm a')
                                .format(widget.call.timestamp),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      widget.call.formattedDuration,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                    if (widget.call.isScamDetected || widget.call.isAiDetected)
                      const Icon(Icons.warning, color: Colors.orange, size: 16),
                  ],
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: Container(height: 0),
          secondChild: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF132036),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _ActionButton(
                      icon: Icons.call,
                      label: 'Call',
                      color: Colors.green,
                      onTap: () async {
                        bool hasPermission =
                            await PermissionHelper.checkAndRequestMicrophone(
                                context);
                        if (!hasPermission) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        "Microphone needed to make call.")));
                          }
                          return;
                        }
                        if (!context.mounted) return;

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ActiveCallScreen(
                              userId: widget.call.contactNumber,
                              contactName: displayName,
                            ),
                          ),
                        );
                      },
                    ),
                    _ActionButton(
                      icon: widget.contact != null
                          ? Icons.edit
                          : Icons.person_add,
                      label: widget.contact != null ? 'Edit' : 'Add Info',
                      color: Colors.blue,
                      onTap: () {
                        _showAddContactSheet(context, widget.call.contactNumber,
                            contact: widget.contact);
                      },
                    ),
                    _ActionButton(
                      icon: Icons.block,
                      label: widget.call.isBlocked ? 'Unblock' : 'Block',
                      color: Colors.red,
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: const Color(0xFF1A2942),
                            title: Text(
                                widget.call.isBlocked
                                    ? 'Unblock Contact'
                                    : 'Block Contact',
                                style: const TextStyle(color: Colors.white)),
                            content: Text(
                                widget.call.isBlocked
                                    ? 'Are you sure you want to unblock this contact?'
                                    : 'Are you sure you want to block this contact? They will not be able to call you.',
                                style: const TextStyle(color: Colors.white70)),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Provider.of<CallProvider>(context,
                                          listen: false)
                                      .updateCallStatus(widget.call.id,
                                          isBlocked: !widget.call.isBlocked);
                                  Navigator.pop(context);
                                  setState(() {});
                                },
                                child: Text(
                                    widget.call.isBlocked ? 'Unblock' : 'Block',
                                    style: const TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),

                // WARNING SECTION
                // Display notes only if flagged
                if (widget.call.isAiDetected || widget.call.isScamDetected) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.call.isAiDetected)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.mic_off,
                                    color: Colors.orange, size: 16),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "Note: This is not a real person, it's created with artificial intelligence, do not share any data.",
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (widget.call.isScamDetected)
                          const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.warning_amber_rounded,
                                  color: Colors.red, size: 16),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Note: This person is trying to steal your data, don't give him any of your information.",
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],

                const Divider(color: Colors.white24, height: 24),
                // FLAG BUTTONS
                Row(
                  children: [
                    Expanded(
                      child: _StatusButton(
                        label: 'Flag as Scam',
                        icon: Icons.warning,
                        color: Colors.red,
                        isActive: widget.call.isScamDetected,
                        onTap: () {
                          final provider =
                              Provider.of<CallProvider>(context, listen: false);
                          final contactProvider = Provider.of<ContactProvider>(
                              context,
                              listen: false);
                          final newState = !widget.call.isScamDetected;

                          provider.flagNumber(widget.call.contactNumber,
                              isScam: newState);
                          contactProvider.updateContactFlags(
                              widget.call.contactNumber,
                              isScam: newState);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatusButton(
                        label: 'Flag as AI',
                        icon: Icons.graphic_eq,
                        color: Colors.orange,
                        isActive: widget.call.isAiDetected,
                        onTap: () {
                          final provider =
                              Provider.of<CallProvider>(context, listen: false);
                          final contactProvider = Provider.of<ContactProvider>(
                              context,
                              listen: false);
                          final newState = !widget.call.isAiDetected;

                          provider.flagNumber(widget.call.contactNumber,
                              isAi: newState);
                          contactProvider.updateContactFlags(
                              widget.call.contactNumber,
                              isAi: newState);
                        },
                      ),
                    ),
                  ],
                ),
                if (widget.call.isScamDetected || widget.call.isAiDetected) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: const Color(0xFF1A2942),
                            title: const Text('Mark as Safe?',
                                style: TextStyle(color: Colors.white)),
                            content: const Text(
                                "Are you sure? Our algorithms detected potential security risks with this caller.",
                                style: TextStyle(color: Colors.white70)),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  final provider = Provider.of<CallProvider>(
                                      context,
                                      listen: false);
                                  final contactProvider =
                                      Provider.of<ContactProvider>(context,
                                          listen: false);

                                  provider.flagNumber(widget.call.contactNumber,
                                      isScam: false, isAi: false, isSafe: true);
                                  contactProvider.updateContactFlags(
                                      widget.call.contactNumber,
                                      isSafe: true);

                                  Navigator.pop(context);
                                },
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green),
                                child: const Text('Mark as Safe',
                                    style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.check_circle_outline,
                          color: Colors.green),
                      label: const Text('Mark as Safe',
                          style: TextStyle(color: Colors.green)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.green),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          crossFadeState: _isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  void _showAddContactSheet(BuildContext context, String phoneNumber,
      {ContactModel? contact}) {
    final nameController = TextEditingController(text: contact?.name);
    final phoneController = TextEditingController(
        text: phoneNumber); // Use existing number if editing or adding
    if (contact != null) phoneController.text = contact.phoneNumber;

    final imagePathNotifier = ValueNotifier<String?>(contact?.imagePath);
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A2942),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              contact == null ? 'Add Contact' : 'Edit Contact',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: ValueListenableBuilder<String?>(
                valueListenable: imagePathNotifier,
                builder: (context, path, _) {
                  return GestureDetector(
                    onTap: () async {
                      final ImagePicker picker = ImagePicker();
                      final XFile? image =
                          await picker.pickImage(source: ImageSource.gallery);
                      if (image != null) {
                        imagePathNotifier.value = image.path;
                      }
                    },
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.white.withOpacity(0.1),
                          backgroundImage: path != null
                              ? FileImage(File(path))
                              : (contact?.avatarUrl != null
                                  ? NetworkImage(contact!.avatarUrl!)
                                      as ImageProvider
                                  : null),
                          child: path == null && contact?.avatarUrl == null
                              ? const Icon(Icons.person,
                                  size: 40, color: Colors.white54)
                              : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            Form(
              key: formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white30),
                      ),
                    ),
                    validator: (value) => value!.isEmpty ? 'Enter name' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: phoneController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white30),
                      ),
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (value) =>
                        value!.isEmpty ? 'Enter phone number' : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    final provider =
                        Provider.of<ContactProvider>(context, listen: false);
                    if (contact == null) {
                      provider.addContact(
                        nameController.text,
                        phoneController.text,
                        imagePath: imagePathNotifier.value,
                      );
                    } else {
                      provider.updateContact(ContactModel(
                        id: contact.id,
                        name: nameController.text,
                        phoneNumber: phoneController.text,
                        imagePath: imagePathNotifier.value,
                        avatarUrl: contact.avatarUrl,
                        avatarColor: contact.avatarColor,
                      ));
                    }
                    Navigator.pop(context);
                    setState(() {}); // Refresh to show the new name
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  contact == null ? 'Save Contact' : 'Update Contact',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isActive;
  final VoidCallback onTap;

  const _StatusButton(
      {required this.label,
      required this.icon,
      required this.color,
      required this.isActive,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isActive ? color : Colors.white24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isActive ? color : Colors.white70, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isActive ? color : Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.8), fontSize: 12)),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  // Deprecated/Removed in favor of _StatusButton, removed from use
  const _StatusChip();

  @override
  Widget build(BuildContext context) {
    return const SizedBox();
  }
}
