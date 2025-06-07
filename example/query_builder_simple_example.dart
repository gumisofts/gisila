/// Simple Query Builder Example for Gisila ORM
/// Demonstrates the concept of type-safe WHERE clause generation

void main() {
  print('🔍 Query Builder Examples for Gisila ORM\n');
  
  _syntaxComparison();
  _queryExamples();
  _benefitsExplanation();
}

/// Examples comparing old vs new syntax
void _syntaxComparison() {
  print('📊 Syntax Comparison:');
  print('');
  
  print('❌ OLD (String-based, error-prone):');
  print('   User.findAll(');
  print('     where: "email = ? AND first_name LIKE ?",');
  print('     parameters: ["john@example.com", "John%"]');
  print('   )');
  print('');
  
  print('✅ NEW (Type-safe, IDE-friendly):');
  print('   User.where(');
  print('     User.query().email.equals("john@example.com") &');
  print('     User.query().first_name.like("John%")');
  print('   )');
  print('');
}

/// Query examples showing different patterns
void _queryExamples() {
  print('🚀 Query Examples:');
  print('');
  
  print('✅ Basic equality:');
  print('   User.query().email.equals("john@example.com")');
  print('   → WHERE "user"."email" = \'john@example.com\'');
  print('');
  
  print('✅ Comparison operators:');
  print('   User.query().id > "10"');
  print('   → WHERE "user"."id" > 10');
  print('');
  
  print('✅ Text search:');
  print('   User.query().first_name.like("John%")');
  print('   → WHERE "user"."first_name" LIKE \'John%\'');
  print('');
  
  print('✅ Case-insensitive search:');
  print('   User.query().email.ilike("%gmail.com")');
  print('   → WHERE "user"."email" ILIKE \'%gmail.com\'');
  print('');
  
  print('✅ IN clause:');
  print('   User.query().id.inn([1, 2, 3])');
  print('   → WHERE "user"."id" IN (1, 2, 3)');
  print('');
  
  print('✅ NULL checks:');
  print('   User.query().last_name.isNull()');
  print('   → WHERE "user"."last_name" IS NULL');
  print('');
  
  print('✅ AND conditions:');
  print('   User.query().first_name.equals("John") &');
  print('   User.query().email.ilike("%gmail.com")');
  print('   → WHERE ("user"."first_name" = \'John\') AND ("user"."email" ILIKE \'%gmail.com\')');
  print('');
  
  print('✅ OR conditions:');
  print('   User.query().first_name.equals("John") |');
  print('   User.query().first_name.equals("Jane")');
  print('   → WHERE ("user"."first_name" = \'John\') OR ("user"."first_name" = \'Jane\')');
  print('');
  
  print('✅ NOT conditions:');
  print('   ~User.query().email.ilike("%spam%")');
  print('   → WHERE NOT ("user"."email" ILIKE \'%spam%\')');
  print('');
  
  print('✅ Complex combinations:');
  print('   (User.query().first_name.equals("John") |');
  print('    User.query().first_name.equals("Jane")) &');
  print('   User.query().email.ilike("%gmail.com") &');
  print('   ~User.query().email.ilike("%test%")');
  print('   → Complex WHERE with multiple AND/OR/NOT conditions');
  print('');
  
  print('✅ Relationship queries:');
  print('   Book.query().author.first_name.equals("J.K.") &');
  print('   Book.query().author.last_name.equals("Rowling")');
  print('   → SELECT * FROM book JOIN author WHERE author conditions');
  print('');
  
  print('✅ Method chaining:');
  print('   User.query()');
  print('     .where(User.query().email.ilike("%gmail.com"))');
  print('     .limit(10)');
  print('     .orderBy("first_name")');
  print('   → SELECT * FROM user WHERE ... LIMIT 10 ORDER BY first_name');
  print('');
}

/// Benefits explanation
void _benefitsExplanation() {
  print('🎯 Benefits of Query Builder Pattern:');
  print('');
  
  print('✓ TYPE SAFETY');
  print('  - Column names are checked at compile time');
  print('  - No more runtime SQL syntax errors');
  print('  - IDE shows errors immediately');
  print('');
  
  print('✓ IDE SUPPORT');
  print('  - Full autocompletion for column names');
  print('  - IntelliSense shows available methods');
  print('  - Refactoring support when schema changes');
  print('');
  
  print('✓ SECURITY');
  print('  - No SQL injection risks');
  print('  - Values are properly escaped');
  print('  - Type checking prevents invalid data');
  print('');
  
  print('✓ MAINTAINABILITY');
  print('  - Readable and self-documenting code');
  print('  - Easy to understand complex queries');
  print('  - Consistent query patterns across codebase');
  print('');
  
  print('✓ DEVELOPER EXPERIENCE');
  print('  - Less documentation needed');
  print('  - Faster development with autocomplete');
  print('  - Fewer bugs in production');
  print('');
}

/* 
Generated query builder structure example:

```dart
class UserQuery extends Query {
  // Column accessors with proper types
  TextColumn get email => TextColumn(column: 'email', offtable: 'user');
  TextColumn get first_name => TextColumn(column: 'first_name', offtable: 'user');
  NumberColumn get id => NumberColumn(column: 'id', offtable: 'user');
  
  // Methods for building queries
  UserQuery where(Operation operation) => UserQuery()..operation = operation;
  UserQuery limit(int count) => this..limit = count;
  UserQuery orderBy(String field) => this..orderBy = field;
}

class TextColumn {
  Operation equals(String value) => Operation(column, Operator.eq, value);
  Operation like(String pattern) => Operation(column, Operator.like, pattern);
  Operation ilike(String pattern) => Operation(column, Operator.ilike, pattern);
  // ... other text operations
}

class NumberColumn {
  Operation operator >(String value) => Operation(column, Operator.gt, value);
  Operation operator >=(String value) => Operation(column, Operator.gte, value);
  // ... other numeric operations
}
```

Usage patterns:

```dart
// Simple queries
final users = await User.where(User.query().email.equals('john@example.com'));

// Complex queries with relationships
final books = await Book.where(
  Book.query().author.first_name.equals('J.K.') &
  Book.query().published_date >= '2000-01-01'
);

// Query building
final query = User.query()
  .where(User.query().active.equals(true))
  .orderBy('created_at')
  .limit(50);
final users = await User.findWhere(query);
```
*/ 