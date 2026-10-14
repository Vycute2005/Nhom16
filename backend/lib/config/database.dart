import 'package:dotenv/dotenv.dart';
import 'package:mysql_client/mysql_client.dart';

class Database {
  static Future<MySQLConnection> connect() async {
    final dotenv = DotEnv()..load();

    final db = await MySQLConnection.createConnection(
      host: dotenv['DB_HOST'] ?? 'localhost',
      port: int.parse(dotenv['DB_PORT'] ?? '3306'),
      userName: dotenv['DB_USERNAME'] ?? '',
      password: dotenv['DB_PASSWORD'] ?? '',
      databaseName: dotenv['DB_DATABASE'] ?? '',
      secure: false,
    );

    await db.connect();

    print('Connected to MariaDB!');

    return db;
  }
}