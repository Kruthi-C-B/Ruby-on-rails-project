require "rails_helper"

RSpec.describe LoginAttempt do
  describe "validations" do
    it "requires email and status" do
      attempt = described_class.new

      expect(attempt).not_to be_valid
      expect(attempt.errors[:email]).to include("can't be blank")
      expect(attempt.errors[:status]).to include("can't be blank")
    end

    it "accepts a complete attempt" do
      attempt = described_class.new(email: "person@example.test", status: "failed", failure_reason: "bad password")

      expect(attempt).to be_valid
    end
  end
end
