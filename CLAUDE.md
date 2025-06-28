# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Tapioca DSL Compiler gem that generates RBI (Ruby Interface) files for StoreModel attributes in ActiveRecord models. StoreModel adds JSON-backed attributes to ActiveRecord, and this compiler provides Sorbet type signatures for the methods that StoreModel dynamically generates.

## Key Architecture

### Core Components

- **Main Compiler**: `lib/tapioca/dsl/compilers/store_model.rb` - The core DSL compiler that follows Tapioca's standard pattern
- **Entry Point**: `lib/tapioca_dsl_compiler_store_model.rb` - Conditional loading mechanism that only loads the compiler when both Tapioca and StoreModel are available
- **Version Module**: `lib/tapioca_dsl_compiler_store_model/version.rb` - Standard gem version definition

### Compiler Implementation

The compiler (`Tapioca::Dsl::Compilers::StoreModel`) extends `Tapioca::Dsl::Compiler` and implements:

1. **`gather_constants`**: Identifies ActiveRecord models that have StoreModel attributes by checking `attribute_types` for StoreModel::Types::One and StoreModel::Types::Many
2. **`decorate`**: Generates RBI signatures for StoreModel attributes including:
   - Getter methods (`attribute_name`)
   - Setter methods (`attribute_name=`)
   - Builder methods (`build_attribute_name`) for single-type attributes

### Conditional Loading Pattern

The gem uses a defensive loading pattern in the entry point:
- Only loads the compiler implementation when both `Tapioca::Dsl::Compiler` and `StoreModel` are defined
- Gracefully handles missing dependencies with `rescue LoadError`

## Development Commands

### Testing
```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/tapioca/dsl/compilers/store_model_spec.rb

# Run with verbose output
bundle exec rspec --format documentation
```

### Gem Tasks
```bash
# Run default task (tests)
bundle exec rake

# Build gem
bundle exec rake build

# Install locally
bundle exec rake install
```

## Test Architecture

### Integration Testing Pattern

The test suite uses a sophisticated integration testing approach:

- **Dynamic Test Environment**: Creates temporary directories and modifies `$LOAD_PATH` for isolated testing
- **In-Memory SQLite**: Uses `:memory:` database for fast, isolated ActiveRecord tests
- **Automatic Constant Cleanup**: `add_ruby_file` method automatically tracks and cleans up dynamically created constants
- **Real RBI Generation**: Tests use the actual compiler (not mocks) via the `rbi_for` helper method

### Key Test Helpers

- **`rbi_for(klass_name)`**: Generates actual RBI output using the real compiler pipeline
- **`add_ruby_file(filename, content)`**: Creates temporary Ruby files and automatically registers constants for cleanup
- **`register_test_constant(const_name)`**: Manually register constants for cleanup

### Test Structure

Tests are organized in `spec/tapioca/dsl/compilers/store_model_spec.rb` following Tapioca's single-file pattern with comprehensive coverage of:
- Single StoreModel attributes
- Array StoreModel attributes  
- Mixed regular and StoreModel attributes
- Nested StoreModel structures
- Inheritance scenarios
- Edge cases and error conditions

## Commit Guidelines

- Follow [Conventional Commits](https://www.conventionalcommits.org/) specification
- Write commit messages in English
- Use these types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`
- Examples:
  - `feat: add support for nested StoreModel attributes`
  - `fix: handle edge case in constant gathering`
  - `docs: update README with usage examples`
  - `test: add comprehensive array type coverage`

## Code Guidelines

- Write all code comments in English
- Use descriptive variable and method names
- Follow Ruby conventions and style guidelines

## Dependencies

- **Runtime**: `tapioca >= 0.11.0`, `store_model >= 1.0.0`
- **Development**: `rspec`, `sqlite3`, `activerecord ~> 7.0`
- **Ruby Version**: >= 2.7.0