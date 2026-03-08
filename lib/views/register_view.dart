import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../viewmodels/auth_viewmodel.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  static const Color cyanPrimary = Color(0xFF0DA6F2);
  static const Color pinkAccent = Color(0xFFFF00FF);
  static const Color darkBg = Color(0xFF020408);

  final nameController = TextEditingController();
  final retypeController = TextEditingController();

  void _handleRegistration(AuthViewModel authVM) async {
    if (authVM.passwordController.text != retypeController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("ERROR: PASSWORDS DO NOT MATCH"),
          backgroundColor: pinkAccent,
        ),
      );
      return;
    }

    bool readyForOTP = await authVM.register(
      context,
      nameController.text,
      authVM.emailController.text,
      authVM.passwordController.text,
    );

    if (readyForOTP && mounted) {
      _showOTPModal(context, authVM);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authVM = Provider.of<AuthViewModel>(context);
    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: darkBg,
      resizeToAvoidBottomInset: true, // Key for keyboard sliding
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: GridPainter())),
          SafeArea(
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: retypeController,
              builder: (context, retypeVal, _) {
                bool isTypingConfirm = retypeVal.text.isNotEmpty;

                return SingleChildScrollView(
                  physics: (isKeyboardOpen || isTypingConfirm)
                      ? const BouncingScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(30.0, 50.0, 30.0, 20.0), // Restored old padding
                  child: SizedBox(
                    // Ensure the column takes up at least the full screen height 
                    // to allow Spacers to work in the static view.
                    height: MediaQuery.of(context).size.height - 100,
                    child: Column(
                      children: [
                        _buildHexagonLogo(),
                        const SizedBox(height: 15),
                        _buildMainTitle(),
                        
                        const Spacer(flex: 2), // Old structure spacing
                        
                        _buildLabelRow("FULL NAME"),
                        _buildCyberField(
                          controller: nameController,
                          hint: "Enter your name",
                          icon: Icons.person_outline,
                          accent: cyanPrimary,
                        ),
                        const SizedBox(height: 10),
                        
                        _buildLabelRow("EMAIL ADDRESS"),
                        _buildCyberField(
                          controller: authVM.emailController,
                          hint: "Enter your email",
                          icon: Icons.alternate_email_rounded,
                          accent: cyanPrimary,
                        ),
                        const SizedBox(height: 10),

                        _buildLabelRow("PASSWORD"),
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: authVM.passwordController,
                          builder: (context, value, child) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildCyberField(
                                  controller: authVM.passwordController,
                                  hint: "Create a password",
                                  icon: Icons.vpn_key_outlined,
                                  accent: pinkAccent,
                                  isPassword: true,
                                  obscure: authVM.obscurePassword,
                                  onToggle: authVM.togglePasswordVisibility,
                                ),
                                _buildLiveValidation(value.text),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 10),

                        _buildLabelRow("CONFIRM PASSWORD"),
                        _buildCyberField(
                          controller: retypeController,
                          hint: "Repeat your password",
                          icon: Icons.shield_outlined,
                          accent: pinkAccent,
                          isPassword: true,
                          obscure: authVM.obscurePassword,
                          onToggle: authVM.togglePasswordVisibility,
                        ),
                        
                        const SizedBox(height: 25),
                        _buildPrimaryButton(
                          label: "CREATE ACCOUNT",
                          isLoading: authVM.isLoading,
                          onTap: authVM.isLoading ? null : () => _handleRegistration(authVM),
                        ),
                        
                        const Spacer(flex: 3), // Old structure footer spacing
                        _buildFooter(context),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                );
              }
            ),
          ),
        ],
      ),
    );
  }

  // --- REINSTATED OLD UI METHODS (Shadows, Structure, Spacing) ---

  Widget _buildHexagonLogo() => Container(
        padding: const EdgeInsets.all(14), // Old sizing
        decoration: BoxDecoration(
          color: const Color(0xFF010204),
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(15), bottomRight: Radius.circular(15)),
          border: Border.all(color: cyanPrimary, width: 1.5),
          boxShadow: [BoxShadow(color: cyanPrimary.withOpacity(0.5), blurRadius: 8, spreadRadius: 1)],
        ),
        child: Icon(Icons.shield_outlined, color: Colors.white, size: 22, shadows: [Shadow(color: cyanPrimary.withOpacity(0.8), blurRadius: 10)]),
      );

  Widget _buildMainTitle() => Column(
        children: [
          RichText(
            text: TextSpan(
              style: GoogleFonts.orbitron(
                fontSize: 24, // Old sizing
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
                fontStyle: FontStyle.italic,
                shadows: [
                  Shadow(color: cyanPrimary.withOpacity(0.7), offset: const Offset(2, 2), blurRadius: 10),
                  Shadow(color: pinkAccent.withOpacity(0.5), offset: const Offset(-1, -1), blurRadius: 5),
                ],
              ),
              children: const [
                TextSpan(text: "SIGN", style: TextStyle(color: Colors.white)),
                TextSpan(text: "UP", style: TextStyle(color: cyanPrimary)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: cyanPrimary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: cyanPrimary.withOpacity(0.2), width: 0.5),
            ),
            child: Text("INITIALIZING NEW ACCOUNT",
                style: GoogleFonts.spaceGrotesk(color: cyanPrimary, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 3)),
          ),
        ],
      );

  Widget _buildLabelRow(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 8.0, left: 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(label, style: GoogleFonts.spaceGrotesk(color: cyanPrimary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        ),
      );

  Widget _buildCyberField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color accent,
    bool isPassword = false,
    bool obscure = false,
    VoidCallback? onToggle,
  }) {
    return Container(
      decoration: BoxDecoration(
        // Slightly more visible background (0.05 vs 0.01)
        color: Colors.white.withOpacity(0.05),
        border: Border(
          left: BorderSide(color: accent, width: 4),
          // Added a very faint bottom border for more definition
          bottom: BorderSide(color: Colors.white.withOpacity(0.02), width: 1),
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          // Lightened up the hint text (0.3 vs 0.1)
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
          filled: true,
          fillColor: Colors.transparent,
          prefixIcon: Icon(icon, color: accent, size: 20),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: Colors.white38, // Slightly lighter icon
                    size: 16,
                  ),
                  onPressed: onToggle,
                )
              : null,
          enabledBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.zero, 
            // Lightened the border (white24 vs white12)
            borderSide: BorderSide(color: Colors.white24),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.zero, 
            borderSide: BorderSide(color: accent, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildLiveValidation(String password) {
    bool hasMin8 = password.length >= 8;
    bool hasUpper = password.contains(RegExp(r'[A-Z]'));
    bool hasLower = password.contains(RegExp(r'[a-z]'));
    bool hasNum = password.contains(RegExp(r'[0-9]'));
    bool hasSpecial = password.contains(RegExp(r'[!@#\$&*~]'));

    return Padding(
      padding: const EdgeInsets.only(top: 6.0),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          _validationChip("8+ CHR", hasMin8),
          _validationChip("UPPER", hasUpper),
          _validationChip("LOWER", hasLower),
          _validationChip("NUMBER", hasNum),
          _validationChip("SYMBOL", hasSpecial),
        ],
      ),
    );
  }

  Widget _validationChip(String label, bool isValid) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isValid ? cyanPrimary.withOpacity(0.1) : Colors.transparent,
        border: Border.all(color: isValid ? cyanPrimary : Colors.white10),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        label,
        style: GoogleFonts.spaceGrotesk(
          color: isValid ? cyanPrimary : Colors.white12,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({required String label, required bool isLoading, required VoidCallback? onTap}) {
    return Container(
      height: 60, // Old height
      width: double.infinity,
      decoration: BoxDecoration(
        color: cyanPrimary.withOpacity(0.08),
        border: Border.all(color: cyanPrimary, width: 2),
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(25), bottomRight: Radius.circular(25)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(25), bottomRight: Radius.circular(25)),
        child: Center(
          child: isLoading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: cyanPrimary))
              : Text(label, style: GoogleFonts.orbitron(color: cyanPrimary, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 5)),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    return InkWell(
      onTap: () { authVM.clearAuthInputs(); Navigator.pop(context); },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: cyanPrimary.withOpacity(0.4), width: 1))),
        child: RichText(
          text: TextSpan(
            style: GoogleFonts.spaceGrotesk(fontSize: 11, color: Colors.white24, letterSpacing: 1),
            children: const [
              TextSpan(text: "HAVE AN ACCOUNT? "),
              TextSpan(text: "LOGIN NOW", style: TextStyle(color: cyanPrimary, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  void _showOTPModal(BuildContext context, AuthViewModel authVM) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF0A0E12),
            shape: const RoundedRectangleBorder(
              side: BorderSide(color: cyanPrimary, width: 2),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
            ),
            title: Text("VERIFY EMAIL", style: GoogleFonts.orbitron(color: Colors.white, fontSize: 14, letterSpacing: 2)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Enter the code we sent to your email.", style: GoogleFonts.spaceGrotesk(color: Colors.white54, fontSize: 11)),
                const SizedBox(height: 20),
                TextField(
                  controller: authVM.otpController,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.orbitron(color: cyanPrimary, letterSpacing: 10, fontSize: 24),
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: cyanPrimary))),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () { authVM.cancelOTP(context); Navigator.pop(context); },
                  child: const Text("CANCEL", style: TextStyle(color: pinkAccent, fontWeight: FontWeight.bold))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: cyanPrimary),
                onPressed: authVM.isLoading ? null : () async { await authVM.verifyOTPAndAccess(context); },
                child: authVM.isLoading 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : Text("CONFIRM", style: GoogleFonts.spaceGrotesk(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        }
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF0DA6F2).withOpacity(0.05)..strokeWidth = 1;
    for (double i = 0; i < size.width; i += 30) { canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint); }
    for (double i = 0; i < size.height; i += 30) { canvas.drawLine(Offset(0, i), Offset(size.width, i), paint); }
  }
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}