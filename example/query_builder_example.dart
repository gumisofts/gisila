/// Query Builder Example for Gisila ORM
/// Demonstrates type-safe WHERE clause generation

import 'generated/models/models.dart';

void main() async {
  print('🔍 Query Builder Examples for Gisila ORM\n');

  await _basicQueryExamples();
  await _comparisonExamples();
  await _textSearchExamples();
  await _combinedQueryExamples();
  await _relationshipQueryExamples();
}

/// Basic query examples
Future<void> _basicQueryExamples() async {
  print('📝 Basic Query Examples:');

  // Instead of: User.findAll(where: 'email = ?', parameters: ['john@example.com'])
  print('✅ Type-safe email query:');
  try {
    final users =
        await User.where(User.query().email.equals('john@example.com'));
    print('   Found ${users.length} users');
  } catch (e) {
    print(
        '   Would execute: SELECT * FROM user WHERE "user"."email" = \'john@example.com\'');
  }

  // Instead of: User.findAll(where: 'id > ?', parameters: [10])
  print('✅ Type-safe ID comparison:');
  try {
    final users = await User.where(User.query().id >= '10');
    print('   Found ${users.length} users');
  } catch (e) {
    print('   Would execute: SELECT * FROM user WHERE "user"."id" >= 10');
  }

  print('');
}

/// Comparison operator examples
Future<void> _comparisonExamples() async {
  print('⚖️  Comparison Operator Examples:');

  // Greater than
  print('✅ Greater than query:');
  try {
    final users = await User.where(User.query().id > '5');
  } catch (e) {
    print('   Would execute: SELECT * FROM user WHERE "user"."id" > 5');
  }

  // Less than or equal
  print('✅ Less than or equal query:');
  try {
    final users = await User.where(User.query().id <= '100');
  } catch (e) {
    print('   Would execute: SELECT * FROM user WHERE "user"."id" <= 100');
  }

  // Not equals
  print('✅ Not equals query:');
  try {
    final users =
        await User.where(User.query().email.notEquals('admin@example.com'));
  } catch (e) {
    print(
        '   Would execute: SELECT * FROM user WHERE "user"."email" != admin@example.com');
  }

  // In list
  print('✅ IN query:');
  try {
    final users = await User.where(
        User.query().email.inn(['john@example.com', 'jane@example.com']));
  } catch (e) {
    print(
        '   Would execute: SELECT * FROM user WHERE "user"."email" in [john@example.com, jane@example.com]');
  }

  print('');
}

/// Text search examples
Future<void> _textSearchExamples() async {
  print('🔤 Text Search Examples:');

  // LIKE search
  print('✅ LIKE search:');
  try {
    final users = await User.where(User.query().first_name.like('John%'));
  } catch (e) {
    print(
        '   Would execute: SELECT * FROM user WHERE "user"."first_name" like John%');
  }

  // Case-insensitive LIKE search
  print('✅ ILIKE search:');
  try {
    final users = await User.where(User.query().email.ilike('%gmail.com'));
  } catch (e) {
    print(
        '   Would execute: SELECT * FROM user WHERE "user"."email" ilike %gmail.com');
  }

  // Contains
  print('✅ Contains search:');
  try {
    final users = await User.where(User.query().first_name.contains('oh'));
  } catch (e) {
    print(
        '   Would execute: SELECT * FROM user WHERE "user"."first_name" like oh');
  }

  print('');
}

/// Combined query examples with AND/OR
Future<void> _combinedQueryExamples() async {
  print('🔗 Combined Query Examples:');

  // AND conditions
  print('✅ AND condition:');
  try {
    final users = await User.where(User.query().first_name.equals('John') &
        User.query().email.ilike('%gmail.com'));
  } catch (e) {
    print(
        '   Would execute: SELECT * FROM user WHERE ("user"."first_name" = \'John\') and ("user"."email" ilike %gmail.com)');
  }

  // OR conditions
  print('✅ OR condition:');
  try {
    final users = await User.where(User.query().first_name.equals('John') |
        User.query().first_name.equals('Jane'));
  } catch (e) {
    print(
        '   Would execute: SELECT * FROM user WHERE ("user"."first_name" = \'John\') or ("user"."first_name" = \'Jane\')');
  }

  // NOT condition
  print('✅ NOT condition:');
  try {
    final users = await User.where(~User.query().email.ilike('%spam%'));
  } catch (e) {
    print(
        '   Would execute: SELECT * FROM user WHERE not ("user"."email" ilike %spam%)');
  }

  // Complex condition
  print('✅ Complex condition:');
  try {
    final users = await User.where((User.query().first_name.equals('John') |
            User.query().first_name.equals('Jane')) &
        User.query().email.ilike('%gmail.com') &
        ~User.query().email.ilike('%test%'));
  } catch (e) {
    print('   Would execute complex WHERE with multiple AND/OR/NOT conditions');
  }

  print('');
}

/// Relationship query examples
Future<void> _relationshipQueryExamples() async {
  print('🔗 Relationship Query Examples:');

  // Query books by author
  print('✅ Query books by author:');
  try {
    final books = await Book.where(
        Book.query().author.first_name.equals('J.K.') &
            Book.query().author.last_name.equals('Rowling'));
  } catch (e) {
    print(
        '   Would execute: SELECT * FROM book JOIN author WHERE author conditions');
  }

  // Query reviews by book title
  print('✅ Query reviews by book title:');
  try {
    final reviews = await Review.where(
        Review.query().book.title.ilike('%Harry Potter%') &
                Review.query().rating >=
            '4');
  } catch (e) {
    print(
        '   Would execute: SELECT * FROM review JOIN book WHERE book.title ILIKE \'%Harry Potter%\' AND rating >= 4');
  }

  // Query books with high-rated reviews
  print('✅ Query books with high-rated reviews:');
  try {
    final reviews = await Review.where(Review.query().rating >=
        '4' &
            Review.query().isApproved.equals(true) &
            ~Review.query().isSpam.equals(true));
  } catch (e) {
    print(
        '   Would execute: SELECT * FROM review WHERE rating >= 4 AND is_approved = true AND NOT is_spam = true');
  }

  print();
}

/// Examples comparing old vs new syntax
void _syntaxComparison() {
  print('📊 Syntax Comparison:');
  print();

  print('❌ OLD (String-based, error-prone):');
  print(
      '   User.findAll(where: "email = ? AND first_name LIKE ?", parameters: ["john@example.com", "John%"])');
  print();

  print('✅ NEW (Type-safe, IDE-friendly):');
  print(
      '   User.where(User.query().email.equals("john@example.com") & User.query().first_name.like("John%"))');
  print();

  print('🎯 Benefits:');
  print('   ✓ Type safety - no runtime SQL errors');
  print('   ✓ IDE autocompletion for column names');
  print('   ✓ Compile-time validation');
  print('   ✓ Refactoring support');
  print('   ✓ No SQL injection risks');
  print('   ✓ Readable and maintainable code');
  print();
}

/// Advanced query examples
void _advancedExamples() {
  print('🚀 Advanced Query Examples:');
  print();

  print('✅ Find first user:');
  print(
      '   final user = await User.firstWhere(User.query().email.equals("admin@example.com"));');
  print();

  print('✅ Custom query builder:');
  print('   final query = User.query()');
  print('     ..where(User.query().email.ilike("%gmail.com"))');
  print('     ..limit(10)');
  print('     ..orderBy("first_name");');
  print('   final users = await User.findWhere(query);');
  print();

  print('✅ Null checks:');
  print('   User.where(User.query().last_name.isNull())');
  print('   User.where(User.query().last_name.isNotNull())');
  print();
}
