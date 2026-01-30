import 'dart:io' show File;
import 'package:epubx/epubx.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:uuid/uuid.dart';

import '../models/book.dart';

class ImportService {
  final uuid = const Uuid();

  Future<Book?> pickAndImport() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['epub'],
      withData: true, // IMPORTANT for web
    );

    if (result == null) return null;

    // On Web → bytes only
    if (kIsWeb) {
      final bytes = result.files.single.bytes;
      if (bytes == null) return null;

      final epub = await EpubReader.readBook(bytes);

      final title = epub.Title ?? 'Untitled';
      final author = epub.Author ?? 'Unknown';

      // No local file saving on web
      return Book(
        id: uuid.v4(),
        title: title,
        author: author,
        coverPath: '',
        epubPath: 'web', // placeholder
      );
    }

    // On ANDROID/WINDOWS → file path works normally
    final path = result.files.single.path;
    if (path == null) return null;

    final epubFile = File(path);
    final bytes = await epubFile.readAsBytes();

    final epub = await EpubReader.readBook(bytes);

    final title = epub.Title ?? 'Untitled';
    final author = epub.Author ?? 'Unknown';

    // Local storage for device
    final appDir = await getApplicationDocumentsDirectory();
    final id = uuid.v4();
    final newPath = '${appDir.path}/$id.epub';

    await epubFile.copy(newPath);

    // Extract Cover
    String coverPath = '';
    try {
      EpubByteContentFile? coverImage;

      // 1. Try finding in images (more reliable type-wise)
      if (epub.Content?.Images != null) {
        final images = epub.Content!.Images!;
        
        // Try to find a file that looks like a cover
        final coverKey = images.keys.firstWhere(
          (k) => k.toLowerCase().contains('cover'),
          orElse: () => '',
        );
        
        if (coverKey.isNotEmpty) {
          coverImage = images[coverKey];
        } else if (images.isNotEmpty) {
             // Fallback: if only one image, might be cover? Or first image?
             // Let's be conservative and only take if it says 'cover' or 'title'
             // or maybe just take the largest image?
             // For now, strict 'cover' check is safer to avoid random images.
        }
      }

      if (coverImage != null) {
        final coverFile = File('${appDir.path}/$id.jpg');
        await coverFile.writeAsBytes(coverImage.Content!);
        coverPath = coverFile.path;
      }
    } catch (e) {
      debugPrint("Error extracting cover: $e");
    }

    return Book(
      id: id,
      title: title,
      author: author,
      coverPath: coverPath,
      epubPath: newPath,
    );
  }
}
