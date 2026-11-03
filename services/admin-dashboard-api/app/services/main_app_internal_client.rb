require "json"
require "net/http"
require "uri"

class MainAppInternalClient
  class Error < StandardError; end

  def initialize(authorization:)
    @authorization = authorization
  end

  def get(path, params: {})
    base_url = ENV.fetch("MAIN_APP_INTERNAL_URL", "http://web:3000")
    uri = URI.join("#{base_url.chomp("/")}/", path.delete_prefix("/"))
    uri.query = URI.encode_www_form(params) if params.any?

    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = @authorization
    response = Net::HTTP.start(
      uri.host,
      uri.port,
      use_ssl: uri.scheme == "https",
      open_timeout: 2,
      read_timeout: 10
    ) { |http| http.request(request) }

    unless response.is_a?(Net::HTTPSuccess)
      raise Error, "Main app internal API returned HTTP #{response.code}"
    end

    JSON.parse(response.body)
  rescue IOError, SystemCallError, Timeout::Error, SocketError, URI::InvalidURIError, JSON::ParserError => error
    raise Error, "Main app internal API request failed: #{error.class}"
  end

end
