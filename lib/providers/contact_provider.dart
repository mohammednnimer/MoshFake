import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/contact_model.dart';
import 'dart:math';

class ContactProvider with ChangeNotifier {
  List<ContactModel> _contacts = [];
  List<ContactModel> _filteredContacts = [];
  bool _isLoading = false;
  
  List<ContactModel> get contacts => _filteredContacts.isNotEmpty || _isSearching ? _filteredContacts : _contacts;
  bool get isLoading => _isLoading;
  bool _isSearching = false;

  ContactProvider() {
    loadContacts();
  }

  Future<void> loadContacts() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? contactsJson = prefs.getString('local_contacts');
      
      if (contactsJson != null) {
        final List<dynamic> decodedList = json.decode(contactsJson);
        _contacts = decodedList.map((item) => ContactModel.fromJson(item)).toList();
        // Sort alphabetically
        _contacts.sort((a, b) => a.name.compareTo(b.name));
      }
    } catch (e) {
      print('Error loading contacts: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addContact(String name, String phoneNumber, {String? imagePath}) async {
    final newContact = ContactModel(
      id: const Uuid().v4(),
      name: name,
      phoneNumber: phoneNumber,
      imagePath: imagePath,
      avatarColor: _generateRandomColor(),
    );

    _contacts.add(newContact);
    _contacts.sort((a, b) => a.name.compareTo(b.name));
    await _saveContacts();
    notifyListeners();
  }

  Future<void> updateContact(ContactModel contact) async {
    final index = _contacts.indexWhere((c) => c.id == contact.id);
    if (index != -1) {
      _contacts[index] = contact;
      _contacts.sort((a, b) => a.name.compareTo(b.name));
      if (_isSearching) {
        final filteredIndex = _filteredContacts.indexWhere((c) => c.id == contact.id);
        if (filteredIndex != -1) {
           _filteredContacts[filteredIndex] = contact;
        }
      }
      await _saveContacts();
      notifyListeners();
    }
  }

  Future<void> updateContactFlags(String phoneNumber, {bool? isScam, bool? isAi, bool? isSafe}) async {
    // Determine the new state. If isSafe is true, both flags become false.
    // If isScam/isAi provided, we update them.
    // Note: We need to find *all* contacts with this phone number (usually 1, but technically possible to have duplicate numbers)
    
    bool changed = false;
    for (int i = 0; i < _contacts.length; i++) {
        if (_contacts[i].phoneNumber.replaceAll(' ', '') == phoneNumber.replaceAll(' ', '')) {
            bool newIsScam = _contacts[i].isScam;
            bool newIsAi = _contacts[i].isAi;

            if (isSafe == true) {
                newIsScam = false;
                newIsAi = false;
            } else {
                if (isScam != null) newIsScam = isScam;
                if (isAi != null) newIsAi = isAi;
            }
            
            if (newIsScam != _contacts[i].isScam || newIsAi != _contacts[i].isAi) {
                 _contacts[i] = _contacts[i].copyWith(
                    isScam: newIsScam,
                    isAi: newIsAi
                 );
                 changed = true;
            }
        }
    }
    
    if (changed) {
        // Update filtered list too if searching
        if (_isSearching) {
             for (int i = 0; i < _filteredContacts.length; i++) {
                if (_filteredContacts[i].phoneNumber.replaceAll(' ', '') == phoneNumber.replaceAll(' ', '')) {
                    // Re-sync with main list
                    final updatedMain = _contacts.firstWhere((c) => c.id == _filteredContacts[i].id);
                    _filteredContacts[i] = updatedMain;
                }
             }
        }

        await _saveContacts();
        notifyListeners();
    }
  }

  Future<void> deleteContact(String id) async {
    _contacts.removeWhere((contact) => contact.id == id);
    if (_isSearching) {
        _filteredContacts.removeWhere((contact) => contact.id == id);
    }
    await _saveContacts();
    notifyListeners();
  }

  Future<void> _saveContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedList = json.encode(_contacts.map((c) => c.toJson()).toList());
    await prefs.setString('local_contacts', encodedList);
  }
  
  void searchContacts(String query) {
    if (query.isEmpty) {
      _isSearching = false;
      _filteredContacts = [];
    } else {
      _isSearching = true;
      _filteredContacts = _contacts.where((contact) {
        return contact.name.toLowerCase().contains(query.toLowerCase()) || 
               contact.phoneNumber.replaceAll(' ', '').contains(query.replaceAll(' ', ''));
      }).toList();
    }
    notifyListeners();
  }

  int _generateRandomColor() {
    final List<int> colors = [
      0xFFE57373, 0xFFF06292, 0xFFBA68C8, 0xFF9575CD, 0xFF7986CB,
      0xFF64B5F6, 0xFF4FC3F7, 0xFF4DD0E1, 0xFF4DB6AC, 0xFF81C784,
      0xFFAED581, 0xFFFF8A65, 0xFFA1887F, 0xFF90A4AE
    ];
    return colors[Random().nextInt(colors.length)];
  }
}
