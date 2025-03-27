import 'package:codeed/api.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final Size screenSize = MediaQuery.of(context).size;
    final bool isSmallScreen = screenSize.width < 600;
    final ThemeData theme = Theme.of(context);
    final Color primaryColor = const Color(0xFF00158F);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              primaryColor,
              primaryColor.withOpacity(0.8),
              primaryColor.withOpacity(0.6),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Card(
                  margin: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 20 : 40,
                    vertical: 20,
                  ),
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo or App Title
                        Container(
                          height: 100,
                          width: 100,
                          decoration: BoxDecoration(
                            color: primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.school,
                            size: 50,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Title
                        Text(
                          'Welcome to CodeEd',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 8),

                        // Subtitle
                        Text(
                          'Please select your role to continue',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 36),

                        // Admin Login Button
                        LoginButton(
                          icon: Icons.admin_panel_settings,
                          text: 'Login as Admin',
                          color: primaryColor,
                          onPressed: () {
                            appState.setUserRole('admin');
                            Navigator.pushReplacementNamed(context, '/admin');
                          },
                        ),

                        const SizedBox(height: 16),

                        // Student Login Button
                        LoginButton(
                          icon: Icons.person,
                          text: 'Login as Student',
                          color: primaryColor.withOpacity(0.8),
                          onPressed: () {
                            appState.setUserRole('student');
                            Navigator.pushReplacementNamed(context, '/student');
                          },
                        ),

                        const SizedBox(height: 24),

                        // Footer Text
                        Text(
                          '© ${DateTime.now().year} CodeEd Learning Platform',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LoginButton extends StatefulWidget {
  final IconData icon;
  final String text;
  final Color color;
  final VoidCallback onPressed;

  const LoginButton({
    super.key,
    required this.icon,
    required this.text,
    required this.color,
    required this.onPressed,
  });

  @override
  State<LoginButton> createState() => _LoginButtonState();
}

class _LoginButtonState extends State<LoginButton> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = kIsWeb || MediaQuery.of(context).size.width > 1024;

    return MouseRegion(
      onEnter: isDesktop
          ? (event) {
              setState(() {
                isHovered = true;
              });
            }
          : null,
      onExit: isDesktop
          ? (event) {
              setState(() {
                isHovered = false;
              });
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: ElevatedButton(
          onPressed: widget.onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: isHovered ? 6 : 2,
            minimumSize: const Size(double.infinity, 54),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon),
              const SizedBox(width: 12),
              Text(
                widget.text,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
