import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'register_view.dart';

class LoginView extends StatelessWidget {
  const LoginView({super.key});

  static const Color cyanPrimary = Color(0xFF0DA6F2);
  static const Color pinkAccent = Color(0xFFFF00FF);
  static const Color darkBg = Color(0xFF020408);

 @override
  Widget build(BuildContext context) {
    final authVM = Provider.of<AuthViewModel>(context);

    return Scaffold(
      backgroundColor: darkBg,
      resizeToAvoidBottomInset: false, 
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: GridPainter())),
          
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      // Increased top padding to 100 to really push the content down
                      padding: const EdgeInsets.fromLTRB(30.0, 100.0, 30.0, 20.0),
                      child: Column(
                        children: [
                          _buildHexagonLogo(),
                          const SizedBox(height: 15),
                          _buildMainTitle(),
                          
                          // Smaller spacer here so the form starts sooner after the title
                          const SizedBox(height: 40),

                          _buildLabelRow("EMAIL ADDRESS", ""),
                          _buildCyberField(
                            controller: authVM.emailController,
                            hint: "Enter your email",
                            icon: Icons.alternate_email_rounded,
                            accent: cyanPrimary,
                          ),
                          const SizedBox(height: 18),

                          _buildLabelRow("PASSWORD", "", isAction: true),
                          _buildCyberField(
                            controller: authVM.passwordController,
                            hint: "Enter your password",
                            icon: Icons.vpn_key_outlined,
                            accent: pinkAccent,
                            isPassword: true,
                            obscure: authVM.obscurePassword,
                            onToggle: authVM.togglePasswordVisibility,
                          ),
                          const SizedBox(height: 30),

                          _buildPrimaryButton(
                            label: "LOGIN",
                            isLoading: authVM.isLoading,
                            onTap: authVM.isLoading ? null : () => authVM.handleLogin(context),
                          ),
                          
                          // Reduced spacing before biometrics
                          const SizedBox(height: 25), 

                          GestureDetector(
                            onTap: authVM.isLoading ? null : () => authVM.handleBiometricLogin(context),
                            child: _buildCompactBiometric(authVM.isLoading),
                          ),

                          // This spacer now handles the remaining bottom gap
                          const Spacer(),

                          _buildFooter(context),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- SHARPER UI DESIGN COMPONENTS ---

  Widget _buildHexagonLogo() => Container(
      padding: const EdgeInsets.all(14), // Reduced from 22 for a tighter look
      decoration: BoxDecoration(
        color: const Color(0xFF010204),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(15), // Reduced from 25 to match smaller scale
          bottomRight: Radius.circular(15),
          topRight: Radius.zero,
          bottomLeft: Radius.zero,
        ),
        border: Border.all(
          color: cyanPrimary, 
          width: 1.5, // Slightly thinner border for the smaller size
        ),
        boxShadow: [
          BoxShadow(
            color: cyanPrimary.withOpacity(0.5),
            blurRadius: 8,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: cyanPrimary.withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(
        Icons.shield_outlined, 
        color: Colors.white,
        size: 22, // Reduced from 32 for a sleeker profile
        shadows: [
          Shadow(
            color: cyanPrimary.withOpacity(0.8),
            blurRadius: 10,
          ),
        ],
      ),
    );

 Widget _buildMainTitle() => Column(
      children: [
        RichText(
          text: TextSpan(
            style: GoogleFonts.orbitron(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
              fontStyle: FontStyle.italic,
              // Shadow added here to create the "Cyber" pop
              shadows: [
                Shadow(
                  color: cyanPrimary.withOpacity(0.7),
                  offset: const Offset(2, 2),
                  blurRadius: 10,
                ),
                Shadow(
                  color: pinkAccent.withOpacity(0.5),
                  offset: const Offset(-1, -1),
                  blurRadius: 5,
                ),
              ],
            ),
            children: const [
              TextSpan(text: "CYPHER", style: TextStyle(color: Colors.white)),
              TextSpan(text: "TASK", style: TextStyle(color: cyanPrimary)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Adding a subtle container to the subtitle for a "scanning" feel
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: cyanPrimary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Text(
            "SYSTEM ACCESS REQUIRED",
            style: GoogleFonts.spaceGrotesk(
              color: cyanPrimary,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 3,
            ),
          ),
        ),
      ],
    );

  Widget _buildLabelRow(String left, String right, {bool isAction = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 8.0, left: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(left, style: GoogleFonts.spaceGrotesk(color: cyanPrimary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        Text(right, style: GoogleFonts.spaceGrotesk(color: isAction ? pinkAccent : Colors.white24, fontSize: 9, fontWeight: FontWeight.bold)),
      ],
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
        // Lighter background (0.05) to define the field area better
        color: Colors.white.withOpacity(0.05),
        border: Border(
          left: BorderSide(color: accent, width: 4),
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        // Kept your larger font size for the taller field
        style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          // Lighter, more readable hint text
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.30), fontSize: 13),
          filled: true,
          fillColor: Colors.transparent,
          prefixIcon: Icon(icon, color: accent, size: 22),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: Colors.white38, // Lighter icon
                    size: 18,
                  ),
                  onPressed: onToggle,
                )
              : null,
          enabledBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            // Lighter border for better structure visibility
            borderSide: BorderSide(color: Colors.white24),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(0),
            borderSide: BorderSide(color: accent, width: 1.5),
          ),
          // Kept your increased padding for the tall aesthetic
          contentPadding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        ),
      ),
    );
  }

Widget _buildPrimaryButton({required String label, required bool isLoading, required VoidCallback? onTap}) {
  return Container(
    height: 60, // Slightly taller to match your enhanced input fields
    width: double.infinity,
    decoration: BoxDecoration(
      // Clean transparent blue tint
      color: cyanPrimary.withOpacity(0.08), 
      border: Border.all(color: cyanPrimary, width: 2),
      // Doflamingo-style asymmetric rounding
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(25),
        bottomRight: Radius.circular(25),
        topRight: Radius.zero,
        bottomLeft: Radius.zero,
      ),
      // boxShadow removed to eliminate the "shady" glow look
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(25),
        bottomRight: Radius.circular(25),
      ),
      child: Center(
        child: isLoading
            ? const SizedBox(
                height: 20, 
                width: 20, 
                child: CircularProgressIndicator(strokeWidth: 2, color: cyanPrimary)
              )
            : Text(
                label,
                style: GoogleFonts.orbitron(
                  color: cyanPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 16, // Matches the bigger button size
                  letterSpacing: 5,
                ),
              ),
      ),
    ),
  );
}
// --- The Doflamingo Wing Shape ---
  Widget _buildCompactBiometric(bool isLoading) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: cyanPrimary.withOpacity(isLoading ? 0.1 : 0.5),
              width: 1,
            ),
          ),
          child: Icon(
            Icons.fingerprint_rounded,
            size: 28,
            color: cyanPrimary.withOpacity(isLoading ? 0.2 : 1.0),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          "ENCRYPTED SIGN-IN",
          style: GoogleFonts.spaceGrotesk(
            color: cyanPrimary.withOpacity(0.5),
            fontSize: 8,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

 Widget _buildFooter(BuildContext context) {
  final authVM = Provider.of<AuthViewModel>(context, listen: false); // Get VM instance

  return InkWell(
    onTap: () {
      authVM.clearAuthInputs(); // Clear before navigating
      Navigator.push(
        context, 
        MaterialPageRoute(builder: (_) => const RegisterView())
      );
    },
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: pinkAccent.withOpacity(0.4), width: 1))
      ),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.spaceGrotesk(fontSize: 11, color: Colors.white24, letterSpacing: 1),
          children: const [
            TextSpan(text: "NEW USER? "),
            TextSpan(text: "INITIALIZE ACCOUNT", style: TextStyle(color: pinkAccent, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    ),
  );
}
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0DA6F2).withOpacity(0.05)
      ..strokeWidth = 1;

    for (double i = 0; i < size.width; i += 30) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 30) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
