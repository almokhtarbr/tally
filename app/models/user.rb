class User < ApplicationRecord
  has_secure_password

  # A single-use, 30-minute password-reset token. Tying it to the last 10
  # chars of the salt means the link stops working the moment the password
  # changes (so it can't be replayed).
  generates_token_for :password_reset, expires_in: 30.minutes do
    password_salt&.last(10)
  end

  # A one-week link an invited member uses to set their own password. It
  # stops working once they accept (the timestamp changes) or once the
  # password changes again (the salt changes).
  generates_token_for :invitation, expires_in: 7.days do
    [ password_salt&.last(10), invitation_accepted_at&.to_i ].join
  end

  scope :pending_invitation, -> { where(invitation_accepted_at: nil) }

  has_many :sessions, dependent: :destroy
  has_many :project_memberships, dependent: :destroy
  has_many :projects, through: :project_memberships

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true
  validates :role, presence: true, inclusion: { in: %w[admin member] }

  def admin?
    role == "admin"
  end

  def invitation_pending?
    invitation_accepted_at.nil?
  end

  def can_access_project?(project)
    admin? || project_memberships.exists?(project: project)
  end

  def role_for_project(project)
    project_memberships.find_by(project: project)&.role
  end
end
