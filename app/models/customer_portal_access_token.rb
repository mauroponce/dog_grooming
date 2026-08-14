class CustomerPortalAccessToken < ApplicationRecord
  PURPOSES = %w[customer_portal_login booking_access].freeze

  belongs_to :business
  belongs_to :customer_profile, optional: true

  validates :email, :token_digest, :purpose, :expires_at, presence: true
  validates :purpose, inclusion: { in: PURPOSES }
  validates :token_digest, uniqueness: true

  scope :active, -> { where(consumed_at: nil).where("expires_at > ?", Time.current) }
  scope :for_login, -> { where(purpose: "customer_portal_login") }

  def self.digest(token)
    OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, token.to_s)
  end

  def expired?
    expires_at <= Time.current
  end

  def consumed?
    consumed_at.present?
  end
end
