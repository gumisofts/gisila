part of 'schema.dart';
class UserDb{
static String table="user";
static Future<User> create({
required String firstName,
String? lastName,
required String email,
required String password,
required DateTime dateJoined,
})async{
final columns=<String,dynamic>{
"first_name":firstName,
"last_name":lastName,
"email":email,
"password":password,
"date_joined":dateJoined,
};
final query=Query.insert(table: table, columns: columns);
final result=await Database.execute(query.toString());
return User(
firstName:firstName,lastName:lastName,email:email,password:password,dateJoined:dateJoined
);
}
static Future<Iterator<User>> filter(Operation Function(UserQuery) where)async{
return Iterable<User>.empty().iterator;
}
static Future<void> delete(User user)
async{
}

}

class AuthorDb{
static String table="author";
static Future<Author> create({
required String firstName,
String? lastName,
required String email,
})async{
final columns=<String,dynamic>{
"first_name":firstName,
"last_name":lastName,
"email":email,
};
final query=Query.insert(table: table, columns: columns);
final result=await Database.execute(query.toString());
return Author(
firstName:firstName,lastName:lastName,email:email
);
}
static Future<Iterator<Author>> filter(Operation Function(AuthorQuery) where)async{
return Iterable<Author>.empty().iterator;
}
static Future<void> delete(Author author)
async{
}

}

class BookDb{
static String table="book";
static Future<Book> create({
required String title,
String? subtitle,
String? description,
DateTime? publishedDate,
String? isbn,
int? pageCount,
required String authorId,
})async{
final columns=<String,dynamic>{
"title":title,
"subtitle":subtitle,
"description":description,
"published_date":publishedDate,
"isbn":isbn,
"page_count":pageCount,
"authorId":authorId,
};
final query=Query.insert(table: table, columns: columns);
final result=await Database.execute(query.toString());
return Book(
title:title,subtitle:subtitle,description:description,publishedDate:publishedDate,isbn:isbn,pageCount:pageCount,authorId:authorId
);
}
static Future<Iterator<Book>> filter(Operation Function(BookQuery) where)async{
return Iterable<Book>.empty().iterator;
}
static Future<void> delete(Book book)
async{
}

}

class ReviewDb{
static String table="review";
static Future<Review> create({
required String bookId,
required String reviewerId,
required int rating,
String? reviewText,
required DateTime reviewDate,
required bool isApproved,
required bool isFlagged,
required bool isDeleted,
required bool isSpam,
required bool isInappropriate,
required bool isHarmful,
})async{
final columns=<String,dynamic>{
"bookId":bookId,
"reviewerId":reviewerId,
"rating":rating,
"review_text":reviewText,
"review_date":reviewDate,
"is_approved":isApproved,
"is_flagged":isFlagged,
"is_deleted":isDeleted,
"is_spam":isSpam,
"is_inappropriate":isInappropriate,
"is_harmful":isHarmful,
};
final query=Query.insert(table: table, columns: columns);
final result=await Database.execute(query.toString());
return Review(
bookId:bookId,reviewerId:reviewerId,rating:rating,reviewText:reviewText,reviewDate:reviewDate,isApproved:isApproved,isFlagged:isFlagged,isDeleted:isDeleted,isSpam:isSpam,isInappropriate:isInappropriate,isHarmful:isHarmful
);
}
static Future<Iterator<Review>> filter(Operation Function(ReviewQuery) where)async{
return Iterable<Review>.empty().iterator;
}
static Future<void> delete(Review review)
async{
}

}

