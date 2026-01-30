class Bookmark {
  final String id;        // uuid or timestamp string
  final String bookPath;  // epubPath used as book identifier
  final int chapterIndex; // index of chapter in our flattened chapters list (approx)
  final double offset;    // scroll offset in pixels
  final String note;      // optional user note / title
  final int createdAt;    // unix ms

  Bookmark({
    required this.id,
    required this.bookPath,
    required this.chapterIndex,
    required this.offset,
    required this.note,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'bookPath': bookPath,
        'chapterIndex': chapterIndex,
        'offset': offset,
        'note': note,
        'createdAt': createdAt,
      };

  factory Bookmark.fromJson(Map<String, dynamic> json) => Bookmark(
        id: json['id'],
        bookPath: json['bookPath'],
        chapterIndex: json['chapterIndex'],
        offset: (json['offset'] as num).toDouble(),
        note: json['note'],
        createdAt: json['createdAt'],
      );
}
