import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import '../models/user_account.dart';
import 'local_database.dart';

abstract class AuthService {
  Future<UserAccount> login({required String email, required String password});
  Future<UserAccount> register({required String name, required String email, required String password});
  Future<void> resetPassword({required String email, required String newPassword});
}

class LocalAuthService implements AuthService {
  LocalAuthService(this.database);

  final LocalDatabase database;

  @override
  Future<UserAccount> register({required String name, required String email, required String password}) async {
    final normalizedName = name.trim();
    final normalizedEmail = email.trim().toLowerCase();
    _validate(normalizedName, normalizedEmail, password);

    final salt = _newSalt();
    final hash = _hash(password, salt);
    try {
      final id = await database.db.insert('users', {
        'name': normalizedName,
        'email': normalizedEmail,
        'password_hash': hash,
        'salt': salt,
        'created_at': DateTime.now().toIso8601String(),
      });
      return UserAccount(id: id, name: normalizedName, email: normalizedEmail);
    } on DatabaseException catch (error) {
      final message = error.toString().toLowerCase();
      if (message.contains('unique') || message.contains('constraint')) {
        throw const AuthException('Já existe uma conta com este e-mail.');
      }
      rethrow;
    }
  }

  @override
  Future<UserAccount> login({required String email, required String password}) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty || password.isEmpty) {
      throw const AuthException('Informe e-mail e senha.');
    }
    final rows = await database.db.query(
      'users',
      columns: ['id', 'name', 'email', 'password_hash', 'salt'],
      where: 'email = ? COLLATE NOCASE',
      whereArgs: [normalizedEmail],
      limit: 1,
    );
    if (rows.isEmpty) throw const AuthException('E-mail ou senha inválidos.');
    final row = rows.first;
    final expected = row['password_hash']?.toString() ?? '';
    final salt = row['salt']?.toString() ?? '';
    if (_hash(password, salt) != expected) {
      throw const AuthException('E-mail ou senha inválidos.');
    }
    return UserAccount(
      id: row['id'] as int,
      name: row['name'] as String,
      email: row['email'] as String,
    );
  }

  @override
  Future<void> resetPassword({required String email, required String newPassword}) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      throw const AuthException('Informe o e-mail da conta.');
    }
    if (newPassword.length < 6) {
      throw const AuthException('A nova senha deve ter pelo menos 6 caracteres.');
    }

    final rows = await database.db.query(
      'users',
      columns: ['id'],
      where: 'email = ? COLLATE NOCASE',
      whereArgs: [normalizedEmail],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const AuthException('Nenhuma conta local foi encontrada com este e-mail.');
    }

    final salt = _newSalt();
    final hash = _hash(newPassword, salt);
    await database.db.update(
      'users',
      {
        'password_hash': hash,
        'salt': salt,
      },
      where: 'id = ?',
      whereArgs: [rows.first['id']],
    );
  }

  void _validate(String name, String email, String password) {
    if (name.length < 2) throw const AuthException('Informe seu nome.');
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(email)) throw const AuthException('Informe um e-mail válido.');
    if (password.length < 6) throw const AuthException('A senha deve ter pelo menos 6 caracteres.');
  }

  String _newSalt() {
    final random = Random.secure();
    return base64UrlEncode(List<int>.generate(24, (_) => random.nextInt(256)));
  }

  String _hash(String password, String salt) {
    return sha256.convert(utf8.encode('$salt:$password')).toString();
  }
}

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}
