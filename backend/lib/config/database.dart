import 'dart:io';
import 'package:dotenv/dotenv.dart';
import 'package:mysql1/mysql1.dart';

class DatabaseConnection {
  final MySqlConnection _connection;

  DatabaseConnection(this._connection);

  Future<DatabaseResult> execute(
    String sql, [
    Map<String, dynamic> parameters = const {},
  ]) async {
    final values = <Object?>[];
    final statement = sql.replaceAllMapped(
      RegExp(r':([A-Za-z_][A-Za-z0-9_]*)'),
      (match) {
        final name = match.group(1)!;
        if (!parameters.containsKey(name)) {
          throw ArgumentError('Missing SQL parameter: $name');
        }
        values.add(parameters[name]);
        return '?';
      },
    );
    final result = await _connection.query(
      statement,
      values.isEmpty ? null : values,
    );
    return DatabaseResult(
      result.map((row) => DatabaseRow(row.fields)).toList(),
      affectedRows: result.affectedRows ?? 0,
    );
  }

  Future<void> close() => _connection.close();
}

class DatabaseResult {
  final List<DatabaseRow> rows;
  final int affectedRows;

  const DatabaseResult(this.rows, {required this.affectedRows});
}

class DatabaseRow {
  final Map<String, dynamic> _values;

  const DatabaseRow(this._values);

  Map<String, String?> assoc() =>
      _values.map((key, value) => MapEntry(key, value?.toString()));
}

class Database {
  static Future<DatabaseConnection> connect({
    String? host,
    int? port,
    String? user,
    String? password,
    String? database,
  }) async {
    // Tải cấu hình từ .env nếu file tồn tại
    final localEnvFile = File('.env');
    final backendEnvFile = File('backend/.env');
    final envFile = await backendEnvFile.exists()
        ? backendEnvFile
        : await localEnvFile.exists()
            ? localEnvFile
            : null;
    Map<String, String> envMap = {};
    if (envFile != null) {
      final dotenv = DotEnv()..load([envFile.path]);
      for (final key in const ['DB_HOST', 'DB_PORT', 'DB_USERNAME', 'DB_PASSWORD', 'DB_DATABASE']) {
        final value = dotenv[key];
        if (value != null) envMap[key] = value;
      }
      print('Loaded MariaDB configuration from ${envFile.path}.');
    }

    // Thứ tự ưu tiên: Tham số truyền vào > File .env > VPS Mặc định (103.82.26.171:8806)
    final dbHost = host ?? envMap['DB_HOST'] ?? '103.82.26.171';
    final dbPort = port ?? int.tryParse(envMap['DB_PORT'] ?? '') ?? 8806;
    final dbUser = user ?? envMap['DB_USERNAME'] ?? 'root';
    final dbPassword = password ?? envMap['DB_PASSWORD'] ?? '';
    final dbName = database ?? envMap['DB_DATABASE'] ?? 'vietnam_travel';

    final connection = await MySqlConnection.connect(
      ConnectionSettings(
        host: dbHost,
        port: dbPort,
        user: dbUser,
        password: dbPassword.isNotEmpty ? dbPassword : null,
        db: dbName,
      ),
    );

    print('Connected to MariaDB at $dbHost:$dbPort/$dbName.');
    return DatabaseConnection(connection);
  }
}