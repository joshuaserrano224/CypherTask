import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'register_view.dart';
import 'widgets/cyber_widgets.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  static const Color cyanPrimary = Color(0xFF0DA6F2);
  static const Color pinkAccent = Color(0xFFFF00FF);
  static const Color darkBg = Color(0xFF020408);

  bool _isModalOpen = false; 

  @override
  void initState() {
    super.initState();
    // Add listener to trigger the OTP modal when the VM says we are waiting
    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    authVM.addListener(_handleOTPState);
  }

  void _handleOTPState() {
    if (!mounted) return; 
    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    
    if (authVM.isWaitingForOTP && !_isModalOpen) {
      _isModalOpen = true;
      _showOTPModal(context, authVM);
    } 
    else if (!authVM.isWaitingForOTP) {
      _isModalOpen = false;
    }
  }

  @override
  void dispose() {
    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    authVM.removeListener(_handleOTPState);
    super.dispose();
  }

  void _showOTPModal(BuildContext context, AuthViewModel authVM) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 30,
          left: 30, right: 30, top: 30,
        ),
        decoration: const BoxDecoration(
          color: darkBg,
          border: Border(top: BorderSide(color: cyanPrimary, width: 2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLabelRow("SECURITY CLEARANCE", "ONE-TIME VERIFICATION"),
            const SizedBox(height: 10),
            CyberInput(
              controller: authVM.otpController,
              hint: "X - X - X - X - X - X",
              icon: Icons.security,
              accent: pinkAccent,
            ),
            const SizedBox(height: 30),
            Consumer<AuthViewModel>(
              builder: (context, vm, _) {
                return vm.isLoading 
                  ? const CircularProgressIndicator(color: pinkAccent)
                  : Row(
                      children: [
                        Expanded(
                          child: _buildSecondaryButton(
                            "ABORT", 
                            icon: Icons.close, 
                            color: Colors.redAccent, 
                            onTap: () {
                              vm.cancelOTP();
                              Navigator.pop(context);
                            }
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Material(
                            color: Colors.transparent,
                            child: _buildPrimaryButton(
                              "CONFIRM", 
                              Icons.vpn_key_outlined, 
                              onTap: () async {
                                FocusManager.instance.primaryFocus?.unfocus();
                                await vm.verifyOTPAndRegister(context);
                                if (!vm.isWaitingForOTP && context.mounted) {
                                  Navigator.pop(context); // Close modal on success
                                }
                              }, 
                            ),
                          ),
                        ),
                      ],
                    );
              },
            ),
          ],
        ),
      ),
    ).then((_) => _isModalOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final authVM = context.watch<AuthViewModel>();

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
                  _buildLabelRow("IDENTITY EMAIL", ""),
                  CyberInput(
                    controller: authVM.emailController,
                    hint: "Enter registered email",
                    icon: Icons.person_outline,
                    accent: cyanPrimary,
                  ),
                  const SizedBox(height: 25),
                  _buildLabelRow("ACCESS KEY", "", isAction: true),
                  CyberInput(
                    controller: authVM.passwordController,
                    hint: "Enter secure password",
                    icon: Icons.lock_outline,
                    accent: pinkAccent,
                    isPassword: authVM.obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        authVM.obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: Colors.white24, size: 20,
                      ),
                      onPressed: authVM.togglePasswordVisibility,
                    ),
                  ),
                  const SizedBox(height: 40),
                  authVM.isLoading 
                    ? const CircularProgressIndicator(color: cyanPrimary)
                    : _buildPrimaryButton("ACCESS VAULT", Icons.arrow_forward_ios_rounded, 
                        onTap: () => authVM.handleLogin(context)),
                  const SizedBox(height: 20),
                  
                  // --- MODIFIED BUTTON ROW (LOCAL ONLY) ---
                  Row(
                    children: [
                      Expanded(
                        child: _buildSecondaryButton(
                          "FORGOT", 
                          icon: Icons.help_outline, 
                          onTap: () {
                            // Local logic: usually points to contact admin or reset flow
                          }
                        )
                      ),
                      const SizedBox(width: 10),
                      // Biometric Button (Essential for Hardware Rubric)
                      _buildBiometricButton(() => authVM.handleBiometricLogin(context)),
                    ],
                  ),
                  
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

  // --- DESIGN COMPONENTS ---
  Widget _buildHexagonLogo() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: Colors.black, border: Border.all(color: cyanPrimary.withOpacity(0.5), width: 2)),
    child: const Icon(Icons.shield_outlined, color: cyanPrimary, size: 30),
  );

  Widget _buildMainTitle() => Column(
    children: [
      RichText(
        text: TextSpan(
          style: GoogleFonts.orbitron(fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: 3, fontStyle: FontStyle.italic),
          children: const [
            TextSpan(text: "SECURE", style: TextStyle(color: Colors.white)),
            TextSpan(text: "VAULT", style: TextStyle(color: cyanPrimary)),
          ],
        ),
      ),
      const SizedBox(height: 6),
      Text("ENCRYPTED LOCAL STORAGE", style: GoogleFonts.spaceGrotesk(color: cyanPrimary, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 3)),
    ],
  );

  Widget _buildLabelRow(String left, String right, {bool isAction = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 8.0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(left, style: GoogleFonts.spaceGrotesk(color: cyanPrimary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        Text(right, style: GoogleFonts.spaceGrotesk(color: isAction ? pinkAccent : Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
      ],
    ),
  );

  Widget _buildPrimaryButton(String text, IconData icon, {VoidCallback? onTap}) => Container(
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

  Widget _buildSecondaryButton(String text, {required IconData icon, Color color = cyanPrimary, VoidCallback? onTap}) => Container(
    height: 55,
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.03), 
      border: Border.all(color: Colors.white10),
      borderRadius: BorderRadius.circular(4),
    ),
    child: InkWell(
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 4),
          Text(text, style: GoogleFonts.orbitron(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 8, letterSpacing: 1)),
        ],
      ),
    ),
  );

  Widget _buildBiometricButton(VoidCallback onTap) => Container(
    width: 60, height: 55,
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.03), 
      border: Border.all(color: Colors.white10),
      borderRadius: const BorderRadius.only(bottomRight: Radius.circular(10))
    ),
    child: InkWell(onTap: onTap, child: const Icon(Icons.fingerprint, color: cyanPrimary, size: 28)),
  );

  Widget _buildFooter(BuildContext context) => InkWell(
    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterView())),
    child: RichText(
      text: TextSpan(
        style: GoogleFonts.spaceGrotesk(fontSize: 11, color: Colors.white24, letterSpacing: 0.5),
        children: const [
          TextSpan(text: "New operative?  "),
          TextSpan(text: "REGISTER IDENTITY", style: TextStyle(color: pinkAccent, fontWeight: FontWeight.bold)),
        ],
      ),
    ),
  );
}