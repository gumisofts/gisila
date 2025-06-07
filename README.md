**Gisila Project Structure**

## **1. Overview**
This project aims to develop a Dart Object-Relational Mapper (ORM) that supports **SQLite, PostgreSQL, and MySQL**. The ORM will rely on **code generation** using a builder pattern from a YAML-based schema definition. The key components of the ORM include:

- **Schema Definition Language**
- **Database Configuration Handler**
- **Code Generator Engine**
- **Query Builder**
- **Migration Handler**

## **2. Project Structure**
The project will be organized as follows:

```
dart_orm/
│── lib/
│   ├── schema/
│   │   ├── schema_parser.dart
│   │   ├── schema_validator.dart
│   ├── config/
│   │   ├── database_config.dart
│   │   ├── connection_pool.dart
│   ├── generator/
│   │   ├── code_generator.dart
│   │   ├── templates/
│   │   │   ├── model_template.dart
│   │   │   ├── migration_template.dart
│   ├── query/
│   │   ├── query_builder.dart
│   │   ├── filter_conditions.dart
│   ├── migration/
│   │   ├── migration_handler.dart
│   │   ├── migration_executor.dart
│── bin/
│   ├── generate.dart
│   ├── migrate.dart
│── test/
│── example/
│── pubspec.yaml
```

## **3. Component Breakdown**

### **Feature Implementation Progress**

| **Feature**               | **Description**                                         | **Progress** |
|---------------------------|---------------------------------------------------------|-------------|
| Schema Definition Language | Defines models and relationships using YAML            | Not Started |
| Database Configuration    | Manages database connections for supported databases    | Not Started |
| Code Generator Engine     | Generates models and migration scripts                  | Not Started |
| Query Builder             | Provides a fluent API for database queries              | Not Started |
| Migration Handler         | Manages database migrations                             | Not Started |
| CLI Commands for Migrations | Command-line tool to create, run, and rollback migrations | Not Started |
| Hooks & Events            | Lifecycle hooks for model operations                    | Not Started |
| Transactions              | Ensures data integrity across multiple operations       | Not Started |
| Batch Insert/Update       | Optimized queries for bulk operations                   | Not Started |
| Pagination & Sorting      | Built-in utilities for managing pagination and sorting  | Not Started |
| Custom Validations        | Model-level validation rules                            | Not Started |
| Relation Handling         | Supports eager and lazy loading for related models     | Not Started |
| Multi-Tenancy Support     | Allows shared databases across tenants                 | Not Started |
| Seeders & Factories       | Utilities for seeding data and creating test factories | Not Started |
| Logging & Debugging       | Tools for query logging and debugging                   | Not Started |

## **4. Data Type and Column Configuration Mapping**

| **SDL Type** | **PostgreSQL**            | **SQLite**           | **MySQL**              | **Column Configurations** |
|-------------|-------------------------|--------------------|----------------------|-------------------------|
| `int`       | `INTEGER`                | `INTEGER`          | `INT`               | `PRIMARY KEY`, `UNIQUE`, `NOT NULL`, `INDEX` |
| `bigint`    | `BIGINT`                 | `INTEGER` (64-bit) | `BIGINT`            | `PRIMARY KEY`, `UNIQUE`, `NOT NULL`, `INDEX` |
| `smallint`  | `SMALLINT`               | `INTEGER` (16-bit) | `SMALLINT`          | `NOT NULL`, `DEFAULT` |
| `decimal`   | `DECIMAL(p,s)`           | `NUMERIC`          | `DECIMAL(p,s)`      | `NOT NULL`, `DEFAULT` |
| `float`     | `REAL` / `DOUBLE PRECISION` | `REAL`         | `FLOAT`             | `NOT NULL`, `DEFAULT` |
| `boolean`   | `BOOLEAN`                | `INTEGER` (0/1)    | `BOOLEAN` (TINYINT) | `NOT NULL`, `DEFAULT` |
| `string`    | `TEXT` / `VARCHAR(n)`     | `TEXT`             | `VARCHAR(n)`        | `NOT NULL`, `DEFAULT`, `INDEX` |
| `char(n)`   | `CHAR(n)`                | `TEXT`             | `CHAR(n)`           | `NOT NULL`, `DEFAULT` |
| `uuid`      | `UUID`                   | `TEXT`             | `CHAR(36)`          | `PRIMARY KEY`, `UNIQUE`, `NOT NULL` |
| `json`      | `JSONB` / `JSON`         | `TEXT`             | `JSON`              | `NOT NULL`, `DEFAULT` |
| `date`      | `DATE`                   | `TEXT` (ISO 8601)  | `DATE`              | `NOT NULL`, `DEFAULT` |
| `time`      | `TIME`                   | `TEXT` (ISO 8601)  | `TIME`              | `NOT NULL`, `DEFAULT` |
| `datetime`  | `TIMESTAMP`              | `TEXT` (ISO 8601)  | `DATETIME`          | `NOT NULL`, `DEFAULT` |
| `timestamp` | `TIMESTAMP WITH TIME ZONE` | `TEXT`          | `TIMESTAMP`         | `NOT NULL`, `DEFAULT` |
| `binary`    | `BYTEA`                  | `BLOB`             | `BLOB`              | `NOT NULL`, `DEFAULT` |

## **5. Development Roadmap**
1. Implement **Schema Parser** and **Validator**.
2. Develop **Database Configuration Handler**.
3. Create **Code Generation Engine**.
4. Build **Query Builder API**.
5. Implement **Migration Handling**.
6. Add additional features and optimize for performance.
7. Write comprehensive tests and documentation.

