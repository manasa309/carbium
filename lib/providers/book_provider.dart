import 'dart:io';
import 'package:flutter/foundation.dart';
import 'auth_provider.dart';

import '../models/book.dart';
import '../services/book_service.dart';
import '../services/import_service.dart';

class BookProvider extends ChangeNotifier {
  final BookService _storage = BookService();
  final ImportService _importer = ImportService();
  
  List<Book> _books = [];
  List<Book> get books => _books;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _userId;

  void update(AuthProvider auth) {
    if (auth.currentUser?.email != _userId) {
      _userId = auth.currentUser?.email;
      _books = [];
      if (_userId != null) {
        loadBooks();
      } else {
        notifyListeners();
      }
    }
  }

  Future<void> loadBooks() async {
    if (_userId == null) return;
    
    _isLoading = true;
    notifyListeners();
    
    try {
      _books = await _storage.loadBooks(_userId!);
    } catch (e) {
      debugPrint("Error loading books: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> importBook() async {
    if (_userId == null) return;

    try {
      final newBook = await _importer.pickAndImport();
      if (newBook != null) {
        _books.add(newBook);
        await _storage.saveBooks(_userId!, _books);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error importing book: $e");
    }
  }

  Future<void> deleteBook(String id) async {
    if (_userId == null) return;

    final book = _books.firstWhere((b) => b.id == id);
    _books.removeWhere((b) => b.id == id);
    await _storage.saveBooks(_userId!, _books);
    
    // Attempt to delete file if it exists locally
    if (book.epubPath.isNotEmpty && !kIsWeb) {
      try {
        final file = File(book.epubPath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint("Error deleting file: $e");
      }
    }
    
    notifyListeners();
  }
}
