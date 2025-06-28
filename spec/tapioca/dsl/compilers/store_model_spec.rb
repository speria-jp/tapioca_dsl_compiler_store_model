# frozen_string_literal: true

require_relative "../../../spec_helper"

RSpec.describe Tapioca::Dsl::Compilers::StoreModel, type: :integration do
  describe ".gather_constants" do
    context "with StoreModel attributes" do
      before do
        add_ruby_file("store_models.rb", <<~RUBY)
          class UserSettings
            include StoreModel::Model
            attribute :theme, :string
            attribute :notifications, :boolean
          end

          class User < ActiveRecord::Base
            attribute :settings, UserSettings.to_type
          end
        RUBY
      end

      it "includes ActiveRecord models with StoreModel attributes" do
        constants = described_class.gather_constants
        expect(constants).to include(User)
      end
    end

    context "without StoreModel attributes" do
      before do
        ActiveRecord::Schema.define do
          create_table :regular_users do |t|
            t.string :name
            t.timestamps
          end
        end

        add_ruby_file("regular_model.rb", <<~RUBY)
          class RegularUser < ActiveRecord::Base
            # Regular attributes only
          end
        RUBY
      end

      it "excludes ActiveRecord models without StoreModel attributes" do
        constants = described_class.gather_constants
        expect(constants).not_to include(RegularUser)
      end
    end
  end

  describe ".store_model_type?" do
    context "with StoreModel types" do
      before do
        add_ruby_file("store_models.rb", <<~RUBY)
          class UserSettings
            include StoreModel::Model
            attribute :theme, :string
          end

          class Preference
            include StoreModel::Model
            attribute :key, :string
          end

          class User < ActiveRecord::Base
            attribute :settings, UserSettings.to_type
            attribute :preferences, Preference.to_array_type
          end
        RUBY
      end

      it "correctly identifies StoreModel::Types::One" do
        user_attribute_types = User.attribute_types
        settings_type = user_attribute_types["settings"]

        expect(described_class.send(:store_model_type?, settings_type)).to be true
      end

      it "correctly identifies StoreModel::Types::Many" do
        user_attribute_types = User.attribute_types
        preferences_type = user_attribute_types["preferences"]

        expect(described_class.send(:store_model_type?, preferences_type)).to be true
      end

      it "correctly identifies the specific type classes" do
        user_attribute_types = User.attribute_types
        settings_type = user_attribute_types["settings"]
        preferences_type = user_attribute_types["preferences"]

        expect(settings_type.class.name).to include("StoreModel::Types")
        expect(preferences_type.class.name).to include("StoreModel::Types")
      end

      it "identifies types based on model_klass" do
        user_attribute_types = User.attribute_types
        settings_type = user_attribute_types["settings"]

        expect(described_class.send(:store_model_class_type?, settings_type)).to be true
        expect(settings_type.model_klass).to eq(UserSettings)
        expect(settings_type.model_klass.include?(StoreModel::Model)).to be true
      end
    end

    context "with non-StoreModel types" do
      it "rejects regular objects" do
        expect(described_class.send(:store_model_type?, "string")).to be false
        expect(described_class.send(:store_model_type?, 123)).to be false
        expect(described_class.send(:store_model_type?, Object.new)).to be false
      end
    end
  end

  describe "#decorate" do
    context "with single StoreModel attributes" do
      before do
        add_ruby_file("single_store_model.rb", <<~RUBY)
          class UserSettings
            include StoreModel::Model
            attribute :theme, :string
            attribute :notifications, :boolean
          end

          class User < ActiveRecord::Base
            attribute :settings, UserSettings.to_type
          end
        RUBY
      end

      it "identifies the model as having StoreModel attributes" do
        constants = described_class.gather_constants
        expect(constants).to include(User)
      end

      it "generates correct RBI for single StoreModel attribute" do
        expected = <<~RBI
          # typed: strong

          class User
            sig { returns(T.nilable(UserSettings)) }
            def settings; end

            sig { params(value: T.nilable(T.any(UserSettings, T::Hash[T.untyped, T.untyped]))).returns(T.nilable(UserSettings)) }
            def settings=(value); end

            sig { params(attributes: T::Hash[T.untyped, T.untyped]).returns(UserSettings) }
            def build_settings(attributes: {}); end
          end
        RBI

        actual = rbi_for(:User)
        expect(actual).to eq(expected)
      end
    end

    context "with array StoreModel attributes" do
      before do
        add_ruby_file("array_store_model.rb", <<~RUBY)
          class Preference
            include StoreModel::Model
            attribute :key, :string
            attribute :value, :string
          end

          class User < ActiveRecord::Base
            attribute :preferences, Preference.to_array_type
          end
        RUBY
      end

      it "identifies the model as having StoreModel attributes" do
        constants = described_class.gather_constants
        expect(constants).to include(User)
      end

      it "generates correct RBI for array StoreModel attribute" do
        expected = <<~RBI
          # typed: strong

          class User
            sig { returns(T::Array[Preference]) }
            def preferences; end

            sig { params(value: T.nilable(T.any(T::Array[Preference], T::Array[T::Hash[T.untyped, T.untyped]]))).returns(T::Array[Preference]) }
            def preferences=(value); end
          end
        RBI

        actual = rbi_for(:User)
        expect(actual).to eq(expected)
      end
    end

    context "with multiple StoreModel attributes" do
      before do
        add_ruby_file("multiple_store_models.rb", <<~RUBY)
          class UserSettings
            include StoreModel::Model
            attribute :theme, :string
          end

          class Preference
            include StoreModel::Model
            attribute :key, :string
            attribute :value, :string
          end

          class User < ActiveRecord::Base
            attribute :settings, UserSettings.to_type
            attribute :preferences, Preference.to_array_type
          end
        RUBY
      end

      it "identifies the model as having StoreModel attributes" do
        constants = described_class.gather_constants
        expect(constants).to include(User)
      end

      it "generates RBI for multiple StoreModel attributes" do
        expected = <<~RBI
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
        RBI

        actual = rbi_for(:User)
        expect(actual).to eq(expected)
      end
    end

    context "with mixed regular and StoreModel attributes" do
      before do
        add_ruby_file("mixed_attributes.rb", <<~RUBY)
          class UserSettings
            include StoreModel::Model
            attribute :theme, :string
          end

          class User < ActiveRecord::Base
            attribute :settings, UserSettings.to_type  # StoreModel attribute
            attribute :name, :string                   # Regular attribute
            attribute :age, :integer                   # Regular attribute
          end
        RUBY
      end

      it "identifies the model as having StoreModel attributes" do
        constants = described_class.gather_constants
        expect(constants).to include(User)
      end

      it "only generates RBI for StoreModel attributes" do
        expected = <<~RBI
          # typed: strong

          class User
            sig { returns(T.nilable(UserSettings)) }
            def settings; end

            sig { params(value: T.nilable(T.any(UserSettings, T::Hash[T.untyped, T.untyped]))).returns(T.nilable(UserSettings)) }
            def settings=(value); end

            sig { params(attributes: T::Hash[T.untyped, T.untyped]).returns(UserSettings) }
            def build_settings(attributes: {}); end
          end
        RBI

        actual = rbi_for(:User)
        expect(actual).to eq(expected)
      end

      it "identifies only StoreModel attributes" do
        ActiveRecord::Schema.define do
          create_table :mixed_users do |t|
            t.text :settings
            t.string :name
            t.integer :age
            t.timestamps
          end
        end

        add_ruby_file("mixed_user.rb", <<~RUBY)
          class MixedUser < ActiveRecord::Base
            attribute :settings, UserSettings.to_type  # StoreModel
            attribute :name, :string                   # Regular attribute
            attribute :age, :integer                   # Regular attribute
          end
        RUBY

        mixed_user_attributes = MixedUser.attribute_types
        settings_type = mixed_user_attributes["settings"]
        name_type = mixed_user_attributes["name"]
        age_type = mixed_user_attributes["age"]

        expect(described_class.send(:store_model_type?, settings_type)).to be true
        expect(described_class.send(:store_model_type?, name_type)).to be false
        expect(described_class.send(:store_model_type?, age_type)).to be false
      end
    end

    context "with inheritance" do
      before do
        ActiveRecord::Schema.define do
          create_table :extended_users do |t|
            t.text :settings
            t.timestamps
          end
        end

        add_ruby_file("inheritance.rb", <<~RUBY)
          class BaseSettings
            include StoreModel::Model
            attribute :base_setting, :string
          end

          class ExtendedSettings < BaseSettings
            attribute :extended_setting, :string
          end

          class BaseUser < ActiveRecord::Base
            self.table_name = "users"
          end

          class ExtendedUser < ActiveRecord::Base
            attribute :settings, ExtendedSettings.to_type
          end
        RUBY
      end

      it "handles inheritance correctly" do
        constants = described_class.gather_constants

        # ExtendedUser has StoreModel attributes so should be included
        expect(constants).to include(ExtendedUser)

        # BaseUser has no StoreModel attributes so should not be included
        expect(constants).not_to include(BaseUser)
      end
    end

    context "with complex nested StoreModel" do
      before do
        add_ruby_file("complex_store_model.rb", <<~RUBY)
          class Address
            include StoreModel::Model
          #{'  '}
            attribute :street, :string
            attribute :city, :string
            attribute :zip_code, :string
          end

          class Profile
            include StoreModel::Model
          #{'  '}
            attribute :bio, :string
            attribute :avatar_url, :string
            attribute :address, Address.to_type
          end

          class User < ActiveRecord::Base
            attribute :profile, Profile.to_type
          end
        RUBY
      end

      it "generates correct RBI for nested StoreModel structures" do
        expected = <<~RBI
          # typed: strong

          class User
            sig { returns(T.nilable(Profile)) }
            def profile; end

            sig { params(value: T.nilable(T.any(Profile, T::Hash[T.untyped, T.untyped]))).returns(T.nilable(Profile)) }
            def profile=(value); end

            sig { params(attributes: T::Hash[T.untyped, T.untyped]).returns(Profile) }
            def build_profile(attributes: {}); end
          end
        RBI

        actual = rbi_for(:User)
        expect(actual).to eq(expected)
      end
    end

    context "with various attribute type configurations" do
      before do
        ActiveRecord::Schema.define do
          create_table :variations_users do |t|
            t.text :simple
            t.text :complex
            t.text :array_simple
            t.text :array_complex
            t.timestamps
          end
        end

        add_ruby_file("type_variations.rb", <<~RUBY)
          class SimpleModel
            include StoreModel::Model
            attribute :simple_attr, :string
          end

          class ComplexModel
            include StoreModel::Model
            attribute :nested_model, SimpleModel.to_type
            attribute :model_array, SimpleModel.to_array_type
          end

          class VariationsUser < ActiveRecord::Base
            attribute :simple, SimpleModel.to_type
            attribute :complex, ComplexModel.to_type
            attribute :array_simple, SimpleModel.to_array_type
            attribute :array_complex, ComplexModel.to_array_type
          end
        RUBY
      end

      it "handles various StoreModel attribute configurations" do
        user_attributes = VariationsUser.attribute_types

        expect(described_class.send(:store_model_type?, user_attributes["simple"])).to be true
        expect(described_class.send(:store_model_type?, user_attributes["complex"])).to be true
        expect(described_class.send(:store_model_type?, user_attributes["array_simple"])).to be true
        expect(described_class.send(:store_model_type?, user_attributes["array_complex"])).to be true
      end

      it "includes model with various StoreModel attributes" do
        constants = described_class.gather_constants
        expect(constants).to include(VariationsUser)
      end

      it "generates correct RBI for various attribute types" do
        expected = <<~RBI
          # typed: strong

          class VariationsUser
            sig { returns(T.nilable(SimpleModel)) }
            def simple; end

            sig { params(value: T.nilable(T.any(SimpleModel, T::Hash[T.untyped, T.untyped]))).returns(T.nilable(SimpleModel)) }
            def simple=(value); end

            sig { params(attributes: T::Hash[T.untyped, T.untyped]).returns(SimpleModel) }
            def build_simple(attributes: {}); end

            sig { returns(T.nilable(ComplexModel)) }
            def complex; end

            sig { params(value: T.nilable(T.any(ComplexModel, T::Hash[T.untyped, T.untyped]))).returns(T.nilable(ComplexModel)) }
            def complex=(value); end

            sig { params(attributes: T::Hash[T.untyped, T.untyped]).returns(ComplexModel) }
            def build_complex(attributes: {}); end

            sig { returns(T::Array[SimpleModel]) }
            def array_simple; end

            sig { params(value: T.nilable(T.any(T::Array[SimpleModel], T::Array[T::Hash[T.untyped, T.untyped]]))).returns(T::Array[SimpleModel]) }
            def array_simple=(value); end

            sig { returns(T::Array[ComplexModel]) }
            def array_complex; end

            sig { params(value: T.nilable(T.any(T::Array[ComplexModel], T::Array[T::Hash[T.untyped, T.untyped]]))).returns(T::Array[ComplexModel]) }
            def array_complex=(value); end
          end
        RBI

        actual = rbi_for(:VariationsUser)
        expect(actual).to eq(expected)
      end

      it "detects array types correctly in type names" do
        user_attributes = VariationsUser.attribute_types
        array_simple_type = user_attributes["array_simple"]
        array_complex_type = user_attributes["array_complex"]

        # Check that array types have distinguishable class names
        expect(array_simple_type.class.name).to include("StoreModel::Types")
        expect(array_complex_type.class.name).to include("StoreModel::Types")

        # Verify these are detected as array types (Many types)
        expect(array_simple_type).to be_a(StoreModel::Types::Many)
        expect(array_complex_type).to be_a(StoreModel::Types::Many)
      end
    end

    context "with OneOf StoreModel attributes" do
      before do
        ActiveRecord::Schema.define do
          create_table :one_of_users do |t|
            t.text :dynamic_content
            t.text :dynamic_list
            t.timestamps
          end
        end

        add_ruby_file("oneof_models.rb", <<~RUBY)
          class TextContent
            include StoreModel::Model
            attribute :text, :string
          end

          class ImageContent
            include StoreModel::Model
            attribute :url, :string
            attribute :alt_text, :string
          end

          DynamicContent = StoreModel.one_of do |json|
            case json['type']
            when 'text'
              TextContent
            when 'image'
              ImageContent
            else
              raise "Unknown content type"
            end
          end

          class OneOfUser < ActiveRecord::Base
            attribute :dynamic_content, DynamicContent.to_type
            attribute :dynamic_list, DynamicContent.to_array_type
          end
        RUBY
      end

      it "identifies OneOf types correctly" do
        user_attributes = OneOfUser.attribute_types
        dynamic_content_type = user_attributes["dynamic_content"]
        dynamic_list_type = user_attributes["dynamic_list"]

        expect(described_class.send(:store_model_one_of_type?, dynamic_content_type)).to be true
        expect(described_class.send(:store_model_one_of_type?, dynamic_list_type)).to be true
      end

      it "includes model with OneOf StoreModel attributes" do
        constants = described_class.gather_constants
        expect(constants).to include(OneOfUser)
      end

      it "generates correct RBI for OneOf attributes" do
        expected = <<~RBI
          # typed: strong

          class OneOfUser
            sig { returns(T.nilable(StoreModel::Model)) }
            def dynamic_content; end

            sig { params(value: T.nilable(T.any(StoreModel::Model, T::Hash[T.untyped, T.untyped]))).returns(T.nilable(StoreModel::Model)) }
            def dynamic_content=(value); end

            sig { params(attributes: T::Hash[T.untyped, T.untyped]).returns(StoreModel::Model) }
            def build_dynamic_content(attributes: {}); end

            sig { returns(T::Array[StoreModel::Model]) }
            def dynamic_list; end

            sig { params(value: T.nilable(T.any(T::Array[StoreModel::Model], T::Array[T::Hash[T.untyped, T.untyped]]))).returns(T::Array[StoreModel::Model]) }
            def dynamic_list=(value); end
          end
        RBI

        actual = rbi_for(:OneOfUser)
        expect(actual).to eq(expected)
      end
    end

    context "without StoreModel attributes" do
      before do
        ActiveRecord::Schema.define do
          create_table :simple_users do |t|
            t.string :name
            t.timestamps
          end
        end

        add_ruby_file("simple_user.rb", <<~RUBY)
          class SimpleUser < ActiveRecord::Base
            # No StoreModel attributes
          end
        RUBY
      end

      it "generates empty RBI for models without StoreModel attributes" do
        expected = <<~RBI
          # typed: strong
        RBI

        actual = rbi_for(:SimpleUser)
        expect(actual).to eq(expected)
      end
    end
  end

  describe "compiler class basics" do
    it "exists and is properly defined" do
      expect(defined?(described_class)).to be_truthy
    end

    it "is a subclass of Tapioca::Dsl::Compiler" do
      expect(described_class.superclass).to eq(Tapioca::Dsl::Compiler)
    end

    it "responds to gather_constants" do
      expect(described_class).to respond_to(:gather_constants)
    end

    it "returns an array from gather_constants" do
      result = described_class.gather_constants
      expect(result).to be_an(Array)
    end

    describe "instance methods" do
      let(:compiler) { described_class.allocate }

      it "has a decorate method" do
        expect(compiler).to respond_to(:decorate)
      end
    end
  end
end
