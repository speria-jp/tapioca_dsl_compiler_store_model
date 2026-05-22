# frozen_string_literal: true

# Tapioca DSL Compiler for StoreModel
module Tapioca
  module Dsl
    module Compilers
      class StoreModel < Tapioca::Dsl::Compiler
        sig { override.returns(T::Enumerable[Module]) }
        def self.gather_constants
          return [] unless defined?(::StoreModel)

          ::ActiveRecord::Base.descendants.select do |klass|
            next false unless klass.respond_to?(:attribute_types)

            # Skip classes that can't load their schema or attributes
            begin
              attribute_types = klass.attribute_types
            rescue ActiveRecord::TableNotSpecified, StandardError
              next false
            end

            # Check if any attribute types are StoreModel types
            attribute_types.values.any? { |type| store_model_type?(type) }
          end
        end

        sig { override.void }
        def decorate
          root.create_path(constant) do |klass|
            create_store_model_methods(klass)
          end
        end

        sig { params(type: T.untyped).returns(T::Boolean) }
        def self.store_model_type?(type)
          return true if type.is_a?(::StoreModel::Types::One)
          return true if type.is_a?(::StoreModel::Types::Many)
          return true if store_model_class_type?(type)
          return true if store_model_one_of_type?(type)

          false
        end

        sig { params(type: T.untyped).returns(T::Boolean) }
        def self.store_model_class_type?(type)
          return false unless type.respond_to?(:model_klass)

          model_klass = type.model_klass
          return false if model_klass.nil?

          model_klass.include?(::StoreModel::Model)
        end

        sig { params(type: T.untyped).returns(T::Boolean) }
        def self.store_model_one_of_type?(type)
          # Check for StoreModel.one_of types (polymorphic types)
          return true if type.is_a?(::StoreModel::Types::OnePolymorphic)
          return true if type.is_a?(::StoreModel::Types::ManyPolymorphic)

          false
        end

        private

        sig { params(mod: T.untyped).void }
        def create_store_model_methods(mod)
          constant.attribute_types.each do |attribute_name, type|
            next unless self.class.store_model_type?(type)

            create_attribute_methods(mod, attribute_name, type)
          end
        end

        sig { params(mod: T.untyped, attribute_name: String, type: T.untyped).void }
        def create_attribute_methods(mod, attribute_name, type)
          case type
          when ::StoreModel::Types::One
            create_single_store_model_methods(mod, attribute_name, type.model_klass)
          when ::StoreModel::Types::Many
            create_many_store_model_methods(mod, attribute_name, type.model_klass)
          else
            if self.class.store_model_one_of_type?(type)
              create_one_of_store_model_methods(mod, attribute_name, type)
            else
              create_fallback_store_model_methods(mod, attribute_name, type)
            end
          end
        end

        sig { params(mod: T.untyped, attribute_name: String, type: T.untyped).void }
        def create_fallback_store_model_methods(mod, attribute_name, type)
          return unless type.respond_to?(:model_klass)
          return unless type.model_klass&.include?(::StoreModel::Model)

          if array_type?(type)
            create_many_store_model_methods(mod, attribute_name, type.model_klass)
          else
            create_single_store_model_methods(mod, attribute_name, type.model_klass)
          end
        end

        sig { params(type: T.untyped).returns(T::Boolean) }
        def array_type?(type)
          type_name = type.class.name
          type_name&.include?("Many") || type_name&.include?("Array")
        end

        sig { params(mod: T.untyped, attribute_name: String, type: T.untyped).void }
        def create_one_of_store_model_methods(mod, attribute_name, type)
          # OneOf types have dynamic model selection, so we use more generic types
          if array_type?(type)
            create_one_of_array_methods(mod, attribute_name)
          else
            create_one_of_single_methods(mod, attribute_name)
          end
        end

        sig { params(mod: T.untyped, attribute_name: String).void }
        def create_one_of_single_methods(mod, attribute_name)
          # OneOf types are dynamically resolved, so we use generic StoreModel::Model types
          create_method_unless_overridden(
            mod,
            attribute_name,
            return_type: "T.nilable(StoreModel::Model)"
          )

          create_method_unless_overridden(
            mod,
            "#{attribute_name}=",
            parameters: [create_param("value",
                                      type: "T.nilable(T.any(StoreModel::Model, T::Hash[T.untyped, T.untyped]))")],
            return_type: "T.nilable(StoreModel::Model)"
          )

          create_method_unless_overridden(
            mod,
            "build_#{attribute_name}",
            parameters: [create_kw_opt_param("attributes", type: "T::Hash[T.untyped, T.untyped]", default: "{}")],
            return_type: "StoreModel::Model"
          )
        end

        sig { params(mod: T.untyped, attribute_name: String).void }
        def create_one_of_array_methods(mod, attribute_name)
          # OneOf array types are dynamically resolved
          array_type = "T::Array[StoreModel::Model]"
          nilable_array_type = "T.nilable(#{array_type})"

          create_method_unless_overridden(
            mod,
            attribute_name,
            return_type: nilable_array_type
          )

          create_method_unless_overridden(
            mod,
            "#{attribute_name}=",
            parameters: [create_param("value",
                                      type: "T.nilable(T.any(#{array_type}, " \
                                            "T::Array[T::Hash[T.untyped, T.untyped]]))")],
            return_type: nilable_array_type
          )
        end

        sig { params(mod: T.untyped, attribute_name: String, model_klass: T.untyped).void }
        def create_single_store_model_methods(mod, attribute_name, model_klass)
          return_type = "::#{model_klass.name}"

          create_method_unless_overridden(
            mod,
            attribute_name,
            return_type: "T.nilable(#{return_type})"
          )

          create_method_unless_overridden(
            mod,
            "#{attribute_name}=",
            parameters: [create_param("value",
                                      type: "T.nilable(T.any(#{return_type}, T::Hash[T.untyped, T.untyped]))")],
            return_type: "T.nilable(#{return_type})"
          )

          create_method_unless_overridden(
            mod,
            "build_#{attribute_name}",
            parameters: [create_kw_opt_param("attributes", type: "T::Hash[T.untyped, T.untyped]", default: "{}")],
            return_type: return_type
          )
        end

        sig { params(mod: T.untyped, attribute_name: String, model_klass: T.untyped).void }
        def create_many_store_model_methods(mod, attribute_name, model_klass)
          return_type = "::#{model_klass.name}"
          array_type = "T::Array[#{return_type}]"
          nilable_array_type = "T.nilable(#{array_type})"

          create_method_unless_overridden(
            mod,
            attribute_name,
            return_type: nilable_array_type
          )

          create_method_unless_overridden(
            mod,
            "#{attribute_name}=",
            parameters: [create_param("value",
                                      type: "T.nilable(T.any(#{array_type}, " \
                                            "T::Array[T::Hash[T.untyped, T.untyped]]))")],
            return_type: nilable_array_type
          )
        end

        # Emit a method sig unless the user has redefined that method on the
        # model class itself (via `def`, `delegate`, `define_method`, etc.).
        #
        # Background: `attribute :foo, SomeStoreModel.to_type` causes Rails to
        # generate `foo` / `foo=` on an internal `GeneratedAttributeMethods`
        # module that is included in the model. When the user overrides one
        # of those — typically via `delegate :foo, to: :bar` (which produces a
        # `*args, **kwargs, &block` method) — the rbi sig we'd otherwise emit
        # has a different arity from the user's actual method, and Sorbet
        # rejects it with a 4010 "redefined without matching argument count"
        # error.
        #
        # An overridden method's `owner` is the constant itself, while a
        # Rails-generated accessor's `owner` is the included
        # `GeneratedAttributeMethods` module (or similar). We use that to
        # detect overrides and skip emission so Sorbet can infer the type
        # from the user's implementation.
        sig { params(mod: T.untyped, name: T.any(String, Symbol), kwargs: T.untyped).void }
        def create_method_unless_overridden(mod, name, **kwargs)
          return if user_overridden?(name)

          mod.create_method(name.to_s, **kwargs)
        end

        sig { params(method_name: T.any(String, Symbol)).returns(T::Boolean) }
        def user_overridden?(method_name)
          name = method_name.to_sym
          return false unless constant.method_defined?(name) ||
                              constant.private_method_defined?(name)

          constant.instance_method(name).owner == constant
        rescue NameError
          false
        end
      end
    end
  end
end
