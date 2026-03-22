class Session < ApplicationRecord
  belongs_to :user

  has_secure_token

  validates :token, presence: true, uniqueness: true
end
