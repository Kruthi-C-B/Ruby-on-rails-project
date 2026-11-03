require "rails_helper"

RSpec.describe User, type: :model do
  it "treats a platform_admin-only user as an administrator" do
    user = User.new(is_admin: false, platform_admin: true)

    expect(user.is_admin?).to be(true)
  end

  it "does not treat a non-admin user as an administrator" do
    user = User.new(is_admin: false, platform_admin: false)

    expect(user.is_admin?).to be(false)
  end
end
