import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/patient.dart';
import '../models/booking.dart';

class DatabaseService {
  static Database? _database;
  static const String _databaseName = 'qatar_app.db';
  static const int _databaseVersion = 1;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE patients(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        createdAt INTEGER,
        updatedAt INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE bookings(
        id TEXT PRIMARY KEY,
        patientId TEXT NOT NULL,
        clinicId TEXT NOT NULL,
        clinicName TEXT NOT NULL,
        doctorId TEXT,
        doctorName TEXT,
        status TEXT NOT NULL,
        queueNumber INTEGER,
        bookedAt INTEGER,
        servedAt INTEGER,
        clinicAddress TEXT,
        FOREIGN KEY (patientId) REFERENCES patients (id)
      )
    ''');
  }

  // Patient operations
  static Future<void> savePatient(Patient patient) async {
    final db = await database;
    await db.insert(
      'patients',
      patient.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<Patient?> getPatient(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'patients',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Patient.fromMap(maps.first);
    }
    return null;
  }

  // Booking operations
  static Future<void> saveBooking(Booking booking) async {
    final db = await database;
    await db.insert(
      'bookings',
      booking.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> saveBookings(List<Booking> bookings) async {
    final db = await database;
    
    // Clear existing bookings for this patient first
    if (bookings.isNotEmpty) {
      await db.delete('bookings', where: 'patientId = ?', whereArgs: [bookings.first.patientId]);
    }
    
    final batch = db.batch();
    for (final booking in bookings) {
      batch.insert(
        'bookings',
        booking.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    await batch.commit();
    print('DatabaseService: Saved ${bookings.length} bookings to database');
  }

  static Future<List<Booking>> getBookingHistory(String patientId) async {
    print('DatabaseService: Getting booking history for patient $patientId');
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'bookings',
      where: 'patientId = ?',
      whereArgs: [patientId],
      orderBy: 'servedAt DESC, bookedAt DESC',
    );

    print('DatabaseService: Found ${maps.length} bookings in database');
    return List.generate(maps.length, (i) {
      return Booking.fromMap(maps[i]);
    });
  }

  static Future<void> clearPatientData(String patientId) async {
    final db = await database;
    await db.delete('bookings', where: 'patientId = ?', whereArgs: [patientId]);
    await db.delete('patients', where: 'id = ?', whereArgs: [patientId]);
  }

  static Future<void> clearAllData() async {
    final db = await database;
    await db.delete('bookings');
    await db.delete('patients');
  }


}