part of 'schema.dart';
class UserQuery{
UserQuery();
factory UserQuery.referenced({required List<Join> joins})=>UserQuery().._joins.addAll(joins);
static const table='User';
TextColumn get id => TextColumn(column:'id',offtable:'User',depends:_joins);
TextColumn get firstName => TextColumn(column:"first_name",offtable:"User",depends:_joins);
TextColumn get lastName => TextColumn(column:"last_name",offtable:"User",depends:_joins);
TextColumn get email => TextColumn(column:"email",offtable:"User",depends:_joins);
TextColumn get password => TextColumn(column:"password",offtable:"User",depends:_joins);
DateTimeColumn get dateJoined => DateTimeColumn(column:"date_joined",offtable:"User",depends:_joins);
final _joins=<Join>[];
static List<String> get columns=> <String>['first_name', 'last_name', 'email', 'password', 'date_joined'];
}

class AuthorQuery{
AuthorQuery();
factory AuthorQuery.referenced({required List<Join> joins})=>AuthorQuery().._joins.addAll(joins);
static const table='Author';
TextColumn get id => TextColumn(column:'id',offtable:'Author',depends:_joins);
TextColumn get firstName => TextColumn(column:"first_name",offtable:"Author",depends:_joins);
TextColumn get lastName => TextColumn(column:"last_name",offtable:"Author",depends:_joins);
TextColumn get email => TextColumn(column:"email",offtable:"Author",depends:_joins);
final _joins=<Join>[];
static List<String> get columns=> <String>['first_name', 'last_name', 'email'];
}

class BookQuery{
BookQuery();
factory BookQuery.referenced({required List<Join> joins})=>BookQuery().._joins.addAll(joins);
static const table='Book';
TextColumn get id => TextColumn(column:'id',offtable:'Book',depends:_joins);
TextColumn get title => TextColumn(column:"title",offtable:"Book",depends:_joins);
TextColumn get subtitle => TextColumn(column:"subtitle",offtable:"Book",depends:_joins);
TextColumn get description => TextColumn(column:"description",offtable:"Book",depends:_joins);
DateTimeColumn get publishedDate => DateTimeColumn(column:"published_date",offtable:"Book",depends:_joins);
TextColumn get isbn => TextColumn(column:"isbn",offtable:"Book",depends:_joins);
NumberColumn get pageCount => NumberColumn(column:"page_count",offtable:"Book",depends:_joins);
AuthorQuery get author=> AuthorQuery.referenced(joins:[Join(table:"Author",from:"Book",onn:"book.id=Author")]);
UserQuery get reviewers=> UserQuery.referenced(joins:[Join(table:"User",from:"Book",onn:"book.id=User")]);
final _joins=<Join>[];
static List<String> get columns=> <String>['title', 'subtitle', 'description', 'published_date', 'isbn', 'page_count', 'author', 'reviewers'];
}

class ReviewQuery{
ReviewQuery();
factory ReviewQuery.referenced({required List<Join> joins})=>ReviewQuery().._joins.addAll(joins);
static const table='Review';
TextColumn get id => TextColumn(column:'id',offtable:'Review',depends:_joins);
BookQuery get book=> BookQuery.referenced(joins:[Join(table:"Book",from:"Review",onn:"review.id=Book")]);
UserQuery get reviewer=> UserQuery.referenced(joins:[Join(table:"User",from:"Review",onn:"review.id=User")]);
NumberColumn get rating => NumberColumn(column:"rating",offtable:"Review",depends:_joins);
TextColumn get reviewText => TextColumn(column:"review_text",offtable:"Review",depends:_joins);
DateTimeColumn get reviewDate => DateTimeColumn(column:"review_date",offtable:"Review",depends:_joins);
BooleanColumn get isApproved => BooleanColumn(column:"is_approved",offtable:"Review",depends:_joins);
BooleanColumn get isFlagged => BooleanColumn(column:"is_flagged",offtable:"Review",depends:_joins);
BooleanColumn get isDeleted => BooleanColumn(column:"is_deleted",offtable:"Review",depends:_joins);
BooleanColumn get isSpam => BooleanColumn(column:"is_spam",offtable:"Review",depends:_joins);
BooleanColumn get isInappropriate => BooleanColumn(column:"is_inappropriate",offtable:"Review",depends:_joins);
BooleanColumn get isHarmful => BooleanColumn(column:"is_harmful",offtable:"Review",depends:_joins);
final _joins=<Join>[];
static List<String> get columns=> <String>['book', 'reviewer', 'rating', 'review_text', 'review_date', 'is_approved', 'is_flagged', 'is_deleted', 'is_spam', 'is_inappropriate', 'is_harmful'];
}

