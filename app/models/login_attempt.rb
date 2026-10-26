class LoginAttempt < ApplicationRecord
  validates :email, presence: true
  validates :status, presence: true
end
