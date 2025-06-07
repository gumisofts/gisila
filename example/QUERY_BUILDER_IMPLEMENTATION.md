# Query Builder Implementation for Gisila ORM

## Overview

This implementation replaces direct string WHERE clauses with a type-safe query builder pattern based on the existing query generator from `@/home/murad/gisila/test/models/schema.query.g.dart`.

## What Was Implemented

### 1. Query Generator (`lib/generators/query_generator.dart`)

A new generator that creates type-safe query builders for each model:

```dart
class QueryGenerator {
  /// Generate query builder class for a model
  String generateQueryClass(ModelDefinition model);
  
  /// Generate all query classes for a schema
  String generateAllQueryClasses(SchemaDefinition schema);
}
```

### 2. Enhanced Code Generator

Updated `lib/generators/code_generator.dart` to include query builder generation:

- Added `_generateQueryBuilders()` method
- Generates individual query classes for each model
- Creates a barrel file for easy imports
- Integrates with existing model generation pipeline

### 3. Enhanced Model Generator

Updated `lib/generators/model_generator.dart` to include query builder methods in generated models:

- Added imports for query classes and operators
- Added `query()` static method to create query builders
- Added `where()` method for type-safe queries
- Added `firstWhere()` method for single record queries

### 4. Generated Query Structure

Each model gets a corresponding query class:

```dart
/// Query builder for User model
class UserQuery extends Query {
  // Column accessors with proper types
  TextColumn get email => TextColumn(column: 'email', offtable: 'user');
  NumberColumn get id => NumberColumn(column: 'id', offtable: 'user');
  
  // Relationship accessors
  AuthorQuery get author => AuthorQuery.referenced(joins: [...]);
  
  // Query building methods
  UserQuery where(Operation operation);
  UserQuery select(List<String> columns);
}
```

### 5. Column Types

Different column types provide appropriate operators:

- **TextColumn**: `equals()`, `like()`, `ilike()`, `contains()`, `>`, `<`, etc.
- **NumberColumn**: `>=`, `<=`, `>`, `<`, `inRange()`, etc.
- **BooleanColumn**: `equals()`
- **DateTimeColumn**: Date/time comparisons

### 6. Operation Combinators

Query operations can be combined using operators:

- `&` for AND conditions
- `|` for OR conditions  
- `~` for NOT conditions

## Usage Examples

### Old vs New Syntax

```dart
// ❌ OLD (String-based, error-prone)
User.findAll(
  where: "email = ? AND first_name LIKE ?",
  parameters: ["john@example.com", "John%"]
)

// ✅ NEW (Type-safe, IDE-friendly)
User.where(
  User.query().email.equals("john@example.com") &
  User.query().first_name.like("John%")
)
```

### Basic Queries

```dart
// Simple equality
User.where(User.query().email.equals('john@example.com'))

// Comparison operators
User.where(User.query().id > '10')

// Text search
User.where(User.query().first_name.like('John%'))

// Case-insensitive search
User.where(User.query().email.ilike('%gmail.com'))

// IN clause
User.where(User.query().id.inn([1, 2, 3]))

// NULL checks
User.where(User.query().last_name.isNull())
```

### Complex Queries

```dart
// AND conditions
User.where(
  User.query().first_name.equals('John') &
  User.query().email.ilike('%gmail.com')
)

// OR conditions
User.where(
  User.query().first_name.equals('John') |
  User.query().first_name.equals('Jane')
)

// NOT conditions
User.where(~User.query().email.ilike('%spam%'))

// Complex combinations
User.where(
  (User.query().first_name.equals('John') |
   User.query().first_name.equals('Jane')) &
  User.query().email.ilike('%gmail.com') &
  ~User.query().email.ilike('%test%')
)
```

### Relationship Queries

```dart
// Query books by author
Book.where(
  Book.query().author.first_name.equals('J.K.') &
  Book.query().author.last_name.equals('Rowling')
)

// Query reviews by book title and rating
Review.where(
  Review.query().book.title.ilike('%Harry Potter%') &
  Review.query().rating >= '4'
)
```

### Method Chaining

```dart
// Find first matching record
final user = await User.firstWhere(
  User.query().email.equals('admin@example.com')
);

// Custom query builder
final query = User.query()
  .where(User.query().email.ilike('%gmail.com'))
  .limit(10)
  .orderBy('first_name');
final users = await User.findWhere(query);
```

## Generated Files Structure

```
example/generated_with_queries/
├── models/
│   ├── user.dart          # Enhanced with query builder methods
│   ├── author.dart        # Enhanced with query builder methods
│   ├── book.dart          # Enhanced with query builder methods
│   ├── review.dart        # Enhanced with query builder methods
│   └── models.dart        # Barrel file
├── queries/
│   ├── user_query.dart    # Type-safe query builder for User
│   ├── author_query.dart  # Type-safe query builder for Author
│   ├── book_query.dart    # Type-safe query builder for Book
│   ├── review_query.dart  # Type-safe query builder for Review
│   └── queries.dart       # Barrel file
└── migrations/
    └── ...
```

## Benefits

### ✓ Type Safety
- Column names are checked at compile time
- No more runtime SQL syntax errors
- IDE shows errors immediately

### ✓ IDE Support
- Full autocompletion for column names
- IntelliSense shows available methods
- Refactoring support when schema changes

### ✓ Security
- No SQL injection risks
- Values are properly escaped
- Type checking prevents invalid data

### ✓ Maintainability
- Readable and self-documenting code
- Easy to understand complex queries
- Consistent query patterns across codebase

### ✓ Developer Experience
- Less documentation needed
- Faster development with autocomplete
- Fewer bugs in production

## Integration with Existing System

The query builder integrates seamlessly with the existing Gisila ORM system:

1. **Schema Definition**: Uses existing YAML schema parsing
2. **Code Generation**: Extends existing model generator
3. **Database Context**: Works with existing DatabaseContext
4. **Query Engine**: Built on existing Query/Operation classes
5. **Column Types**: Reuses existing TextColumn, NumberColumn, etc.

## Generation Command

```bash
# Generate models with query builders
dart run bin/generate.dart --schema=test/models/schema.yaml --output=example/generated_with_queries --verbose
```

This creates both the model classes and their corresponding query builders, providing a complete type-safe querying solution for the Gisila ORM.

## Example Output

When you run the query builder example:

```bash
dart run example/query_builder_simple_example.dart
```

You'll see a comprehensive demonstration of the query builder patterns and their benefits over direct string WHERE clauses. 