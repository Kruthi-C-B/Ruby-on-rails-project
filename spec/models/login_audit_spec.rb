require "rails_helper"

RSpec.describe LoginAudit do
  describe "associations" do
    it "belongs to a user" do
      expect(described_class.reflect_on_association(:user).macro).to eq(:belongs_to)
    end
  end

  it "persists audit details for a user" do
    user = User.create!(email: "audit@example.test", password: "password123")
    audit = described_class.create!(
      user: user,
      email: user.email,
      status: "successful",
      ip_address: "127.0.0.1",
      login_timestamp: Time.zone.parse("2026-10-27 10:00:00")
    )

    expect(audit.reload).to have_attributes(
      user_id: user.id,
      email: user.email,
      status: "successful",
      ip_address: "127.0.0.1"
    )
  end
end
