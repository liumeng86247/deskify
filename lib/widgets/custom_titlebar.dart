import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class CustomTitleBar extends StatelessWidget {
  const CustomTitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) {
        windowManager.startDragging();
      },
      child: Container(
        height: 32,
        color: const Color(0xFF2C2C2C),
        child: Row(
          children: [
            const Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: 12.0),
                child: Row(
                  children: [
                    Icon(Icons.language, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Deskify',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                _WindowButton(
                  icon: Icons.minimize,
                  onPressed: () async {
                    await windowManager.minimize();
                  },
                ),
                _WindowButton(
                  icon: Icons.crop_square,
                  onPressed: () async {
                    bool isMaximized = await windowManager.isMaximized();
                    if (isMaximized) {
                      await windowManager.unmaximize();
                    } else {
                      await windowManager.maximize();
                    }
                  },
                ),
                _WindowButton(
                  icon: Icons.close,
                  onPressed: () async {
                    await windowManager.close();
                  },
                  isClose: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WindowButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isClose;

  const _WindowButton({
    required this.icon,
    required this.onPressed,
    this.isClose = false,
  });

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 46,
          height: 32,
          color: _isHovered
              ? (widget.isClose ? const Color(0xFFE81123) : const Color(0x1AFFFFFF))
              : Colors.transparent,
          child: Icon(
            widget.icon,
            color: Colors.white,
            size: 14,
          ),
        ),
      ),
    );
  }
}
