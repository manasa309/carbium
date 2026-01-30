import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/user.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'carbium_user_db.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute(
      '''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        created_at TEXT NOT NULL,
        security_question TEXT NOT NULL,
        security_answer TEXT NOT NULL
      )
      ''',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('DROP TABLE IF EXISTS users');
      await _onCreate(db, newVersion);
    }
  }

  Future<int> createUser(User user) async {
    final db = await database;
    try {
      return await db.insert(
        'users',
        user.toMap(),
        conflictAlgorithm: ConflictAlgorithm.fail, // Fail if email exists
      );
    } catch (e) {
      if (e.toString().contains('UNIQUE constraint failed')) {
        throw Exception('Email already exists');
      }
      rethrow;
    }
  }

  Future<User?> getUserByEmail(String email) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
    );

    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<User?> validateUser(String email, String password) async {
    final user = await getUserByEmail(email);
    if (user == null) return null;

    final hashedPassword = User.hashPassword(password);
    if (user.passwordHash == hashedPassword) {
      return user;
    }
    return null;
  }

  Future<void> clearAllUsers() async {
    final db = await database;
    await db.delete('users');
  }

  Future<void> updatePassword(String email, String newPassword) async {
    final db = await database;
    final hashedPassword = User.hashPassword(newPassword);
    await db.update(
      'users',
      {'password_hash': hashedPassword},
      where: 'email = ?',
      whereArgs: [email],
    );
  }

  Future<String?> getSecurityQuestion(String email) async {
    final user = await getUserByEmail(email);
    return user?.securityQuestion;
  }
}
