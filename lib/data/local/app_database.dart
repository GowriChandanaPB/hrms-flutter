
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._({this.databasePath});

  static final AppDatabase instance = AppDatabase._();

  // Optional full database path, primarily for isolated tests.
  final String? databasePath;

  static const _databaseName = 'rebs_hrms.db';
  static const _databaseVersion = 1;

  Database? _database;
  Future<Database>? _databaseFuture;

  factory AppDatabase.forTesting(String path) {
    return AppDatabase._(databasePath: path);
  }

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }

    _databaseFuture ??= _openDatabase();

    try {
      _database = await _databaseFuture!;
      return _database!;
    } catch (_) {
      _databaseFuture = null;
      rethrow;
    }
  }

  Future<Database> _openDatabase() async {
    final path = databasePath ??
        join(await getDatabasesPath(), _databaseName);

    return openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _createTables,
      onUpgrade: _upgradeDatabase,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE employee (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        department TEXT NOT NULL,
        designation TEXT NOT NULL,
        email TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE attendance_events (
        id TEXT PRIMARY KEY,
        employee_id TEXT NOT NULL,
        type TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        sync_status TEXT NOT NULL,
        created_order INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_attendance_order
      ON attendance_events(created_order)
    ''');

    await db.execute('''
      CREATE INDEX idx_attendance_timestamp
      ON attendance_events(timestamp)
    ''');

    await db.execute('''
      CREATE TABLE leave_balance (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        casual_leave INTEGER NOT NULL,
        sick_leave INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE leave_requests (
        id TEXT PRIMARY KEY,
        employee_id TEXT NOT NULL,
        type TEXT NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        reason TEXT NOT NULL,
        status TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_leave_dates
      ON leave_requests(start_date, end_date)
    ''');
  }

  Future<void> _upgradeDatabase(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // Add migrations here when the schema changes.
  }

  Future<void> close() async {
    final database = _database;

    _database = null;
    _databaseFuture = null;

    if (database != null && database.isOpen) {
      await database.close();
    }
  }
}
