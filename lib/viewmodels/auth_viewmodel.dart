import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:async';
import '../models/user_model.dart';
import '../services/database_service.dart'; // Consolidated service
import '../views/todo_list_view.dart';
import '../utils/constants.dart'; 

class AuthViewModel extends ChangeNotifier {
  // Using the consolidated DatabaseService for everything
  final DatabaseService _dbService = DatabaseService(); 
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Timer? _sessionTimer;

  void resetSessionTimer(BuildContext context) {
    _sessionTimer?.cancel();
    _sessionTimer = Timer(const Duration(minutes: 2), () {
      logout();
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    });
  }

  Future<void> logout() async {
    _sessionTimer?.cancel();
    // Using the new consolidated signOut which handles Firebase, Google, Facebook, and Vault
    await _dbService.signOut(); 
    
    clearAuthInputs(); 
    
    _currentUser = null;
    notifyListeners();
  }

  void clearAuthInputs() {
    emailController.clear();
    passwordController.clear();
    otpController.clear();
    obscurePassword = true; 
    notifyListeners();
  }

  final TextEditingController otpController = TextEditingController();
  String? _generatedOTP;
  bool _isWaitingForOTP = false;
  bool get isWaitingForOTP => _isWaitingForOTP;

  int _resendCountdown = 30;
  int get resendCountdown => _resendCountdown;
  bool get canResend => _resendCountdown == 0;
  Timer? _resendTimer;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool obscurePassword = true;

  String? _tempName;
  String? _tempProvider;

  void togglePasswordVisibility() {
    obscurePassword = !obscurePassword;
    notifyListeners();
  }

