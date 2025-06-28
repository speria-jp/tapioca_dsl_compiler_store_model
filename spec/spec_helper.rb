# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../../lib", __dir__)

require "tapioca_dsl_compiler_store_model"
require "tempfile"
require "fileutils"

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.disable_monkey_patching!
  config.warnings = true

  config.default_formatter = "doc" if config.files_to_run.one?

  config.order = :random
  Kernel.srand config.seed
end

# Helper methods for integration testing
module IntegrationTestHelpers
  def setup_test_environment
    @temp_dir = Dir.mktmpdir
    @original_load_path = $LOAD_PATH.dup
    $LOAD_PATH.unshift(@temp_dir)
    @test_constants = []

    setup_active_record
    setup_store_model
  end

  def cleanup_test_environment
    $LOAD_PATH.replace(@original_load_path) if @original_load_path
    FileUtils.rm_rf(@temp_dir) if @temp_dir
    cleanup_constants
  end

  def register_test_constant(const_name)
    @test_constants ||= []
    @test_constants << const_name.to_sym
  end

  def cleanup_constants
    return unless @test_constants

    @test_constants.each do |const_name|
      Object.send(:remove_const, const_name) if Object.const_defined?(const_name)
    rescue NameError
      # Ignore if already removed
    end

    @test_constants = []
  end

  def add_ruby_file(filename, content)
    file_path = File.join(@temp_dir, filename)
    File.write(file_path, content)

    # Get list of constants before definition
    constants_before = Object.constants

    load file_path

    # Automatically register newly added constants after definition
    new_constants = Object.constants - constants_before
    new_constants.each { |const_name| register_test_constant(const_name) }
  end

  def setup_active_record
    require "active_record"

    ActiveRecord::Base.establish_connection(
      adapter: "sqlite3",
      database: ":memory:"
    )

    ActiveRecord::Schema.define do
      create_table :users do |t|
        t.text :settings
        t.text :preferences
        t.text :configuration
        t.timestamps
      end
    end
  end

  def setup_store_model
    require "store_model"
  end
end

# Helper methods for RBI generation testing
module RbiGenerationHelpers
  # Generate RBI file for specified class (using actual compiler)
  def rbi_for(klass_name)
    require "rbi"
    require "stringio"

    # Get actual class object from class name
    klass = Object.const_get(klass_name.to_s)

    # Check if StoreModel compiler should target this class
    constants = Tapioca::Dsl::Compilers::StoreModel.gather_constants
    return "# typed: strong\n" unless constants.include?(klass)

    # Create RBI tree (following Tapioca official pattern)
    rbi_tree = RBI::Tree.new

    # Create pipeline (required arguments)
    pipeline = Tapioca::Dsl::Pipeline.new(
      requested_constants: [klass],
      requested_compilers: [Tapioca::Dsl::Compilers::StoreModel]
    )

    # Generate RBI using actual StoreModel compiler
    compiler = Tapioca::Dsl::Compilers::StoreModel.new(pipeline, rbi_tree, klass)
    compiler.decorate

    # Create and output RBI file
    rbi_file = RBI::File.new(strictness: "strong")
    rbi_file.root = rbi_tree

    # Convert to string
    full_content = rbi_file.string

    # Return header only if empty
    if full_content.strip == "# typed: strong"
      "# typed: strong\n"
    else
      full_content
    end
  rescue StandardError => e
    # Output debug information if error occurs
    puts "Error in rbi_for: #{e.class}: #{e.message}"
    puts e.backtrace.first(5)
    "# typed: strong\n"
  end
end

RSpec.configure do |config|
  config.include IntegrationTestHelpers, type: :integration
  config.include RbiGenerationHelpers, type: :integration

  config.before(:each, type: :integration) do
    setup_test_environment
  end

  config.after(:each, type: :integration) do
    cleanup_test_environment
  end
end
