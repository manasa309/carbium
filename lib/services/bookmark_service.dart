import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bookmark.dart';

class BookmarkService {
  Future<List<Bookmark>> loadForBook(String userId, String bookPath) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(userId, bookPath));
    if (raw == null) return [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map((m) => Bookmark.fromJson(m)).toList();
  }

  Future<void> saveBookmark(String userId, Bookmark bookmark) async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarks = await loadForBook(userId, bookmark.bookPath);
    
    // Remove existing bookmark with the same ID if it exists (update)
    bookmarks.removeWhere((b) => b.id == bookmark.id);
    bookmarks.add(bookmark);
    
    final List<Map<String, dynamic>> jsonList = bookmarks.map((b) => b.toJson()).toList();
    await prefs.setString(_key(userId, bookmark.bookPath), jsonEncode(jsonList));
  }

  Future<void> deleteBookmark(String userId, String bookPath, String bookmarkId) async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarks = await loadForBook(userId, bookPath);
    
    bookmarks.removeWhere((b) => b.id == bookmarkId);
    
    final List<Map<String, dynamic>> jsonList = bookmarks.map((b) => b.toJson()).toList();
    await prefs.setString(_key(userId, bookPath), jsonEncode(jsonList));
  }

  String _key(String userId, String path) => 'bookmarks_${userId}_$path';
}
