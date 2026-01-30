import 'dart:convert';
import 'package:crypto/crypto.dart';

class User {
  final int? id;
  final String name;
  final String email;
  final String passwordHash;
  final DateTime createdAt;

  final String securityQuestion;
  final String securityAnswer;

  User({
    this.id,
    required this.name,
    required this.email,
    required this.passwordHash,
    required this.createdAt,
    required this.securityQuestion,
    required this.securityAnswer,
  });

  // Convert a User into a Map. The keys must correspond to the names of the
  // columns in the database.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'password_hash': passwordHash,
      'created_at': createdAt.toIso8601String(),
      'security_question': securityQuestion,
      'security_answer': securityAnswer,
    };
  }

  // Implement toString to make it easier to see information about
  // each user when using the print statement.
  @override
  String toString() {
    return 'User{id: $id, name: $name, email: $email, createdAt: $createdAt}';
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      name: map['name'],
      email: map['email'],
      passwordHash: map['password_hash'],
      createdAt: DateTime.parse(map['created_at']),
      securityQuestion: map['security_question'] ?? '',
      securityAnswer: map['security_answer'] ?? '',
    );
  }

  static String hashPassword(String password) {
    var bytes = utf8.encode(password); // data being hashed
    var digest = sha256.convert(bytes);
    return digest.toString();
  }
}
