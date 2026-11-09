module LocalFindShared
  module ServiceTokens
    SERVICES = {
      "admin-dashboard-api" => {
        secret_env: "ADMIN_DASHBOARD_JWT_SECRET",
        audience: "admin-dashboard-api"
      },
      "security-logs-api" => {
        secret_env: "SECURITY_LOGS_JWT_SECRET",
        audience: "security-logs-api"
      }
    }.freeze
    REQUIRED_CLAIMS = %w[user_id email is_admin aud exp].freeze

    class Error < StandardError; end
    class InvalidToken < Error; end
    class UnknownService < Error; end

    def self.issue(user:, service:)
      config = service_config(service)
      JWT.encode(
        {
          user_id: user.id,
          email: user.email,
          is_admin: user.is_admin?,
          aud: config.fetch(:audience),
          exp: 5.minutes.from_now.to_i
        },
        ENV.fetch(config.fetch(:secret_env)),
        "HS256"
      )
    end

    def self.verify(token:, service:)
      config = service_config(service)
      claims = JWT.decode(
        token,
        ENV.fetch(config.fetch(:secret_env)),
        true,
        algorithm: "HS256",
        verify_expiration: true
      ).first

      unless claims.is_a?(Hash) &&
             REQUIRED_CLAIMS.all? { |claim| claims.key?(claim) } &&
             claims["user_id"].is_a?(Integer) &&
             claims["user_id"].positive? &&
             claims["email"].is_a?(String) &&
             claims["email"].present? &&
             [ true, false ].include?(claims["is_admin"]) &&
             claims["aud"] == config.fetch(:audience) &&
             claims["exp"].is_a?(Numeric) &&
             claims["exp"] > Time.now.to_i
        raise InvalidToken, "Invalid service token claims"
      end

      claims
    rescue JWT::DecodeError
      raise InvalidToken, "Invalid service token"
    end

    def self.service_config(service)
      SERVICES.fetch(service) { raise UnknownService, "Unknown token service: #{service}" }
    end
    private_class_method :service_config
  end
end
