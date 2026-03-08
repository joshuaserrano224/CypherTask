import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:local_auth/local_auth.dart';
import '../utils/constants.dart';
import '../models/todo_model.dart';

class DatabaseService {
  // Singleton pattern
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  // Instances
  static Database? _database;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final LocalAuthentication _localAuth = LocalAuthentication();

  // Track the current user ID to manage separate vault files
  String? _currentUserId;

  // --- VAULT & DATABASE CORE ---

  // The database getter now requires the vault to be opened via openUserVault first
  Future<Database> get database async {
    if (_database != null) return _database!;
    throw "SECURITY_ERROR: Vault not initialized. Call openUserVault(uid) first.";
  }

  /// INITIATES A USER-SPECIFIC SESSION
  /// Call this in AuthViewModel during login or after OTP verification.
  Future<void> openUserVault(String uid) async {
    // If the correct vault is already open, do nothing
    if (_database != null && _currentUserId == uid) return;

    // If a different vault is open, close it first
    if (_database != null) {
      await _database!.close();
      _database = null;
    }

    _currentUserId = uid;
    _database = await _initDB(uid);
  }

  Future<Database> _initDB(String uid) async {
    // 1. GENERATE/RETRIEVE USER-SPECIFIC MASTER KEY
    // Each user gets a unique key stored under their own UID in Secure Storage
    String keyName = 'db_key_$uid';
    String? userKey = await _storage.read(key: keyName);
    
    if (userKey == null) {
      userKey = base64Url.encode(List<int>.generate(32, (i) => Random.secure().nextInt(256)));
      await _storage.write(key: keyName, value: userKey);
    }

    // 2. GENERATE USER-SPECIFIC FILE PATH
    // Prevents "File is not a database" errors by giving each user their own file
    String databasesPath = await getDatabasesPath();
    String path = '$databasesPath/vault_$uid.db';

    return await openDatabase(
      path,
      password: userKey,
      version: 3,
      onCreate: (db, version) async {
        // Create users table
        await db.execute('CREATE TABLE users(id TEXT PRIMARY KEY, fullName TEXT, email TEXT)');
        
        // Create tasks table with full schema
        await db.execute('''
          CREATE TABLE tasks(
            id INTEGER PRIMARY KEY AUTOINCREMENT, 
            title TEXT, 
            secretNote TEXT, 
            isDone INTEGER,
            createdAt TEXT,
            updatedAt TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute('ALTER TABLE tasks ADD COLUMN secretNote TEXT');
          } catch (e) {
            debugPrint("Migration V2 Note: $e");
          }
        }
        if (oldVersion < 3) {
          try {
            await db.execute('ALTER TABLE tasks ADD COLUMN createdAt TEXT');
            await db.execute('ALTER TABLE tasks ADD COLUMN updatedAt TEXT');
          } catch (e) {
            debugPrint("Migration V3 Note: $e");
          }
        }
      },
    );
  }

  /// CLOSES THE VAULT SESSION
  /// Call this during logout to ensure the database is locked.
  Future<void> closeVault() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      _currentUserId = null;
    }
  }

  // --- AUTHENTICATION & SECURE STORAGE ---

  Future<void> saveToken(String token) async {
    await _storage.write(key: 'auth_token', value: token);
  }

  Future<void> clearSession() async {
    // Only delete the auth_token. 
    // DO NOT delete login_provider, otherwise biometrics won't know which service to call.
    await _storage.delete(key: 'auth_token');
  }

  Future<void> saveProvider(String provider) async {
    await _storage.write(key: 'login_provider', value: provider);
  }

  Future<String?> getProvider() async {
    return await _storage.read(key: 'login_provider');
  }

  Future<User?> registerWithEmail(String name, String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password
      );
      
      User? user = result.user;
      if (user != null) {
        await user.updateDisplayName(name);
        String? token = await user.getIdToken();
        if (token != null) await saveToken(token);
      }
      return user;
    } catch (e) {
      rethrow; 
    }
  }

  Future<User?> loginWithEmail(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email, 
        password: password
      );

      User? user = result.user;
      if (user != null) {
        String? token = await user.getIdToken();
        if (token != null) await saveToken(token);
      }
      return user;
    } catch (e) {
      rethrow;
    }
  }

  Future<User?> loginWithGoogle() async {
    try {
      await _googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);
      String? token = await userCredential.user?.getIdToken();
      if (token != null) await saveToken(token);

      return userCredential.user;
    } catch (e) {
      rethrow;
    }
  }

  Future<User?> silentLoginWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();
      if (googleUser == null) return await loginWithGoogle(); 

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);
      return userCredential.user;
    } catch (e) {
      debugPrint("Silent Google Auth Failed: $e");
      return null;
    }
  }

  Future<User?> loginWithFacebook() async {
    try {
      final LoginResult result = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
      );

      if (result.status == LoginStatus.success) {
        final AuthCredential credential = FacebookAuthProvider.credential(
          result.accessToken!.tokenString,
        );

        UserCredential userCredential = await _auth.signInWithCredential(credential);
        String? token = await userCredential.user?.getIdToken();
        if (token != null) await saveToken(token);

        return userCredential.user;
      } else if (result.status == LoginStatus.cancelled) {
        return null;
      } else {
        throw result.message ?? "Facebook login failed.";
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
    await FacebookAuth.instance.logOut();
    await _storage.delete(key: 'auth_token');
    await closeVault();
  }

  // --- BIOMETRIC REGISTRY & DEVICE OPS ---

  Future<bool> isBiometricLocked() async {
    String? ownerEmail = await _storage.read(key: "bio_owner_email");
    return ownerEmail != null;
  }

  Future<void> registerDeviceForBiometrics(String uid, String deviceId, bool isEnabled) async {
    final docRef = _db.collection('biometric_registry').doc(deviceId);
    if (isEnabled) {
      final doc = await docRef.get();
      if (doc.exists) {
        String registeredOwnerId = doc.get('userId');
        if (registeredOwnerId != uid) {
          throw "DEVICE_LOCKED: This device is already linked to another account.";
        }
      }
      await docRef.set({
        'userId': uid,
        'registeredAt': FieldValue.serverTimestamp(),
      });
    } else {
      final doc = await docRef.get();
      if (doc.exists && doc.get('userId') == uid) {
        await docRef.delete();
      }
    }
  }

  Future<void> updateBiometricPreference(String uid, bool isEnabled, {String? email, String? password}) async {
    await _db.collection('users').doc(uid).update({
      'biometricEnabled': isEnabled,
    });
    
    await _storage.write(key: "bio_enabled_$uid", value: isEnabled.toString());

    if (isEnabled && email != null && password != null) {
      await _storage.write(key: "bio_owner_email", value: email);
      await _storage.write(key: "bio_owner_password", value: password);
      debugPrint("SECURE_AUTH: Biometric Owner Credentials Locked.");
    } else if (!isEnabled) {
      await _storage.delete(key: "bio_owner_email");
      await _storage.delete(key: "bio_owner_password");
      debugPrint("SECURE_AUTH: Biometric Owner Credentials Purged.");
    }
  }

  Future<String> getDeviceId() async {
    var deviceInfo = DeviceInfoPlugin();
    if (Platform.isIOS) {
      var iosDeviceInfo = await deviceInfo.iosInfo;
      return iosDeviceInfo.identifierForVendor ?? "unknown_ios";
    } else {
      var androidDeviceInfo = await deviceInfo.androidInfo;
      return androidDeviceInfo.id;
    }
  }

  Future<String?> authenticate() async {
    try {
      bool canCheck = await _localAuth.canCheckBiometrics;
      if (!canCheck) return "Biometrics not available.";

      bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'AUTHENTICATION_REQUIRED: Verify identity to unlock vault.',
        options: const AuthenticationOptions(stickyAuth: true, biometricOnly: true),
      );
      return didAuthenticate ? null : "Verification failed.";
    } catch (e) {
      return e.toString();
    }
  }

  // --- OTP & EMAIL PROTOCOL ---

  Future<String> sendEmailOTP(String recipientEmail) async {
    String otp = (100000 + (DateTime.now().millisecondsSinceEpoch % 900000)).toString().substring(0, 6);
    final smtpServer = gmail(AppConstants.smtpEmail, AppConstants.smtpPassword);

    final message = Message()
      ..from = Address(AppConstants.smtpEmail, 'CYPHERTASK')
      ..recipients.add(recipientEmail)
      ..subject = 'ACCESS CODE: $otp'
      ..html = """
        <div style="font-family: monospace; background-color: #020408; color: #0DA6F2; padding: 20px; border: 1px solid #0DA6F2;">
          <h2 style="color: white;">SECURITY PROTOCOL</h2>
          <p>Your authentication code is:</p>
          <h1 style="color: #FF00FF; letter-spacing: 5px;">$otp</h1>
          <p style="font-size: 10px; color: grey;">If you did not request this, ignore this transmission.</p>
        </div>
      """;

    try {
      await send(message, smtpServer);
      return otp;
    } catch (e) {
      throw "Mailer Error: Protocol failed to transmit.";
    }
  }

  // --- LOCAL DATA OPERATIONS ---

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('tasks');
    await db.delete('users');
  }

  Future<List<TodoModel>> getTasks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('tasks');
    return List.generate(maps.length, (i) => TodoModel.fromMap(maps[i]));
  }

  Future<void> insertTask(TodoModel todo) async {
    final db = await database;
    await db.insert(
      'tasks',
      todo.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateTask(TodoModel todo) async {
    final db = await database;
    return await db.update(
      'tasks',
      todo.toMap(),
      where: 'id = ?',
      whereArgs: [todo.id],
    );
  }

  Future<void> deleteTask(int id) async {
    final db = await database;
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> saveLocalUser(String id, String name, String email) async {
    final db = await database;
    await db.insert('users', {'id': id, 'fullName': name, 'email': email},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }
}