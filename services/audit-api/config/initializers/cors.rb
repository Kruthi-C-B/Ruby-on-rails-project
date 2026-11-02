Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*ENV.fetch("ALLOWED_ORIGINS", "http://127.0.0.1:3000,http://localhost:3000").split(",").map(&:strip))
    resource "/api/*", headers: :any, methods: %i[get options]
  end
end
