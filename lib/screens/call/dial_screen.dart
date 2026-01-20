import 'package:flutter/material.dart';
import '../../widgets/dial_button.dart';
import 'active_call_screen.dart';
import '../../utils/permission_helper.dart';

class DialScreen extends StatefulWidget {
  const DialScreen({super.key});

  @override
  State<DialScreen> createState() => _DialScreenState();
}

class _DialScreenState extends State<DialScreen> {
  String _phoneNumber = '';

  void _addDigit(String digit) {
    setState(() {
      _phoneNumber += digit;
    });
  }

  void _deleteDigit() {
    if (_phoneNumber.isNotEmpty) {
      setState(() {
        _phoneNumber = _phoneNumber.substring(0, _phoneNumber.length - 1);
      });
    }
  }

  Future<void> _makeCall() async {
    if (_phoneNumber.isNotEmpty) {
      bool hasPermission =
          await PermissionHelper.checkAndRequestMicrophone(context);
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Microphone permission required to make calls.")),
          );
        }
        return;
      }

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ActiveCallScreen(
            userId: _phoneNumber, // Phone number is used as user ID for calling
            contactName: _phoneNumber,
          ),
        ),
      );
    }
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
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const Expanded(
                      child: Text(
                        'Dial',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                child: Text(
                  _phoneNumber.isEmpty ? 'Enter phone number' : _phoneNumber,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w500,
                    color: _phoneNumber.isEmpty
                        ? Colors.white.withOpacity(0.5)
                        : Colors.white,
                    letterSpacing: 2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        DialButton(digit: '1', onTap: _addDigit),
                        DialButton(
                            digit: '2', letters: 'ABC', onTap: _addDigit),
                        DialButton(
                            digit: '3', letters: 'DEF', onTap: _addDigit),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        DialButton(
                            digit: '4', letters: 'GHI', onTap: _addDigit),
                        DialButton(
                            digit: '5', letters: 'JKL', onTap: _addDigit),
                        DialButton(
                            digit: '6', letters: 'MNO', onTap: _addDigit),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        DialButton(
                            digit: '7', letters: 'PQRS', onTap: _addDigit),
                        DialButton(
                            digit: '8', letters: 'TUV', onTap: _addDigit),
                        DialButton(
                            digit: '9', letters: 'WXYZ', onTap: _addDigit),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        DialButton(digit: '*', onTap: _addDigit),
                        DialButton(digit: '0', letters: '+', onTap: _addDigit),
                        DialButton(digit: '#', onTap: _addDigit),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(width: 80),
                        const Spacer(),
                        GestureDetector(
                          onTap: _makeCall,
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
                        const Spacer(),
                        GestureDetector(
                          onTap: _deleteDigit,
                          child: Container(
                            width: 80,
                            height: 70,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.backspace_outlined,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
