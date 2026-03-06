import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  Database? _db;

  Future<Database> getDatabase(String hardwareKey) async {
    if (_db != null) return _db!;
    _db = await _initDB(hardwareKey);
    return _db!;
  }

  Future<Database> _initDB(String password) async {
    String path = join(await getDatabasesPath(), 'cipher_task_v1.db');
    return await openDatabase(
      path,
      password: password, 
      version: 1,
      onCreate: (db, version) async {
        // Create User Table for Local Auth
        await db.execute('''
          CREATE TABLE users(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            fullName TEXT,
            email TEXT,
            password TEXT
          )
        ''');
        // Create Task Table
        await db.execute('''
          CREATE TABLE tasks(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            encrypted_note TEXT
          )
        ''');
      },
    );
  }
}