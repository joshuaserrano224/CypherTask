import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../utils/validators.dart';
import 'widgets/cyber_widgets.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});
  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  static const Color cyanPrimary = Color(0xFF0DA6F2);
  static const Color pinkAccent = Color(0xFFFF00FF);
  static const Color darkBg = Color(0xFF020408);

  // Use the controllers from the ViewModel to maintain state during OTP process
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    _nameController = authVM.nameController;
    _emailController = authVM.emailController;
    _passwordController = authVM.passwordController;
  }

  void _handleRegister() async {
    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    
    // 1. Run local validation
    final nameErr = Validators.validateName(_nameController.text);
    final emailErr = Validators.validateEmail(_emailController.text);
    final passErr = Validators.validatePassword(_passwordController.text);

    if (nameErr != null || emailErr != null || passErr != null) {
      _showSnackBar(nameErr ?? emailErr ?? passErr!, isError: true);
      return;
    }

    // 2. Trigger Registration & OTP Transmission
    // This now communicates with the SQLCipher + OTP logic in the VM
    await authVM.handleRegister(context);
    
    // Note: The OTP Modal is triggered automatically by the listener in LoginView.
    // If registration starts successfully, the modal will appear.
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.spaceGrotesk(color: Colors.white)),
        backgroundColor: isError ? Colors.redAccent : cyanPrimary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthViewModel>().isLoading;

    return Scaffold(
      backgroundColor: darkBg,
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: GridPainter())),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildHexagonLogo(),
                  const SizedBox(height: 30),
                  _buildMainTitle(),
                  const SizedBox(height: 50),
                  _buildLabelRow("FULL NAME", ""),
                  CyberInput(
                    controller: _nameController,
                    hint: "Enter your full name",
                    icon: Icons.badge_outlined,
                    accent: cyanPrimary,
                  ),
                  const SizedBox(height: 25),
                  _buildLabelRow("EMAIL ADDRESS", ""),
                  CyberInput(
                    controller: _emailController,
                    hint: "Enter your email",
                    icon: Icons.email_outlined,
                    accent: cyanPrimary,
                  ),
                  const SizedBox(height: 25),
                  _buildLabelRow("CREATE PASSWORD", ""),
                  CyberInput(
                    controller: _passwordController,
                    hint: "Min. 8 characters + Symbol",
                    icon: Icons.lock_outline,
                    accent: pinkAccent,
                    isPassword: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, 
                        color: Colors.white24, size: 20
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  const SizedBox(height: 40),
                  isLoading 
                    ? const CircularProgressIndicator(color: cyanPrimary)
                    : _buildPrimaryButton("INITIALIZE IDENTITY", Icons.person_add_alt_1_outlined, onTap: _handleRegister),
                  const SizedBox(height: 50),
                  _buildFooter(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // UI Helper methods to maintain consistent branding
  Widget _buildHexagonLogo() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.black, 
      border: Border.all(color: cyanPrimary.withOpacity(0.5), width: 2)
    ),
    child: const Icon(Icons.shield_outlined, color: cyanPrimary, size: 30),
  );

  Widget _buildMainTitle() => Column(
    children: [
      RichText(
        text: TextSpan(
          style: GoogleFonts.orbitron(fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: 3, fontStyle: FontStyle.italic),
          children: const [
            TextSpan(text: "JOIN ", style: TextStyle(color: Colors.white)),
            TextSpan(text: "VAULT", style: TextStyle(color: cyanPrimary)),
          ],
        ),
      ),
      const SizedBox(height: 6),
      Text("CREATE ENCRYPTED ACCOUNT", style: GoogleFonts.spaceGrotesk(color: cyanPrimary, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 3)),
    ],
  );

  Widget _buildLabelRow(String left, String right) => Padding(
    padding: const EdgeInsets.only(bottom: 8.0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(left, style: GoogleFonts.spaceGrotesk(color: cyanPrimary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        Text(right, style: GoogleFonts.spaceGrotesk(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
      ],
    ),
  );

  Widget _buildPrimaryButton(String text, IconData icon, {required VoidCallback onTap}) => Container(
    height: 60, width: double.infinity,
    decoration: BoxDecoration(
      color: cyanPrimary.withOpacity(0.1), 
      border: Border.all(color: cyanPrimary.withOpacity(0.5)),
      borderRadius: const BorderRadius.only(topRight: Radius.circular(15), bottomLeft: Radius.circular(15))
    ),
    child: InkWell(
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(text, style: GoogleFonts.orbitron(color: cyanPrimary, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 2)),
          const SizedBox(width: 10),
          Icon(icon, color: cyanPrimary, size: 16),
        ],
      ),
    ),
  );

  Widget _buildFooter(BuildContext context) => InkWell(
    onTap: () => Navigator.pop(context),
    child: RichText(
      text: TextSpan(
        style: GoogleFonts.spaceGrotesk(fontSize: 11, color: Colors.white24, letterSpacing: 0.5),
        children: const [
          TextSpan(text: "Already a registered agent?  "),
          TextSpan(text: "LOG IN", style: TextStyle(color: pinkAccent, fontWeight: FontWeight.bold)),
        ],
      ),
    ),
  );
}