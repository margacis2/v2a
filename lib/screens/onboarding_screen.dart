import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import 'home_screen.dart';

class OnboardingStep {
  final IconData icon;
  final String title;
  final String description;
  final String badge;

  const OnboardingStep({
    required this.icon,
    required this.title,
    required this.description,
    required this.badge,
  });
}

class OnboardingScreen extends StatefulWidget {
  final bool isReplay;
  const OnboardingScreen({super.key, this.isReplay = false});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingStep> _steps = const [
    OnboardingStep(
      icon: Icons.video_library_rounded,
      badge: 'Step 1 of 5',
      title: 'Import Videos Easily',
      description:
          'Select single videos or multiple files for batch conversion. Supports MP4, MKV, MOV, WebM, AVI, FLV, 3GP, TS and more from internal storage or SD card.',
    ),
    OnboardingStep(
      icon: Icons.play_circle_fill_rounded,
      badge: 'Step 2 of 5',
      title: 'Inspect & Preview Video',
      description:
          'Preview the video with a full-featured built-in player. Check audio quality, seek with precision, inspect resolution, and select specific audio tracks in multi-language videos.',
    ),
    OnboardingStep(
      icon: Icons.flash_on_rounded,
      badge: 'Step 3 of 5',
      title: 'Fastest Compatible Extraction',
      description:
          'Save immense battery and time! Mode A extracts audio streams directly without re-encoding when formats match. Switch to Mode B or Lossless FLAC when you need custom bitrates or compression.',
    ),
    OnboardingStep(
      icon: Icons.security_rounded,
      badge: 'Step 4 of 5',
      title: 'Never Overwrite Protection',
      description:
          'Your existing media is 100% safe. V2A automatically resolves duplicate names (Movie.mp3, Movie (1).mp3) and uses atomic file staging to guarantee zero data loss.',
    ),
    OnboardingStep(
      icon: Icons.music_note_rounded,
      badge: 'Step 5 of 5',
      title: 'Play Converted Audio & Queue',
      description:
          'Play your converted files directly inside the app with background audio, lock screen controls, and playlists. Conversion queues continue reliably in the background.',
    ),
  ];

  void _finishOnboarding() async {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    await appState.setOnboardingCompleted(true);
    if (!mounted) return;

    if (widget.isReplay) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar with Skip button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.audiotrack, size: 20, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'V2A Converter',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: _finishOnboarding,
                    child: Text(widget.isReplay ? 'Close' : 'Skip'),
                  ),
                ],
              ),
            ),

            // Page View
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _steps.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  final step = _steps[index];
                  return Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              step.badge,
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  theme.colorScheme.primary.withValues(alpha: 0.25),
                                  theme.colorScheme.primary.withValues(alpha: 0.04),
                                ],
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                step.icon,
                                size: 56,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            step.title,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            step.description,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark ? Colors.grey[400] : Colors.grey[700],
                              height: 1.4,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Indicator Dots & Controls
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_steps.length, (index) {
                      final isActive = index == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 6,
                        width: isActive ? 24 : 6,
                        decoration: BoxDecoration(
                          color: isActive
                              ? theme.colorScheme.primary
                              : (isDark ? Colors.grey[700] : Colors.grey[300]),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      if (_currentPage > 0)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              _pageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: const Text('Back'),
                          ),
                        ),
                      if (_currentPage > 0) const SizedBox(width: 16),
                      Expanded(
                        flex: _currentPage > 0 ? 1 : 2,
                        child: ElevatedButton(
                          onPressed: () {
                            if (_currentPage < _steps.length - 1) {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            } else {
                              _finishOnboarding();
                            }
                          },
                          child: Text(_currentPage == _steps.length - 1 ? 'Get Started' : 'Next'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

