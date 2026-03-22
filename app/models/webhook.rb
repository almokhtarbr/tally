class Webhook < ApplicationRecord
  belongs_to :project

  validates :url, presence: true, format: { with: /\Ahttps?:\/\/.+/i, message: "must be a valid HTTP(S) URL" }
  validates :event_names, presence: true

  scope :active, -> { where(active: true) }

  before_validation :generate_secret, on: :create

  def matches_event?(event_name)
    event_names.include?("*") || event_names.include?(event_name)
  end

  def record_failure!
    increment!(:failures)
    update!(active: false) if failures >= 10
  end

  def record_success!
    update!(failures: 0, last_triggered_at: Time.current)
  end

  def sign_payload(payload)
    return nil unless secret.present?
    OpenSSL::HMAC.hexdigest("SHA256", secret, payload)
  end

  private

  def generate_secret
    self.secret ||= "whsec_#{SecureRandom.hex(24)}"
  end
end
