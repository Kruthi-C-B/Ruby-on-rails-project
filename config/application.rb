require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

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

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