  Future<void> handleLogin(BuildContext context) async {
    if (emailController.text.trim().isEmpty || passwordController.text.trim().isEmpty) {
      _showSnackBar(context, "DATA MISSING", isError: true);
      return;
    }

    bool success = await login(emailController.text.trim(), passwordController.text.trim());
    
    if (success) {
      _showSnackBar(context, "Identity Verified. Welcome Agent.");
      
      if (context.mounted) {
        clearAuthInputs(); 
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const TodoListView()));
      }
    } else {
      _showSnackBar(context, _errorMessage ?? "Access Denied", isError: true);
    }
  }
  
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Switched to _dbService
      User? firebaseUser = await _dbService.loginWithEmail(email, password);
      
      if (firebaseUser != null) {
        await _secureStorage.write(key: "session_email", value: email);
        await _secureStorage.write(key: "session_password", value: password);

        await _dbService.openUserVault(firebaseUser.uid);
        DocumentSnapshot userDoc = await _db.collection('users').doc(firebaseUser.uid).get();

        _currentUser = UserModel(
          id: firebaseUser.uid, 
          fullName: userDoc.get('fullName') ?? "Agent", 
          email: email
        );
        
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = "AUTH_PROTOCOL_ERROR: Check credentials.";
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> handleBiometricLogin(BuildContext context) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Switched to _dbService
      String deviceId = await _dbService.getDeviceId();
      DocumentSnapshot registryDoc = await _db.collection('biometric_registry').doc(deviceId).get();
      
      if (!registryDoc.exists) {
        throw "This device is not registered for biometric access.";
      }

      String ownerId = registryDoc.get('userId');
      String? ownerEmail = await _secureStorage.read(key: "biometric_email");
      String? ownerPassword = await _secureStorage.read(key: "biometric_password");

      if (ownerEmail == null || ownerPassword == null) {
        throw "Biometric credentials not found. Please login manually and re-enable it in settings.";
      }

      // Switched to _dbService
      String? authError = await _dbService.authenticate();
      if (authError != null) throw authError;

      UserCredential userCred = await _auth.signInWithEmailAndPassword(
        email: ownerEmail, 
        password: ownerPassword
      );

      if (userCred.user?.uid != ownerId) {
        await _dbService.signOut();
        throw "Security Breach: Identity mismatch. Hardware belongs to another user.";
      }

      await _dbService.openUserVault(ownerId);
      DocumentSnapshot userDoc = await _db.collection('users').doc(ownerId).get();
      
      _currentUser = UserModel(
        id: ownerId, 
        fullName: userDoc.get('fullName'), 
        email: userDoc.get('email')
      );

      _showSnackBar(context, "Welcome back, ${_currentUser?.fullName}");
      
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context, 
          MaterialPageRoute(builder: (context) => const TodoListView()),
          (route) => false
        );
      }
    } catch (e) {
      debugPrint("Biometric Login Failed: $e");
      _showSnackBar(context, e.toString(), isError: true);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> verifyOTPAndAccess(BuildContext context) async {
    if (otpController.text.trim().isEmpty) {
      _showSnackBar(context, "Please enter verification code.", isError: true);
      return;
    }

    if (otpController.text.trim() != _generatedOTP) {
      _showSnackBar(context, "Invalid Code.", isError: true);
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final user = _auth.currentUser;
      if (user == null) throw "Session expired. Please restart registration.";

      await _db.collection('users').doc(user.uid).set({
        'fullName': _tempName ?? "Agent",
        'email': user.email,
        'otpVerified': true,
        'provider': 'email',
        'biometricEnabled': false,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _dbService.openUserVault(user.uid);
      await _dbService.saveLocalUser(user.uid, _tempName ?? "Agent", user.email!);

      String? tPass = await _secureStorage.read(key: "temp_password");
      await _secureStorage.write(key: "session_password", value: tPass); 
      await _secureStorage.write(key: "session_email", value: user.email);

      await _secureStorage.delete(key: "temp_password"); 

      _currentUser = UserModel(id: user.uid, fullName: _tempName ?? "Agent", email: user.email!);
      _isWaitingForOTP = false;
      
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context, 
          MaterialPageRoute(builder: (context) => const TodoListView()), 
          (route) => false
        );
      }
    } catch (e) {
      _showSnackBar(context, "Protocol Error: ${e.toString()}", isError: true);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _abortRegistration() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.delete();
        debugPrint("REGISTRATION_CLEANUP: Unverified user purged from Firebase.");
      }
    } catch (e) {
      debugPrint("CLEANUP_ERROR: ${e.toString()}");
    }
  }

  void cancelOTP(BuildContext context) {
    _isWaitingForOTP = false;
    _resendTimer?.cancel();
    _abortRegistration(); 
    _tempName = null;
    _tempProvider = null;
    _generatedOTP = null;
    otpController.clear();
    _showSnackBar(context, "Registration Cancelled.");
    notifyListeners();
  }

  Future<bool> register(BuildContext context, String name, String email, String password) async {
    if (name.trim().isEmpty || email.trim().isEmpty || password.trim().isEmpty) {
      _errorMessage = "FIELD_ERROR: All credentials required.";
      _showSnackBar(context, _errorMessage!, isError: true);
      return false;
    }

    bool hasMin8 = password.length >= 8;
    bool hasUpper = password.contains(RegExp(r'[A-Z]'));
    bool hasLower = password.contains(RegExp(r'[a-z]'));
    bool hasNum = password.contains(RegExp(r'[0-9]'));
    bool hasSpecial = password.contains(RegExp(r'[!@#\$&*~]'));

    if (!hasMin8 || !hasUpper || !hasLower || !hasNum || !hasSpecial) {
      _errorMessage = "SECURITY_BREACH: Password strength insufficient.";
      _showSnackBar(context, _errorMessage!, isError: true);
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final existing = await _db.collection('users')
          .where('email', isEqualTo: email)
          .where('otpVerified', isEqualTo: true)
          .get();
      
      if (existing.docs.isNotEmpty) {
        _errorMessage = "IDENTITY_ACTIVE: Identity already registered.";
        _showSnackBar(context, _errorMessage!, isError: true);
        return false;
      }

      // Switched to _dbService
      User? firebaseUser = await _dbService.registerWithEmail(name, email, password);
      
      if (firebaseUser != null) {
        await _secureStorage.write(key: "temp_password", value: password);
        bool success = await _triggerOTPProtocol(context, email, firebaseUser.uid, name);
        return success; 
      }
      return false;
    } catch (e) {
      debugPrint("REGISTRATION_SYSTEM_ERROR: $e");
      _errorMessage = "PROTOCOL_FAILURE: Service unreachable.";
      _showSnackBar(context, _errorMessage!, isError: true);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> _triggerOTPProtocol(BuildContext context, String email, String uid, String? name, {String provider = 'email'}) async {
    _isWaitingForOTP = true;
    _tempName = name;
    _tempProvider = provider;
    notifyListeners();

    // Switched to _dbService
    _generatedOTP = await _dbService.sendEmailOTP(email);

    if (_generatedOTP != null) {
      _startResendTimer();
      _showSnackBar(context, "Verification Code Transmitted to $email");
      return true;
    } else {
      await _abortRegistration();
      _isWaitingForOTP = false;
      _showSnackBar(context, "TRANSMISSION_ERROR: Check email address.", isError: true);
      notifyListeners();
      return false;
    }
  }

  void _startResendTimer() {
    _resendCountdown = 30;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        _resendCountdown--;
        notifyListeners();
      } else {
        timer.cancel();
      }
    });
  }

  void _showSnackBar(BuildContext context, String message, {bool isError = false}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.spaceGrotesk(color: Colors.white)),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF0DA6F2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _sessionTimer?.cancel();
    emailController.dispose();
    passwordController.dispose();
    otpController.dispose();
    super.dispose();
  }
}