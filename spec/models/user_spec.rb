require "rails_helper"

RSpec.describe User do
  describe "associations" do
    it "has dependent tenant, cart, and login audit associations" do
      expect(described_class.reflect_on_association(:tenant).options[:dependent]).to eq(:destroy)
      expect(described_class.reflect_on_association(:carts).options[:dependent]).to eq(:destroy)
      expect(described_class.reflect_on_association(:login_audits).options[:dependent]).to eq(:destroy)
    end
  end

  describe "password authentication" do
    it "authenticates with the configured password" do
      user = described_class.create!(email: "user@example.test", password: "password123")

      expect(user.authenticate("password123")).to eq(user)
      expect(user.authenticate("wrong")).to be_falsey
    end
  end
end
