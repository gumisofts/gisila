/// Example demonstrating part-based model generation
/// This approach eliminates file dependencies by using Dart's `part of` directive
/// All models and queries are part of a single library

// Only one import needed - no dependency management required!
import 'generated/models.dart';

void main() async {
  print('=== Part-Based Model Generation Example ===\n');

  // Show the benefits of part-based approach
  _demonstratePartOfBenefits();

  print('\n=== Code Examples ===\n');

  // All types are available without additional imports
  await _demoBasicUsage();
  await _demoQueryBuilders();
}

void _demonstratePartOfBenefits() {
  print('🎯 Benefits of Part-Based Generation:');
  print('');
  print('1. Single Import: Only need to import one file');
  print('   import "generated/models.dart"; // Everything available!');
  print('');
  print('2. No Dependency Management: No need to track imports between files');
  print('   - No circular dependency issues');
  print('   - No missing import errors');
  print('   - No need to manage relationships between model files');
  print('');
  print('3. Simplified File Structure:');
  print('   generated/');
  print('   ├── models.dart          (main library file - import this)');
  print(
      '   └── generated/           (internal parts - do not import directly)');
  print('       ├── base_model.dart');
  print('       ├── user.dart');
  print('       ├── user_query.dart');
  print('       ├── author.dart');
  print('       ├── author_query.dart');
  print('       └── ...');
  print('');
  print('4. Type Safety: All types available in single namespace');
  print('   - No need to import related models for relationships');
  print('   - IDE autocompletion works perfectly');
  print('   - Compile-time checking for all types');
}

Future<void> _demoBasicUsage() async {
  print(
      '📦 Basic Model Usage (All types available without additional imports):');
  print('');

  try {
    // Create a user - User class available directly
    print('// Create a user');
    print('final user = await User.create(');
    print('  first_name: "John",');
    print('  email: "john@example.com",');
    print('  password: "secure123", ');
    print('  date_joined: DateTime.now(),');
    print(');');
    print('print("Created user: \${user.first_name}");');
    print('');

    // Create an author - Author class available directly
    print('// Create an author (no import needed for Author)');
    print('final author = await Author.create(');
    print('  name: "Jane Smith",');
    print('  bio: "Bestselling author",');
    print('  birth_date: DateTime(1980, 5, 15),');
    print(');');
    print('print("Created author: \${author.name}");');
    print('');

    // Create a book - Book class available directly
    print('// Create a book (no import needed for Book)');
    print('final book = await Book.create(');
    print('  title: "The Great Novel",');
    print('  isbn: "978-1234567890",');
    print('  published_date: DateTime(2023, 1, 1),');
    print('  page_count: 300,');
    print('  is_available: true,');
    print('  author: author, // Author type available directly');
    print(');');
    print('print("Created book: \${book.title}");');
    print('');

    print('✅ All model classes work together seamlessly!');
  } catch (e) {
    print(
        'Note: This is a demo - actual database operations would work with real DB connection');
    print('Error (expected): $e');
  }
}

Future<void> _demoQueryBuilders() async {
  print(
      '🔍 Query Builder Usage (All query types available without additional imports):');
  print('');

  print('// Type-safe queries - no imports needed for any query builders');
  print('');

  print('// User queries - UserQuery available directly');
  print('final userQuery = User.query();');
  print('print("User email column: \${userQuery.email}");');
  print('');

  print('// Author queries - AuthorQuery available directly');
  print('final authorQuery = Author.query();');
  print('print("Author name column: \${authorQuery.name}");');
  print('');

  print('// Book queries - BookQuery available directly');
  print('final bookQuery = Book.query();');
  print('print("Book title column: \${bookQuery.title}");');
  print('');

  print('// Review queries - ReviewQuery available directly');
  print('final reviewQuery = Review.query();');
  print('print("Review rating column: \${reviewQuery.rating}");');
  print('');

  try {
    // Demonstrate actual usage
    final userQuery = User.query();
    final authorQuery = Author.query();
    final bookQuery = Book.query();
    final reviewQuery = Review.query();

    print('✅ All query builder types instantiated successfully!');
    print('   - UserQuery: ${userQuery.runtimeType}');
    print('   - AuthorQuery: ${authorQuery.runtimeType}');
    print('   - BookQuery: ${bookQuery.runtimeType}');
    print('   - ReviewQuery: ${reviewQuery.runtimeType}');
  } catch (e) {
    print('Demo instantiation: $e');
  }

  print('');
  print('🎉 Part-based generation eliminates all import dependency issues!');
  print('   Just import one file and everything works together perfectly.');
}
