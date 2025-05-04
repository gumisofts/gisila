import 'package:pg_dorm/pg_dorm.dart';
part 'schema.db.g.dart';
part 'schema.query.g.dart';

class User {
  String get firstName => _firstName;
  set firstName(String firstName) => _firstName = firstName;
  late String _firstName;

  String? get lastName => _lastName;
  set lastName(String? lastName) => _lastName = lastName;
  late String? _lastName;

  String get email => _email;
  set email(String email) => _email = email;
  late String _email;

  String get password => _password;
  set password(String password) => _password = password;
  late String _password;

  DateTime get dateJoined => _dateJoined;
  set dateJoined(DateTime dateJoined) => _dateJoined = dateJoined;
  late DateTime _dateJoined;

  User({
    required String firstName,
    String? lastName,
    required String email,
    required String password,
    required DateTime dateJoined,
  }) {
    _firstName = firstName;
    _lastName = lastName;
    _email = email;
    _password = password;
    _dateJoined = dateJoined;
    Future<void> save() async {}
    Future<void> delete() => UserDb.delete(this);
  }
}

class Author {
  String get firstName => _firstName;
  set firstName(String firstName) => _firstName = firstName;
  late String _firstName;

  String? get lastName => _lastName;
  set lastName(String? lastName) => _lastName = lastName;
  late String? _lastName;

  String get email => _email;
  set email(String email) => _email = email;
  late String _email;

  Author({
    required String firstName,
    String? lastName,
    required String email,
  }) {
    _firstName = firstName;
    _lastName = lastName;
    _email = email;
    Future<void> save() async {}
    Future<void> delete() => AuthorDb.delete(this);
  }
}

class Book {
  String get title => _title;
  set title(String title) => _title = title;
  late String _title;

  String? get subtitle => _subtitle;
  set subtitle(String? subtitle) => _subtitle = subtitle;
  late String? _subtitle;

  String? get description => _description;
  set description(String? description) => _description = description;
  late String? _description;

  DateTime? get publishedDate => _publishedDate;
  set publishedDate(DateTime? publishedDate) => _publishedDate = publishedDate;
  late DateTime? _publishedDate;

  String? get isbn => _isbn;
  set isbn(String? isbn) => _isbn = isbn;
  late String? _isbn;

  int? get pageCount => _pageCount;
  set pageCount(int? pageCount) => _pageCount = pageCount;
  late int? _pageCount;

  Author get author => _author;
  late Author _author;
  set author(Author author) => _author = author;

  late Iterator<User>? _reviewers;

  Iterator<User>? get reviewers => _reviewers;
  set reviewers(Iterator<User>? reviewers) => _reviewers = reviewers;

  Book({
    required String title,
    String? subtitle,
    String? description,
    DateTime? publishedDate,
    String? isbn,
    int? pageCount,
    required Author author,
    Iterator<User>? reviewers,
  }) {
    _title = title;
    _subtitle = subtitle;
    _description = description;
    _publishedDate = publishedDate;
    _isbn = isbn;
    _pageCount = pageCount;
    _author = author;
    _reviewers = reviewers;
    Future<void> save() async {}
    Future<void> delete() => BookDb.delete(this);
  }
}

class Review {
  Book get book => _book;
  late Book _book;
  set book(Book book) => _book = book;

  User get reviewer => _reviewer;
  late User _reviewer;
  set reviewer(User reviewer) => _reviewer = reviewer;

  int get rating => _rating;
  set rating(int rating) => _rating = rating;
  late int _rating;

  String? get reviewText => _reviewText;
  set reviewText(String? reviewText) => _reviewText = reviewText;
  late String? _reviewText;

  DateTime get reviewDate => _reviewDate;
  set reviewDate(DateTime reviewDate) => _reviewDate = reviewDate;
  late DateTime _reviewDate;

  bool get isApproved => _isApproved;
  set isApproved(bool isApproved) => _isApproved = isApproved;
  late bool _isApproved;

  bool get isFlagged => _isFlagged;
  set isFlagged(bool isFlagged) => _isFlagged = isFlagged;
  late bool _isFlagged;

  bool get isDeleted => _isDeleted;
  set isDeleted(bool isDeleted) => _isDeleted = isDeleted;
  late bool _isDeleted;

  bool get isSpam => _isSpam;
  set isSpam(bool isSpam) => _isSpam = isSpam;
  late bool _isSpam;

  bool get isInappropriate => _isInappropriate;
  set isInappropriate(bool isInappropriate) =>
      _isInappropriate = isInappropriate;
  late bool _isInappropriate;

  bool get isHarmful => _isHarmful;
  set isHarmful(bool isHarmful) => _isHarmful = isHarmful;
  late bool _isHarmful;

  Review({
    required Book book,
    required User reviewer,
    required int rating,
    String? reviewText,
    required DateTime reviewDate,
    required bool isApproved,
    required bool isFlagged,
    required bool isDeleted,
    required bool isSpam,
    required bool isInappropriate,
    required bool isHarmful,
  }) {
    _book = book;
    _reviewer = reviewer;
    _rating = rating;
    _reviewText = reviewText;
    _reviewDate = reviewDate;
    _isApproved = isApproved;
    _isFlagged = isFlagged;
    _isDeleted = isDeleted;
    _isSpam = isSpam;
    _isInappropriate = isInappropriate;
    _isHarmful = isHarmful;
    Future<void> save() async {}
    Future<void> delete() => ReviewDb.delete(this);
  }
}
