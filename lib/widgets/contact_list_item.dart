import 'dart:io';
import 'package:flutter/material.dart';
import '../models/contact_model.dart';

class ContactListItem extends StatelessWidget {
  final ContactModel contact;
  final VoidCallback? onTap;
  final VoidCallback? onCall;

  const ContactListItem({
    super.key, 
    required this.contact, 
    this.onTap,
    this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    ImageProvider? imageProvider;
    if (contact.imagePath != null) {
      imageProvider = FileImage(File(contact.imagePath!));
    } else if (contact.avatarUrl != null) {
      imageProvider = NetworkImage(contact.avatarUrl!);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2942),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Color(contact.avatarColor),
          child: imageProvider != null
              ? ClipOval(
                  child: Image(
                    image: imageProvider,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Text(
                        contact.initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                  ),
                )
              : Text(
                  contact.initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                contact.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
             if (contact.isScam)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.warning, color: Colors.red, size: 16),
              ),
            if (contact.isAi)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.graphic_eq, color: Colors.orange, size: 16),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            contact.phoneNumber,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
          ),
        ),
        trailing: IconButton(
          onPressed: onCall,
          icon: Icon(
            Icons.call,
            color: Colors.blue.withOpacity(0.8),
          ),
        ),
      ),
    );
  }
}
