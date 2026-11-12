require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

# Disable Apartment's automatic tenant migration integration.
# Normal rails db:migrate should migrate only the shared database.
Apartment.db_migrate_tenants = false

module LocalFind
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])
    serializers_path = Rails.root.join("app/serializers")
    config.autoload_paths << serializers_path
    config.eager_load_paths << serializers_path

    # Active Record Encryption configuration with environment/credentials support and safe fallbacks
    config.active_record.encryption.primary_key = ENV["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"] ||
      Rails.application.credentials.dig(:active_record_encryption, :primary_key) ||
      "12345678901234567890123456789012"
    config.active_record.encryption.deterministic_key = ENV["ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY"] ||
      Rails.application.credentials.dig(:active_record_encryption, :deterministic_key) ||
      "abcdefghijklmnopqrstuvwxyz123456"
    config.active_record.encryption.key_derivation_salt = ENV["ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"] ||
      Rails.application.credentials.dig(:active_record_encryption, :key_derivation_salt) ||
      "saltysaltysaltysaltysaltysalty12"

    # Shakapacker compiles our JSX, so react-rails must not look for Sprockets
    config.react.sprockets_strategy = false

    # Gracefully handle missing database during Docker image build / assets:precompile
    initializer "apartment.safe_init", before: "apartment.init" do
      if defined?(Apartment::Tenant)
        Apartment::Tenant.singleton_class.prepend(
          Module.new do
            def init
              super
            rescue ActiveRecord::DatabaseConnectionError, Mysql2::Error => e
              warn "Skipping Apartment initialization (database connection unavailable): #{e.message}"
            end
          end
        )
      end
    end

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
