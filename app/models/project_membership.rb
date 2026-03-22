class ProjectMembership < ApplicationRecord
  belongs_to :user
  belongs_to :project

  validates :role, presence: true, inclusion: { in: %w[owner editor viewer] }
  validates :user_id, uniqueness: { scope: :project_id }
end
