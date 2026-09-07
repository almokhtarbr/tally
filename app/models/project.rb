class Project < ApplicationRecord
  has_many :user_profiles, dependent: :destroy
  has_many :events, dependent: :destroy
  has_many :event_daily_rollups, dependent: :destroy
  has_many :identity_aliases, dependent: :destroy
  has_many :segments, dependent: :destroy
  has_many :saved_reports, dependent: :destroy
  has_many :dashboards, dependent: :destroy
  has_many :audit_events, dependent: :destroy
  has_many :webhooks, dependent: :destroy
  has_many :anomalies, dependent: :destroy
  has_many :project_memberships, dependent: :destroy
  has_many :users, through: :project_memberships

  validates :name, presence: true
  validates :api_key, presence: true, uniqueness: true
  validates :api_secret, presence: true, uniqueness: true

  before_validation :generate_api_keys, on: :create

  # A read-only public dashboard link. Off until enabled; enabling again
  # rotates the token (old links stop working).
  def enable_sharing!
    update!(share_token: "sh_#{SecureRandom.urlsafe_base64(24)}")
  end

  def disable_sharing!
    update!(share_token: nil)
  end

  def shared? = share_token.present?

  private

  def generate_api_keys
    self.api_key ||= "pk_#{SecureRandom.hex(24)}"
    self.api_secret ||= "sk_#{SecureRandom.hex(24)}"
  end
end
