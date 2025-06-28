# frozen_string_literal: true

require_relative "tapioca_dsl_compiler_store_model/version"

# Conditionally load required dependencies
begin
  require "tapioca/dsl"
  require "store_model"
rescue LoadError
  # Do nothing if dependencies are not available
end

# Only load implementation when both Tapioca::Dsl::Compiler and StoreModel are available
require_relative "tapioca/dsl/compilers/store_model" if defined?(Tapioca::Dsl::Compiler) && defined?(StoreModel)
