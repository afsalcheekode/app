import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DeviceAuthScreen extends StatefulWidget {
  const DeviceAuthScreen({super.key});

  @override
  State<DeviceAuthScreen> createState() => _DeviceAuthScreenState();
}

class _DeviceAuthScreenState extends State<DeviceAuthScreen> {
  final List<TextEditingController> _controllers = List.generate(8, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(8, (_) => FocusNode());
  bool _isButtonEnabled = false;

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _onChanged(String value, int index) {
    if (value.isNotEmpty && index < 7) {
      _focusNodes[index + 1].requestFocus();
    }
    _checkButtonStatus();
  }

  void _onKeyEvent(KeyEvent event, int index) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace) {
      if (_controllers[index].text.isEmpty && index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
    }
  }

  void _checkButtonStatus() {
    setState(() {
      _isButtonEnabled = _controllers.every((c) => c.text.isNotEmpty);
    });
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF0D1117);
    const cardColor = Color(0xFF161B22);
    const borderColor = Color(0xFF30363D);
    const primaryText = Color(0xFFF0F6FC);
    const secondaryText = Color(0xFF8B949E);
    const greenButton = Color(0xFF238636);

    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo
              const Icon(Icons.hub, size: 48, color: primaryText),
              const SizedBox(height: 32),
              
              // Card
              Container(
                constraints: const BoxConstraints(maxWidth: 500),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: cardColor,
                  border: Border.all(color: borderColor),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'Authorize your device',
                      style: TextStyle(
                        color: primaryText,
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // User Info
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: borderColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(Icons.person, size: 16, color: secondaryText),
                        ),
                        const SizedBox(width: 8),
                        const Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: 'Signed in as ', style: TextStyle(color: primaryText, fontSize: 14)),
                              TextSpan(text: 'afsalcheekode', style: TextStyle(color: primaryText, fontSize: 14, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    
                    const Text(
                      'Enter the code displayed in the app or on the device you\'re signing in to. Never use a code sent by someone else.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: primaryText, fontSize: 14, height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    
                    // Code Inputs
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (int i = 0; i < 4; i++) _buildInputBox(i),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text('-', style: TextStyle(color: secondaryText, fontSize: 20)),
                        ),
                        for (int i = 4; i < 8; i++) _buildInputBox(i),
                      ],
                    ),
                    const SizedBox(height: 32),
                    
                    // Continue Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isButtonEnabled ? () {} : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: greenButton,
                          disabledBackgroundColor: greenButton.withOpacity(0.5),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          elevation: 0,
                        ),
                        child: const Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    const Text(
                      'GitHub staff will never give you a code to enter on this page.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: secondaryText, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputBox(int index) {
    return Container(
      width: 44,
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: KeyboardListener(
        focusNode: FocusNode(), // Dummy node for keyboard listener
        onKeyEvent: (event) => _onKeyEvent(event, index),
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          maxLength: 1,
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: const Color(0xFF0D1117),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFF30363D)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFF1F6FEB), width: 2),
            ),
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: (value) => _onChanged(value, index),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
          ],
        ),
      ),
    );
  }
}
