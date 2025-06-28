# frozen_string_literal: true

require_relative "lib/tapioca_dsl_compiler_store_model/version"

Gem::Specification.new do |spec|
  spec.name = "tapioca_dsl_compiler_store_model"
  spec.version = TapiocaDslCompilerStoreModel::VERSION
  spec.authors = ["speria-jp"]

  spec.summary = "Tapioca DSL compiler for StoreModel"
  spec.description = "Provides Tapioca DSL compiler for generating RBI files for StoreModel gem"
  spec.homepage = "https://github.com/speria-jp/tapioca_dsl_compiler_store_model"
  spec.email = ["daichi.sakai@speria.jp"]
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?("test/", "spec/", "features/") ||
        f.start_with?(".github/") ||
        f == ".gitignore" ||
        f == ".rspec" ||
        f == ".rubocop.yml" ||
        f == "Gemfile" ||
        f == "Gemfile.lock" ||
        f == "CLAUDE.md"
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "store_model", ">= 1.0.0"
  spec.add_dependency "tapioca", ">= 0.11.0"
end
