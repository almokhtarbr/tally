class IdentityAlias < ApplicationRecord
  belongs_to :project
  belongs_to :user_profile

  validates :anonymous_id, presence: true, uniqueness: { scope: :project_id }
end
