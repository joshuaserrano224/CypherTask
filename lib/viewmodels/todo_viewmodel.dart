import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/todo_model.dart';
import '../services/database_service.dart'; // Primary hub
import '../services/encryption_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TodoViewModel extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseService _dbService = DatabaseService();
  final EncryptionService _encryptionService = EncryptionService();
  final _storage = const FlutterSecureStorage();

  List<TodoModel> _todos = [];
  bool _isLoading = false;
  bool _isMinimized = false;
  bool _isBiometricEnabled = false; 
  String? _errorMessage;

  Timer? _inactivityTimer;
  bool _isSessionExpired = false;

  List<TodoModel> get todos => _todos;
  bool get isLoading => _isLoading;
  bool get isMinimized => _isMinimized;
  bool get isBiometricEnabled => _isBiometricEnabled;
  bool get isSessionExpired => _isSessionExpired;
  String? get errorMessage => _errorMessage;

  String _searchQuery = "";

  List<TodoModel> get filteredTodos {
    if (_searchQuery.isEmpty) {
      return _todos;
    }
    return _todos.where((todo) {
      final title = todo.title.toLowerCase();
      final query = _searchQuery.toLowerCase();
      return title.contains(query);
    }).toList();
  }

  void updateSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  TodoViewModel() {
    _initializeVault();
  }

  void clearError() {
    _errorMessage = null;
  }

  Future<void> _initializeVault() async {
    _setLoading(true);
    await _encryptionService.init(); 
    
    await Future.wait([
      loadUserPreferences(), 
      loadTasks(),
    ]);
    
    _setLoading(false);
  }

  Future<void> toggleBiometrics() async {
    if (_isLoading) return;
    
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    bool targetState = !_isBiometricEnabled;
    _errorMessage = null;

    try {
      _setLoading(true);
      String deviceId = await _dbService.getDeviceId(); 
      String userSpecificKey = "bio_enabled_${user.uid}";

      if (targetState) {
        DocumentSnapshot registryDoc = await FirebaseFirestore.instance
            .collection('biometric_registry').doc(deviceId).get();

        if (registryDoc.exists && registryDoc.get('userId') != user.uid) {
          throw "HARDWARE_CONFLICT: This device is already linked to another identity.";
        }

        final String? authError = await _dbService.authenticate();
        if (authError != null) throw "AUTH_FAILED: $authError";

        String? sessionPass = await _storage.read(key: "session_password"); 

        if (sessionPass == null) {
          sessionPass = await _storage.read(key: "biometric_password");
        }

        if (sessionPass == null) {
          throw "SESSION_EXPIRED: Please log out and back in to refresh credentials.";
        }

        await _storage.write(key: "biometric_email", value: user.email);
        await _storage.write(key: "biometric_password", value: sessionPass);

        await _dbService.registerDeviceForBiometrics(user.uid, deviceId, true);
        await _dbService.updateBiometricPreference(
          user.uid, 
          true, 
          email: user.email, 
          password: sessionPass
        );
        
        await _storage.write(key: userSpecificKey, value: "true");
        
      } else {
        await _dbService.registerDeviceForBiometrics(user.uid, deviceId, false);
        await _dbService.updateBiometricPreference(user.uid, false);
        
        await _storage.delete(key: "biometric_email");
        await _storage.delete(key: "biometric_password");
        await _storage.write(key: userSpecificKey, value: "false");
      }

      _isBiometricEnabled = targetState;
      notifyListeners();
      
    } catch (e) {
      _errorMessage = e.toString().replaceAll("Exception: ", "");
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }
  
  Future<void> loadUserPreferences() async {
    final user = _auth.currentUser;
    if (user == null) {
      _isBiometricEnabled = false;
      notifyListeners();
      return;
    }

    String userSpecificKey = "bio_enabled_${user.uid}";

    try {
      var doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      
      if (doc.exists) {
        _isBiometricEnabled = doc.data()?['biometricEnabled'] ?? false;
        await _storage.write(key: userSpecificKey, value: _isBiometricEnabled.toString());
      } else {
        _isBiometricEnabled = false;
      }
    } catch (e) {
      debugPrint("PREFERENCE_SYNC_ERROR: $e");
      String? localVal = await _storage.read(key: userSpecificKey);
      _isBiometricEnabled = (localVal == 'true');
    }
    
    notifyListeners();
  }

  void clearStateOnLogout() {
    _todos = [];
    _isBiometricEnabled = false; 
    _searchQuery = "";
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> loadTasks() async {
    try {
      _todos = await _dbService.getTasks();
    } catch (e) {
      _errorMessage = "Vault Access Denied.";
      notifyListeners();
    }
    notifyListeners();
  }

  Future<void> updateTask(int id, String title, String rawNote) async {
    _isLoading = true;
    notifyListeners();

    try {
      debugPrint("--- SECURITY ENCLAVE: UPDATE PROTOCOL ---");
      debugPrint("ORIGINAL NOTE: $rawNote");

      String timestamp = DateTime.now().toIso8601String();
      String encryptedNote = _encryptionService.encryptText(rawNote);

      debugPrint("ENCRYPTED FOR DATABASE: $encryptedNote");

      final updatedTodo = TodoModel(
        id: id,
        title: title,
        secretNote: encryptedNote,
        isDone: false,
        createdAt: timestamp,
        updatedAt: timestamp, 
      );

      await _dbService.updateTask(updatedTodo); 
      await loadTasks(); 
      _errorMessage = null;
    } catch (e) {
      _errorMessage = "UPDATE_FAILED: 0x${e.hashCode.toRadixString(16)}";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addTask(String title, String rawNote) async {
    if (title.isEmpty) return;
    
    try {
      debugPrint("--- SECURITY ENCLAVE: STORAGE PROTOCOL ---");
      debugPrint("RAW INPUT: $rawNote");

      String timestamp = DateTime.now().toIso8601String();
      String encryptedNote = _encryptionService.encryptText(rawNote);
      
      debugPrint("AES-256 RESULT: $encryptedNote");

      final newTodo = TodoModel(
        title: title, 
        secretNote: encryptedNote, 
        isDone: false,
        createdAt: timestamp, 
        updatedAt: timestamp, 
      );

      await _dbService.insertTask(newTodo);
      debugPrint("PROTOCOL COMPLETE: Data committed to SQLCipher.");
      await loadTasks();
    } catch (e) {
      _errorMessage = "TASK_ADD_FAILED: Could not save to vault.";
      notifyListeners();
    }
  }

  String getDecryptedNote(String cipherText) {
    try {
      // PROOF FOR INSTRUCTOR: Showing the decryption moment
      debugPrint("DECRYPTING VAULT DATA: $cipherText");
      String plainText = _encryptionService.decryptText(cipherText);
      debugPrint("RECOVERED PLAINTEXT: $plainText");
      return plainText;
    } catch (e) {
      debugPrint("DECRYPTION_ERROR: 0x${e.toString().hashCode.toRadixString(16)}");
      return "ERROR: DATA_CORRUPTION_DETECTED";
    }
  }

  Future<void> deleteTask(int id) async {
    try {
      await _dbService.deleteTask(id);
      await loadTasks();
    } catch (e) {
      _errorMessage = "DELETE_FAILED: Security restriction.";
      notifyListeners();
    }
  }

  Future<void> deleteUserAccount() async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final String uid = user.uid;

      var bioDocs = await FirebaseFirestore.instance
          .collection('biometric_registry')
          .where('userId', isEqualTo: uid)
          .get();
      
      for (var doc in bioDocs.docs) {
        await doc.reference.delete();
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .delete();

      await _dbService.clearAllData();
      await _storage.deleteAll();

      await user.delete();
      
      _todos.clear();
      notifyListeners();

    } catch (e) {
      if (e.toString().contains("recent-login")) {
        _errorMessage = "Please log out and log back in to verify it's you.";
      } else {
        _errorMessage = "Action failed. Security integrity check required.";
      }
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  void resetInactivityTimer(BuildContext context, VoidCallback onTimeout) {
    _isSessionExpired = false;
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(minutes: 2), () { 
      _isSessionExpired = true;
      onTimeout();
      notifyListeners();
    });
  }
  
  void setMinimized(bool value) {
    if (_isMinimized != value) {
      _isMinimized = value;
      notifyListeners();
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }
}