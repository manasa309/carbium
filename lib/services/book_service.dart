import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/book.dart';

class BookService {
  static const String key = 'books';

  Future<List<Book>> loadBooks(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('${key}_$userId');
    if (data == null) return [];
    final list = jsonDecode(data) as List;
    return list.map((e) => Book.fromJson(e)).toList();
  }

  Future<void> saveBooks(String userId, List<Book> books) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('${key}_$userId', jsonEncode(books.map((b) => b.toJson()).toList()));
  }
}
