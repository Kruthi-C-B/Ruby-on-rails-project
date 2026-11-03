require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = ENV["CI"] == "true"
  config.consider_all_requests_local = true
  config.cache_classes = true
  config.active_support.deprecation = :stderr
end
