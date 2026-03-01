import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'farmacia_casa.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Tabela de Tratamentos (Medicamentos)
    await db.execute('''
      CREATE TABLE tratamentos (
        id TEXT PRIMARY KEY,
        nome TEXT NOT NULL,
        isAntibiotico INTEGER,
        isFormulado INTEGER,
        uso TEXT,
        usoContinuo INTEGER,
        frequencia TEXT,
        modoUso TEXT,
        dataInicial TEXT,
        dataFinal TEXT,
        infoAdicional TEXT,
        userId TEXT,
        sincronizado INTEGER DEFAULT 0
      )
    ''');

    // Tabela de Doses (Histórico e próximos alarmes)
    await db.execute('''
      CREATE TABLE doses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tratamentoId TEXT,
        medicamentoNome TEXT,
        dataHora TEXT NOT NULL,
        tomado INTEGER DEFAULT 0,
        sincronizado INTEGER DEFAULT 0,
        FOREIGN KEY (tratamentoId) REFERENCES tratamentos (id) ON DELETE CASCADE
      )
    ''');
  }

  // Métodos CRUD básicos
  Future<void> inserirTratamento(Map<String, dynamic> row) async {
    Database db = await database;
    await db.insert('tratamentos', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> inserirDose(Map<String, dynamic> row) async {
    Database db = await database;
    await db.insert('doses', row);
  }

  Future<List<Map<String, dynamic>>> getTratamentosNaoSincronizados() async {
    Database db = await database;
    return await db.query('tratamentos', where: 'sincronizado = 0');
  }

  Future<void> marcarComoSincronizado(String table, String id) async {
    Database db = await database;
    await db.update(table, {'sincronizado': 1}, where: 'id = ?', whereArgs: [id]);
  }
}
