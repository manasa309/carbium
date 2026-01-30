class Book {
  final String id;
  final String title;
  final String author;
  final String coverPath;
  final String epubPath;

  Book({
    required this.id,
    required this.title,
    required this.author,
    required this.coverPath,
    required this.epubPath,
  });

  // Convert Book → JSON
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'author': author,
        'coverPath': coverPath,
        'epubPath': epubPath,
      };

  // Convert JSON → Book
  factory Book.fromJson(Map<String, dynamic> json) => Book(
        id: json['id'],
        title: json['title'],
        author: json['author'],
        coverPath: json['coverPath'],
        epubPath: json['epubPath'],
      );
}
