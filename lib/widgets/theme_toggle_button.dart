import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class ThemeToggleButton extends StatefulWidget {
  const ThemeToggleButton({
    super.key,
    this.size = 56,
    this.showLabel = false,
  });

  final double size;
  final bool showLabel;

  @override
  State<ThemeToggleButton> createState() => _ThemeToggleButtonState();
}

class _ThemeToggleButtonState extends State<ThemeToggleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggleTheme() async {
    _controller.forward().then((_) {
      _controller.reverse();
    });
    
    final themeProvider = context.read<ThemeProvider>();
    await themeProvider.toggleTheme();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Transform.rotate(
            angle: _rotationAnimation.value * 3.14159,
            child: widget.showLabel
                ? _buildWithLabel(context, isDark, colorScheme)
                : _buildIconButton(context, isDark, colorScheme),
          ),
        );
      },
    );
  }

  Widget _buildIconButton(
    BuildContext context,
    bool isDark,
    ColorScheme colorScheme,
  ) {
    return Tooltip(
      message: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
      preferBelow: false,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF1A1A2E),
                    const Color(0xFF16213E),
                  ]
                : [
                    const Color(0xFFFFE5B4),
                    const Color(0xFFFFD700),
                  ],
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.3)
                  : Colors.orange.withOpacity(0.3),
              blurRadius: 12,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _toggleTheme,
            borderRadius: BorderRadius.circular(widget.size / 2),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) {
                  return ScaleTransition(scale: animation, child: child);
                },
                child: Icon(
                  isDark ? Icons.dark_mode : Icons.light_mode,
                  key: ValueKey(isDark),
                  color: isDark ? Colors.white : Colors.orange.shade900,
                  size: widget.size * 0.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWithLabel(
    BuildContext context,
    bool isDark,
    ColorScheme colorScheme,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1A1A2E),
                  const Color(0xFF16213E),
                ]
              : [
                  const Color(0xFFFFE5B4),
                  const Color(0xFFFFD700),
                ],
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.orange.withOpacity(0.3),
            blurRadius: 12,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _toggleTheme,
          borderRadius: BorderRadius.circular(30),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) {
                  return ScaleTransition(scale: animation, child: child);
                },
                child: Icon(
                  isDark ? Icons.dark_mode : Icons.light_mode,
                  key: ValueKey(isDark),
                  color: isDark ? Colors.white : Colors.orange.shade900,
                  size: 24,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isDark ? 'Dark Mode' : 'Light Mode',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.orange.shade900,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Floating theme toggle button that can be placed anywhere
class FloatingThemeToggle extends StatelessWidget {
  const FloatingThemeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 16,
      right: 16,
      child: ThemeToggleButton(size: 56),
    );
  }
}

/// Compact theme toggle for app bars
class CompactThemeToggle extends StatelessWidget {
  const CompactThemeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return ThemeToggleButton(size: 40);
  }
}

