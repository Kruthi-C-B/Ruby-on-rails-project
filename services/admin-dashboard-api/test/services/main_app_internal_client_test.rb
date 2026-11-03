require "test_helper"
require "net/http"

class MainAppInternalClientTest < ActiveSupport::TestCase
  test "forwards the service token and returns decoded main-app data" do
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.define_singleton_method(:body) { '{"audit_trail":[]}' }
    http = Object.new
    http.define_singleton_method(:request) do |request|
      raise "authorization was not forwarded" unless request["Authorization"] == "Bearer service-token"

      response
    end

    with_http_stub(http) do
      data = MainAppInternalClient.new(authorization: "Bearer service-token")
        .get("/api/v1/internal/admin/audit_trail")
      assert_equal({ "audit_trail" => [] }, data)
    end
  end

  test "raises explicitly when the main app returns an error" do
    response = Net::HTTPServiceUnavailable.new("1.1", "503", "Unavailable")
    response.define_singleton_method(:body) { '{"errors":["unavailable"]}' }
    http = Object.new
    http.define_singleton_method(:request) { |_| response }

    with_http_stub(http) do
      assert_raises(MainAppInternalClient::Error) do
        MainAppInternalClient.new(authorization: "Bearer service-token")
          .get("/api/v1/internal/admin/audit_trail")
      end
    end
  end

  private

  def with_http_stub(http)
    original_start = Net::HTTP.method(:start)
    Net::HTTP.define_singleton_method(:start) { |_host, _port, **_options, &block| block.call(http) }
    yield
  ensure
    Net::HTTP.define_singleton_method(:start, original_start)
  end
end
