import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/encryption_service.dart';
import '../services/storage_service.dart';

class TodoViewModel extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  final StorageService _storageService = StorageService();
  
  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> get tasks => _tasks;

  Future<void> loadTasks() async {
    final key = await _storageService.getDatabaseKey();
    final db = await _dbService.getDatabase(key);
    final encryptor = EncryptionService(key);
    
    final List<Map<String, dynamic>> rawData = await db.query('tasks');
    
    _tasks = rawData.map((task) {
      return {
        ...task,
        'display_note': encryptor.decryptField(task['encrypted_note']),
      };
    }).toList();
    
    notifyListeners();
  }

  Future<void> addTask(String title, String note) async {
    final key = await _storageService.getDatabaseKey();
    final db = await _dbService.getDatabase(key);
    final encryptor = EncryptionService(key);

    await db.insert('tasks', {
      'title': title,
      'encrypted_note': encryptor.encryptField(note),
    });
    
    await loadTasks();
  }
}