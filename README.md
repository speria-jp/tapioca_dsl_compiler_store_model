# Tapioca DSL Compiler for StoreModel

A [Tapioca](https://github.com/Shopify/tapioca) DSL compiler that generates RBI files for [StoreModel](https://github.com/DmitryTsepelev/store_model) attributes in ActiveRecord models.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'tapioca_dsl_compiler_store_model'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install tapioca_dsl_compiler_store_model
```

## Usage

Once installed, Tapioca will automatically discover and use this compiler when generating RBI files with `bundle exec tapioca dsl`.

### Example

Given the following StoreModel setup:

```ruby
# app/models/user_settings.rb
class UserSettings
  include StoreModel::Model

  attribute :theme, :string
  attribute :notifications, :boolean
  attribute :language, :string
end

# app/models/preference.rb
class Preference
  include StoreModel::Model

  attribute :key, :string
  attribute :value, :string
end

# app/models/user.rb
class User < ActiveRecord::Base
  attribute :settings, UserSettings.to_type
  attribute :preferences, Preference.to_array_type
end
```

Running `bundle exec tapioca dsl` will generate the following RBI file:

```ruby
# sorbet/rbi/dsl/user.rbi
# typed: strong

class User
  sig { returns(T.nilable(UserSettings)) }
  def settings; end

  sig { params(value: T.nilable(T.any(UserSettings, T::Hash[T.untyped, T.untyped]))).returns(T.nilable(UserSettings)) }
  def settings=(value); end

  sig { params(attributes: T::Hash[T.untyped, T.untyped]).returns(UserSettings) }
  def build_settings(attributes: {}); end

  sig { returns(T::Array[Preference]) }
  def preferences; end

  sig { params(value: T.nilable(T.any(T::Array[Preference], T::Array[T::Hash[T.untyped, T.untyped]]))).returns(T::Array[Preference]) }
  def preferences=(value); end
end
```

### Supported StoreModel Types

This compiler supports all StoreModel attribute types:

- **Single Models**: `Model.to_type` - generates getter, setter, and builder methods
- **Array Models**: `Model.to_array_type` - generates getter and setter methods for arrays
- **Nested Models**: StoreModel classes that contain other StoreModel attributes

### Generated Methods

For each StoreModel attribute, the compiler generates type signatures for:

1. **Getter method**: Returns the StoreModel instance or array
2. **Setter method**: Accepts StoreModel instance(s) or Hash(es)
3. **Builder method** (single types only): Creates a new instance with given attributes

## Limitations

Currently, this compiler has the following limitations:

- **Enum Support**: Does not generate RBI signatures for enum methods (e.g., predicate methods like `active?`, bang methods like `status_active!`)
- **Nested Attributes**: Does not support `accepts_nested_attributes_for` generated methods
- **Custom Types**: Only supports `StoreModel::Types::One` and `StoreModel::Types::Many`, custom types are not detected
- **Validation Methods**: Does not generate signatures for StoreModel validation methods

These features may be added in future versions.

## Requirements

- Ruby 3.2+
- [Tapioca](https://github.com/Shopify/tapioca) 0.11+
- [StoreModel](https://github.com/DmitryTsepelev/store_model) 1.0+

## Development

After checking out the repo, run:

```bash
$ bundle install
```

To run the test suite:

```bash
$ bundle exec rspec
```

To run the linter:

```bash
$ bundle exec rubocop
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/speria-jp/tapioca_dsl_compiler_store_model.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).