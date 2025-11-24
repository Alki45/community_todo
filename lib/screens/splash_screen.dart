import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// Note: Replace with your actual website URL
const String developerWebsite = 'https://your-website.com';

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.onComplete,
  });

  final VoidCallback onComplete;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  bool _showContent = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    // Show content after a brief delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _showContent = true;
        });
        _controller.forward();
      }
    });

    // Auto-advance after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openWebsite(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSmallScreen = MediaQuery.of(context).size.height < 700;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isSmallScreen ? 24 : 32),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Icon/Logo
                  Container(
                    width: isSmallScreen ? 80 : 100,
                    height: isSmallScreen ? 80 : 100,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.menu_book,
                      size: isSmallScreen ? 40 : 50,
                      color: colorScheme.primary,
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 24 : 32),
                  // App Title
                  Text(
                    'Qur\'an Tracker',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                          fontSize: isSmallScreen ? 24 : null,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: isSmallScreen ? 8 : 12),
                  Text(
                    'Community Recitation Platform',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: isSmallScreen ? 14 : null,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: isSmallScreen ? 32 : 48),
                  // Developer Info Card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
                      child: Column(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: isSmallScreen ? 48 : 56,
                            color: colorScheme.primary,
                          ),
                          SizedBox(height: isSmallScreen ? 12 : 16),
                          Text(
                            'Developed by',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: isSmallScreen ? 13 : null,
                                ),
                          ),
                          SizedBox(height: isSmallScreen ? 4 : 6),
                          Text(
                            'Ali Kibret',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                  fontSize: isSmallScreen ? 20 : null,
                                ),
                          ),
                          SizedBox(height: isSmallScreen ? 4 : 6),
                          Text(
                            'Academic Research Assistant',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: colorScheme.primary,
                                  fontSize: isSmallScreen ? 13 : null,
                                ),
                          ),
                          SizedBox(height: isSmallScreen ? 2 : 4),
                          Text(
                            'Adama Science and Technology University (ASTU)',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: isSmallScreen ? 11 : null,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: isSmallScreen ? 16 : 20),
                          Container(
                            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'About This App',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        fontSize: isSmallScreen ? 14 : null,
                                      ),
                                ),
                                SizedBox(height: isSmallScreen ? 8 : 12),
                                Text(
                                  'Created for ASTU Student Muslim Community to facilitate team-based Qur\'an recitation, strengthen Iman through interaction, sharing, and collaborative learning.',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        height: 1.5,
                                        fontSize: isSmallScreen ? 12 : null,
                                        color: colorScheme.onSurface,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 24 : 32),
                  // Skip/Continue Button
                  FilledButton.icon(
                    onPressed: widget.onComplete,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Continue'),
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 24 : 32,
                        vertical: isSmallScreen ? 12 : 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

