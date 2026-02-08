import 'package:flutter/material.dart';

class PrivacyShield extends StatefulWidget {
  final Widget child;

  const PrivacyShield({super.key, required this.child});

  @override
  State<PrivacyShield> createState() => _PrivacyShieldState();
}

class _PrivacyShieldState extends State<PrivacyShield> with WidgetsBindingObserver {
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() {
      _isPaused = state == AppLifecycleState.paused || state == AppLifecycleState.inactive;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isPaused)
          Positioned.fill(
            child: Container(
              color: const Color(0xFF1A237E),
              child: Center(
                child: Image.asset(
                  'assets/images/logowhite.png',
                  width: 100,
                  height: 100,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
