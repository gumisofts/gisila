part of 'schema.dart';

class UserDb {
  static String table = "user";
  static Future<User> create({
    required String firstName,
    String? lastName,
    required String email,
    required String password,
    required DateTime dateJoined,
  }) async {
    final columns = <String, dynamic>{
      "firstName": firstName,
      "lastName": lastName,
      "email": email,
      "password": password,
      "dateJoined": dateJoined,
    };
    final query = Query.insert(table: table, columns: columns);
    return User(
        firstName: firstName,
        lastName: lastName,
        email: email,
        password: password,
        dateJoined: dateJoined);
  }

  static Future<void> delete(User user) async {}
}

class AuthorDb {
  static String table = "author";
  static Future<Author> create({
    required String firstName,
    String? lastName,
    required String email,
  }) async {
    final columns = <String, dynamic>{
      "firstName": firstName,
      "lastName": lastName,
      "email": email,
    };
    final query = Query.insert(table: table, columns: columns);
    return Author(firstName: firstName, lastName: lastName, email: email);
  }

  static Future<void> delete(Author author) async {}
}

class BookDb {
  static String table = "book";
  static Future<Book> create({
    required String title,
    String? subtitle,
    String? description,
    DateTime? publishedDate,
    String? isbn,
    int? pageCount,
    required Author author,
    Iterator<User>? reviewers,
  }) async {
    final columns = <String, dynamic>{
      "title": title,
      "subtitle": subtitle,
      "description": description,
      "publishedDate": publishedDate,
      "isbn": isbn,
      "pageCount": pageCount,
      "author": author,
      "reviewers": reviewers,
    };
    final query = Query.insert(table: table, columns: columns);
    return Book(
        title: title,
        subtitle: subtitle,
        description: description,
        publishedDate: publishedDate,
        isbn: isbn,
        pageCount: pageCount,
        author: author,
        reviewers: reviewers);
  }

  static Future<void> delete(Book book) async {}
}

class ReviewDb {
  static String table = "review";
  static Future<Review> create({
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
  }) async {
    final columns = <String, dynamic>{
      "book": book,
      "reviewer": reviewer,
      "rating": rating,
      "reviewText": reviewText,
      "reviewDate": reviewDate,
      "isApproved": isApproved,
      "isFlagged": isFlagged,
      "isDeleted": isDeleted,
      "isSpam": isSpam,
      "isInappropriate": isInappropriate,
      "isHarmful": isHarmful,
    };
    final query = Query.insert(table: table, columns: columns);
    return Review(
        book: book,
        reviewer: reviewer,
        rating: rating,
        reviewText: reviewText,
        reviewDate: reviewDate,
        isApproved: isApproved,
        isFlagged: isFlagged,
        isDeleted: isDeleted,
        isSpam: isSpam,
        isInappropriate: isInappropriate,
        isHarmful: isHarmful);
  }

  static Future<void> delete(Review review) async {}
}