## **6. Schema Definition Language**

Gisila uses a YAML-based schema definition language to define your database models, relationships, and constraints. The schema file serves as the single source of truth for your application's data model.

### **6.1. Basic Model Definition**

Models are defined as top-level keys in the YAML file. Each model represents a database table:

```yaml
User:
  columns:
    first_name:
      type: varchar
      is_null: false
    email:
      type: varchar
      is_null: false
      is_unique: true
      is_index: true
```

### **6.2. Column Types**

The following column types are supported:

| **Type**    | **Description**                           | **Example Usage**          |
|-------------|-------------------------------------------|----------------------------|
| `varchar`   | Variable-length string                    | `type: varchar`           |
| `text`      | Large text field                          | `type: text`              |
| `integer`   | 32-bit integer                           | `type: integer`           |
| `bigint`    | 64-bit integer                           | `type: bigint`            |
| `boolean`   | Boolean true/false                        | `type: boolean`           |
| `date`      | Date only (YYYY-MM-DD)                   | `type: date`              |
| `timestamp` | Date and time with timezone              | `type: timestamp`         |
| `decimal`   | Fixed-point decimal number               | `type: decimal`           |
| `json`      | JSON data type                           | `type: json`              |
| `uuid`      | Universally unique identifier            | `type: uuid`              |

### **6.3. Column Constraints**

Each column can have various constraints and properties:

| **Property**    | **Type**  | **Description**                           | **Default** |
|-----------------|-----------|-------------------------------------------|-------------|
| `is_null`       | boolean   | Allow NULL values                         | `true`      |
| `is_unique`     | boolean   | Enforce unique constraint                 | `false`     |
| `is_index`      | boolean   | Create database index                     | `false`     |
| `is_primary`    | boolean   | Mark as primary key                       | `false`     |
| `allow_blank`   | boolean   | Allow empty strings                       | `true`      |
| `default`       | mixed     | Default value for the column              | `null`      |

**Example:**
```yaml
Book:
  columns:
    title:
      type: varchar
      is_null: false
      is_unique: true
      is_index: true
      is_primary: true
      allow_blank: false
    isbn:
      type: varchar
      is_null: true
      is_unique: true
      is_index: true
```

### **6.4. Relationships**

Gisila supports various types of relationships between models:

#### **6.4.1. One-to-Many (Foreign Key)**

```yaml
Book:
  columns:
    author:
      type: Author
      references: Author
      is_index: true
      reverse_name: written_books
```

#### **6.4.2. Many-to-Many**

```yaml
Book:
  columns:
    reviewers:
      type: User
      many_to_many: true
      references: User
      reverse_name: reviewed_books
```

#### **6.4.3. One-to-One**

```yaml
Review:
  columns:
    book:
      type: Book
      references: Book
      reverse_name: reviews
    reviewer:
      type: User
      references: User
      reverse_name: reviews
```

### **6.5. Advanced Model Configuration**

#### **6.5.1. Custom Table Names**

By default, table names are derived from the model name. You can override this:

```yaml
Review:
  db_table: reviews
  columns:
    # ... column definitions
```

#### **6.5.2. Custom Indexes**

Define composite indexes for better query performance:

```yaml
Review:
  columns:
    # ... column definitions
  indexes:
    idx_review_book:
      columns:
        - book
    idx_review_reviewer:
      columns:
        - reviewer
    idx_book_reviewer_composite:
      columns:
        - book
        - reviewer
      unique: true  # Optional: create unique composite index
```

### **6.6. Complete Example**

Here's a complete example showing various features:

```yaml
User:
  columns:
    id:
      type: uuid
      is_primary: true
      is_null: false
    first_name:
      type: varchar
      is_null: false
    last_name:
      type: varchar
      is_null: true
      allow_blank: true
    email:
      type: varchar
      is_null: false
      is_unique: true
      is_index: true
    password:
      type: varchar
      is_null: false
    date_joined:
      type: timestamp
      is_null: false
      default: "NOW()"
    is_active:
      type: boolean
      is_null: false
      default: true

Book:
  columns:
    id:
      type: uuid
      is_primary: true
      is_null: false
    title:
      type: varchar
      is_null: false
      is_unique: true
      is_index: true
    subtitle:
      type: varchar
      is_null: true
    description:
      type: text
      is_null: true
    published_date:
      type: date
      is_null: true
    isbn:
      type: varchar
      is_null: true
      is_unique: true
      is_index: true
    page_count:
      type: integer
      is_null: true
    author:
      type: Author
      references: Author
      is_index: true
      reverse_name: written_books
    reviewers:
      type: User
      many_to_many: true
      references: User
      reverse_name: reviewed_books
  indexes:
    idx_title_author:
      columns:
        - title
        - author
```

### **6.7. Schema Validation Rules**

- Model names must be in PascalCase
- Column names should be in snake_case
- Primary keys are automatically indexed
- Foreign key columns are automatically indexed unless specified otherwise
- Many-to-many relationships create junction tables automatically
- The `reverse_name` property defines the accessor name on the referenced model

### **6.8. Code Generation**

Once your schema is defined, use the code generator to create Dart model classes:

```bash
dart run bin/generate.dart --schema=schema.yaml --output=lib/models/
```

This will generate:
- Model classes with proper typing
- Relationship accessors
- Validation methods
- Migration files

## **7. Conclusion**
This ORM will simplify database interactions in Dart by providing an intuitive API, automatic schema-based code generation, and robust migration handling. The project will prioritize **performance, extensibility, and multi-database support**.

