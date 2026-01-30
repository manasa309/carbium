import 'dart:io';
import 'package:flutter/material.dart';
import 'package:epubx/epubx.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/bookmark.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../services/bookmark_service.dart';

class ReaderScreen extends StatefulWidget {
  final String epubPath;
  final String title;

  const ReaderScreen({
    super.key,
    required this.epubPath,
    required this.title,
  });

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  List<ChapterData> chapters = [];
  
  // Scroll Mode Controllers
  final ItemScrollController itemScrollController = ItemScrollController();
  final ItemPositionsListener itemPositionsListener = ItemPositionsListener.create();
  
  // Paged Mode State
  int _currentChapterIndex = 0;

  double scrollProgress = 0.0;

  final BookmarkService _bookmarkService = BookmarkService();
  List<Bookmark> _bookmarks = [];

  final TextEditingController _searchController = TextEditingController();
  bool _searchOpen = false;
  final List<_SearchResult> _searchResults = [];

  final uuid = const Uuid();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    loadEpub();
    itemPositionsListener.itemPositions.addListener(_onScroll);
  }

  @override
  void dispose() {
    itemPositionsListener.itemPositions.removeListener(_onScroll);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> loadEpub() async {
    try {
      final file = File(widget.epubPath);
      final bytes = await file.readAsBytes();

      final book = await EpubReader.readBook(bytes);

      // Flatten everything into a linear list of (Title, Content)
      chapters = (book.Chapters ?? []).expand((c) => _extractChapters(c)).toList();

      final auth = Provider.of<AuthProvider>(context, listen: false);
      final email = auth.currentUser?.email;
      if (email != null) {
        _bookmarks = await _bookmarkService.loadForBook(email, widget.epubPath);
      }
      
      setState(() {
        _isLoading = false;
      });
      
      // Restore position after a slight delay
      await Future.delayed(const Duration(milliseconds: 300));
      await _loadScrollPosition();
      
    } catch (e) {
      debugPrint("EPUB Load Error: $e");
      setState(() {
        chapters = [ChapterData(title: "Error", content: "<p>Failed to load EPUB file.</p>")];
        _isLoading = false;
      });
    }
  }

  List<ChapterData> _extractChapters(EpubChapter c) {
    List<ChapterData> result = [];
    if (c.HtmlContent != null && c.HtmlContent!.trim().isNotEmpty) {
      result.add(ChapterData(title: c.Title ?? "Untitled", content: c.HtmlContent!));
    }
    if (c.SubChapters != null) {
      for (var sub in c.SubChapters!) {
        result.addAll(_extractChapters(sub));
      }
    }
    return result;
  }

  void _onScroll() {
    final positions = itemPositionsListener.itemPositions.value;
    if (positions.isEmpty || chapters.isEmpty) return;

    final first = positions.first;
    final index = first.index;
    
    // Only update if changed significantly to avoid spamming prefs
    if (index != _currentChapterIndex) {
      _currentChapterIndex = index;
      _saveScrollPosition(index);
    }

    final progress = index / (chapters.length - 1);
    if (progress != scrollProgress) {
      setState(() {
        scrollProgress = progress.clamp(0.0, 1.0);
      });
    }
  }

  Future<void> _saveScrollPosition(int index) async {
    _currentChapterIndex = index;
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('${widget.epubPath}_chapter_index', index);
  }

  Future<void> _loadScrollPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt('${widget.epubPath}_chapter_index') ?? 0;
    _currentChapterIndex = index;
    
    if (index >= 0 && index < chapters.length) {
      // If in scroll mode, jump
      if (itemScrollController.isAttached) {
        itemScrollController.jumpTo(index: index);
      }
      
      setState(() {
        scrollProgress = index / (chapters.length - 1);
      });
    }
  }

  Future<void> addBookmark({String note = ''}) async {
    // Use current index regardless of mode
    final index = _currentChapterIndex;

    final bm = Bookmark(
      id: uuid.v4(),
      bookPath: widget.epubPath,
      chapterIndex: index,
      offset: 0.0,
      note: note,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final email = auth.currentUser?.email;
    if (email == null) return;

    await _bookmarkService.saveBookmark(email, bm);
    _bookmarks = await _bookmarkService.loadForBook(email, widget.epubPath);
    setState(() {});
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bookmark saved")));
    }
  }
  
  Future<void> deleteBookmark(String id) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final email = auth.currentUser?.email;
    if (email == null) return;

    await _bookmarkService.deleteBookmark(email, widget.epubPath, id);
    _bookmarks = await _bookmarkService.loadForBook(email, widget.epubPath);
    setState(() {});
  }

  Future<void> _jumpToChapter(int index) async {
    if (index >= 0 && index < chapters.length) {
      _currentChapterIndex = index;
      _saveScrollPosition(index);
      
      // If scroll mode
      if (itemScrollController.isAttached) {
        itemScrollController.jumpTo(index: index);
      }
      // If paged mode, we need to force rebuild or use controller if we had one.
      // Since we use PageView.builder with a fresh controller in build, setState might work if we pass initialPage
      setState(() {});
    }
  }

  void _openSearch() {
    setState(() {
      _searchOpen = true;
      _searchResults.clear();
      _searchController.clear();
    });
  }

  void _closeSearch() {
    setState(() {
      _searchOpen = false;
      _searchResults.clear();
      _searchController.clear();
    });
  }

  void _performSearch(String query) {
    _searchResults.clear();
    if (query.trim().isEmpty) {
      setState(() {});
      return;
    }
    final q = query.toLowerCase();
    for (int i = 0; i < chapters.length; i++) {
      final text = chapters[i].content.toLowerCase();
      final idx = text.indexOf(q);
      if (idx >= 0) {
        final snippet = chapters[i].content.substring(
          idx,
          (idx + 100).clamp(0, chapters[i].content.length),
        );
        _searchResults.add(_SearchResult(chapterIndex: i, snippet: snippet, query: query));
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    
    // Sepia Colors
    const sepiaBg = Color(0xFFF4ECD8);
    const sepiaText = Color(0xFF5B4636);
    
    final bgColor = settings.isSepia ? sepiaBg : Theme.of(context).scaffoldBackgroundColor;
    final textColor = settings.isSepia ? sepiaText : Theme.of(context).textTheme.bodyMedium?.color;
    
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(widget.title, style: TextStyle(color: settings.isSepia ? Colors.brown : null)),
        backgroundColor: settings.isSepia ? sepiaBg : null,
        iconTheme: IconThemeData(color: settings.isSepia ? Colors.brown : null),
        elevation: settings.isSepia ? 0 : null,
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: _openSearch),
          IconButton(
            icon: const Icon(Icons.bookmark_add),
            onPressed: () async {
              final note = await _askForNote();
              await addBookmark(note: note ?? "");
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsSheet(context),
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            Container(
              color: bgColor,
              child: settings.readerMode == ReaderMode.scroll
                  ? ScrollablePositionedList.builder(
                      itemCount: chapters.length,
                      itemScrollController: itemScrollController,
                      itemPositionsListener: itemPositionsListener,
                      padding: const EdgeInsets.all(16),
                      itemBuilder: (context, index) => _buildChapterHtml(index, settings, textColor),
                    )
                  : PageView.builder(
                      // Key forces rebuild when mode changes or chapter jumps
                      key: ValueKey("paged_$_currentChapterIndex"),
                      controller: PageController(initialPage: _currentChapterIndex),
                      itemCount: chapters.length,
                      onPageChanged: (index) {
                         _currentChapterIndex = index;
                         setState(() {
                           scrollProgress = index / (chapters.length - 1);
                         });
                         _saveScrollPosition(index);
                      },
                      itemBuilder: (context, index) {
                        return SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: _buildChapterHtml(index, settings, textColor),
                        );
                      },
                    ),
            ),
          if (_searchOpen) _buildSearchOverlay(),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(settings.isSepia),
    );
  }

  Widget _buildChapterHtml(int index, SettingsProvider settings, Color? textColor) {
    return Html(
      data: chapters[index].content,
      style: {
        "body": Style(
          fontSize: FontSize(settings.fontSize),
          fontFamily: settings.fontFamily == 'Default' ? null : settings.fontFamily,
          lineHeight: LineHeight.em(1.6),
          color: textColor,
          padding: HtmlPaddings.only(bottom: 32),
        ),
      },
    );
  }

  Widget _buildBottomBar(bool isSepia) {
    return SizedBox(
      height: 48,
      child: Column(
        children: [
          LinearProgressIndicator(
            value: scrollProgress,
            color: isSepia ? Colors.brown : Theme.of(context).primaryColor,
            backgroundColor: isSepia ? Colors.brown.withOpacity(0.2) : Colors.grey.withOpacity(0.3),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(scrollProgress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(color: isSepia ? Colors.brown : null),
                ),
                IconButton(
                  icon: Icon(Icons.bookmark, color: isSepia ? Colors.brown : null),
                  onPressed: _showBookmarksSheet,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            const ListTile(
              title: Text("Table of Contents", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: chapters.length,
                itemBuilder: (_, i) {
                  final c = chapters[i];
                  final isSelected = i == _currentChapterIndex;
                  return ListTile(
                    title: Text(
                      c.title,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Theme.of(context).primaryColor : null,
                      ),
                    ),
                    selected: isSelected,
                    onTap: () {
                      Navigator.pop(context);
                      _jumpToChapter(i); 
                    },
                  );
                },
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.bookmark),
              title: const Text("Bookmarks"),
              onTap: _showBookmarksSheet,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchOverlay() {
    return Positioned(
      left: 12, right: 12, top: 12,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(hintText: "Search in book"),
                      onSubmitted: _performSearch,
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.search), onPressed: () => _performSearch(_searchController.text)),
                  IconButton(icon: const Icon(Icons.close), onPressed: _closeSearch),
                ],
              ),
              if (_searchResults.isNotEmpty)
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (_, i) {
                      final r = _searchResults[i];
                      return ListTile(
                        title: Text(chapters[r.chapterIndex].title),
                        subtitle: Text(r.snippet, maxLines: 2, overflow: TextOverflow.ellipsis),
                        onTap: () {
                          _closeSearch();
                          _jumpToChapter(r.chapterIndex);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBookmarksSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: StatefulBuilder(
          builder: (context, setSheetState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ListTile(title: Text("Bookmarks", style: TextStyle(fontWeight: FontWeight.bold))),
                if (_bookmarks.isEmpty) const ListTile(title: Text("No bookmarks yet")),
                if (_bookmarks.isNotEmpty)
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _bookmarks.length,
                      itemBuilder: (ctx, i) {
                        final b = _bookmarks[i];
                        // Safe title lookup
                        String chapterTitle = "Unknown Chapter";
                        if (b.chapterIndex >= 0 && b.chapterIndex < chapters.length) {
                          chapterTitle = chapters[b.chapterIndex].title;
                        }

                        return ListTile(
                          title: Text(b.note.isEmpty ? "Bookmark" : b.note),
                          subtitle: Text(chapterTitle),
                          onTap: () {
                            Navigator.pop(context);
                            _jumpToChapter(b.chapterIndex);
                          },
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              await deleteBookmark(b.id);
                              setSheetState(() {}); // Refresh the sheet
                            },
                          ),
                        );
                      },
                    ),
                  ),
              ],
            );
          }
        ),
      ),
    );
  }

  Future<String?> _askForNote() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Bookmark note"),
        content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: "Add note (optional)")),
        actions: [
          TextButton(child: const Text("Cancel"), onPressed: () => Navigator.pop(context)),
          TextButton(child: const Text("Save"), onPressed: () => Navigator.pop(context, ctrl.text.trim())),
        ],
      ),
    );
  }

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Consumer<SettingsProvider>(
        builder: (context, settings, _) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Appearance", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              
              // Reader Mode Toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Paged View (Swipe)"),
                  Switch(
                    value: settings.readerMode == ReaderMode.paged,
                    onChanged: (val) {
                      settings.setReaderMode(val ? ReaderMode.paged : ReaderMode.scroll);
                      setState(() {});
                    },
                  ),
                ],
              ),
              const Divider(),

              const Text("Theme"),
              Row(
                children: [
                  _themeButton(context, "System", ThemeMode.system, settings),
                  _themeButton(context, "Light", ThemeMode.light, settings),
                  _themeButton(context, "Dark", ThemeMode.dark, settings),
                ],
              ),
              const SizedBox(height: 8),
              // Sepia Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: settings.isSepia ? const Color(0xFFF4ECD8) : null,
                    side: BorderSide(color: settings.isSepia ? Colors.brown : Colors.grey),
                  ),
                  onPressed: () => settings.setSepia(!settings.isSepia),
                  child: Text("Sepia Mode", style: TextStyle(color: settings.isSepia ? Colors.brown : null)),
                ),
              ),
              
              const SizedBox(height: 16),
              const Text("Font Size"),
              Slider(
                value: settings.fontSize,
                min: 12,
                max: 32,
                divisions: 10,
                label: settings.fontSize.round().toString(),
                onChanged: (v) => settings.setFontSize(v),
              ),
              const SizedBox(height: 16),
              const Text("Font Family"),
              DropdownButton<String>(
                value: settings.fontFamily,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'Default', child: Text("Default")),
                  DropdownMenuItem(value: 'Serif', child: Text("Serif")),
                  DropdownMenuItem(value: 'Monospace', child: Text("Monospace")),
                ],
                onChanged: (v) {
                  if (v != null) settings.setFontFamily(v);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _themeButton(BuildContext context, String label, ThemeMode mode, SettingsProvider settings) {
    final isSelected = settings.themeMode == mode;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            backgroundColor: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : null,
            side: BorderSide(color: isSelected ? Theme.of(context).primaryColor : Colors.grey),
          ),
          onPressed: () => settings.setThemeMode(mode),
          child: Text(label),
        ),
      ),
    );
  }
}

class ChapterData {
  final String title;
  final String content;
  ChapterData({required this.title, required this.content});
}

class _SearchResult {
  final int chapterIndex;
  final String snippet;
  final String query;
  _SearchResult({required this.chapterIndex, required this.snippet, required this.query});
}
