import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:async';
import '../models/user_model.dart';
import '../services/database_service.dart';
import '../services/storage_service.dart';
import '../services/biometric_service.dart';
import '../views/todo_list_view.dart';

class AuthViewModel extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  final StorageService _storageService = StorageService();
  final BiometricService _biometricService = BiometricService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // --- OTP STATE ---
  final TextEditingController otpController = TextEditingController();
  String? _generatedOTP;
  bool _isWaitingForOTP = false;
  bool get isWaitingForOTP => _isWaitingForOTP;
  
  String? _tempName;
  String? _tempEmail;
  String? _tempPassword;

  // --- UI CONTROLLERS ---
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  bool obscurePassword = true;

  void togglePasswordVisibility() {
    obscurePassword = !obscurePassword;
    notifyListeners();
  }

  // --- STEP 1: REGISTRATION & OTP TRIGGER ---
  Future<void> handleRegister(BuildContext context) async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty || nameController.text.isEmpty) {
      _showSnackBar(context, "All fields are required.", isError: true);
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final hardwareKey = await _storageService.getDatabaseKey();
      final db = await _dbService.getDatabase(hardwareKey);

      final existing = await db.query('users', where: 'email = ?', whereArgs: [emailController.text.trim()]);
      if (existing.isNotEmpty) {
        _showSnackBar(context, "Identity already registered. Please Login.", isError: true);
        return;
      }

      _tempName = nameController.text.trim();
      _tempEmail = emailController.text.trim();
      _tempPassword = passwordController.text.trim();

      // Lab Requirement: MFA Simulation (Bonus Points)
      _generatedOTP = "123456"; 
      _isWaitingForOTP = true;
      _showSnackBar(context, "MFA Protocol: Code 123456 transmitted to $_tempEmail");
      
    } catch (e) {
      _showSnackBar(context, "Transmission Failed: $e", isError: true);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- STEP 2: VERIFY OTP & SAVE TO SQLCIPHER ---
  Future<void> verifyOTPAndRegister(BuildContext context) async {
    if (otpController.text.trim() == _generatedOTP) {
      _isLoading = true;
      notifyListeners();

      try {
        final hardwareKey = await _storageService.getDatabaseKey();
        final db = await _dbService.getDatabase(hardwareKey);

        await db.insert('users', {
          'fullName': _tempName,
          'email': _tempEmail,
          'password': _tempPassword,
        });

        _isWaitingForOTP = false;
        _generatedOTP = null;
        otpController.clear();

        _showSnackBar(context, "Identity Secured. Account Activated.");
        Navigator.pop(context); 
      } catch (e) {
        _showSnackBar(context, "Database Protocol Failure.", isError: true);
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    } else {
      _showSnackBar(context, "Invalid Access Code.", isError: true);
    }
  }

  // --- MANUAL LOGIN ---
  Future<void> handleLogin(BuildContext context) async {
    _isLoading = true;
    notifyListeners();

    try {
      final hardwareKey = await _storageService.getDatabaseKey();
      final db = await _dbService.getDatabase(hardwareKey);

      final List<Map<String, dynamic>> results = await db.query(
        'users',
        where: 'email = ? AND password = ?',
        whereArgs: [emailController.text.trim(), passwordController.text.trim()],
      );

      if (results.isNotEmpty) {
        await _secureStorage.write(key: "last_email", value: emailController.text.trim());
        await _secureStorage.write(key: "last_pass", value: passwordController.text.trim());

        _currentUser = UserModel(
          id: results.first['id'].toString(),
          fullName: results.first['fullName'],
          email: results.first['email'],
        );

        _navigateToDashboard(context);
      } else {
        _showSnackBar(context, "Access Denied: Invalid Credentials", isError: true);
      }
    } catch (e) {
      _showSnackBar(context, "Vault is Locked.", isError: true);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- BIOMETRIC LOGIN ---
  Future<void> handleBiometricLogin(BuildContext context) async {
    try {
      // Fix: Ensured the result is handled as a boolean check
      final bool authenticated = await _biometricService.authenticate();
      if (!authenticated) return;

      String? email = await _secureStorage.read(key: "last_email");
      String? pass = await _secureStorage.read(key: "last_pass");

      if (email != null && pass != null) {
        emailController.text = email;
        passwordController.text = pass;
        await handleLogin(context);
      } else {
        _showSnackBar(context, "Biometrics not initialized. Login with password first.", isError: true);
      }
    } catch (e) {
      _showSnackBar(context, "Biometric Failure: $e", isError: true);
    }
  }

  // --- FIX: Added missing cancelOTP method ---
  void cancelOTP() {
    _isWaitingForOTP = false;
    _generatedOTP = null;
    otpController.clear();
    notifyListeners();
  }

  void _navigateToDashboard(BuildContext context) {
    emailController.clear();
    passwordController.clear();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => TodoListView()));
  }

  void _showSnackBar(BuildContext context, String message, {bool isError = false}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Poppins')),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF0DA6F2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    otpController.dispose();
    super.dispose();
  }
}